using DiarioTreino.Application.Acesso;
using DiarioTreino.Application.Comum;
using DiarioTreino.Application.Identidade;
using DiarioTreino.Domain.Comum;
using DiarioTreino.Domain.Educador;
using DiarioTreino.Domain.Identidade;

namespace DiarioTreino.Application.Educador;

/// <summary>
/// Habilitação do educador pela consulta do CREF (PBI-106). O papel EDUCADOR só
/// é concedido quando a busca por CPF na UF devolve o número informado com
/// situação ATIVO. Falha do site nunca recusa. O CPF não sai deste método: não
/// vai para banco, log, exceção nem resposta.
/// </summary>
public sealed class ServicoCref
{
    /// <summary>Tentativas que contam (todas menos INDISPONIVEL) em 24 h.</summary>
    public const int LimiteTentativas = 5;

    private readonly IRepositorioEducadorCref _cref;
    private readonly IRepositorioUsuario _usuarios;
    private readonly IConsultaCref _consulta;
    private readonly ConfiguracaoEducador _config;
    private readonly TimeProvider _relogio;

    public ServicoCref(
        IRepositorioEducadorCref cref,
        IRepositorioUsuario usuarios,
        IConsultaCref consulta,
        ConfiguracaoEducador config,
        TimeProvider relogio)
    {
        _cref = cref;
        _usuarios = usuarios;
        _consulta = consulta;
        _config = config;
        _relogio = relogio;
    }

    public async Task<SituacaoCrefResposta> ObterAsync(Guid usuarioId, CancellationToken ct)
    {
        var registro = await _cref.ObterAsync(usuarioId, ct);
        return new SituacaoCrefResposta(
            _config.ExigirCref,
            registro is null
                ? null
                : new RegistroCrefResposta(
                    registro.Uf, registro.Numero, registro.Situacao, registro.Categoria,
                    registro.Origem, registro.ConsultadoEm, registro.DeclaradoEm));
    }

    /// <summary>
    /// Verifica o registro. O formato (UF, número, CPF com dígito verificador)
    /// já foi conferido pelo <see cref="VerificarCrefValidator"/>.
    /// </summary>
    /// <exception cref="LimiteTentativasCrefException">Acima de 5 tentativas em 24 h (429).</exception>
    /// <exception cref="ConflitoException">O registro já habilitou outra conta (409).</exception>
    public async Task<VerificarCrefResposta> VerificarAsync(
        Guid usuarioId, string uf, string numero, string cpf, CancellationToken ct)
    {
        var ufNormalizada = uf.Trim().ToUpperInvariant();
        var numeroNormalizado = RegistroCref.Normalizar(numero);

        // Já habilitado: não consulta de novo.
        var atual = await _cref.ObterAsync(usuarioId, ct);
        if (atual is not null)
        {
            return new VerificarCrefResposta(ResultadoCref.Habilitado, null, atual.Situacao);
        }

        // UF sem consulta levantada (PBI-105): não consulta, não gasta tentativa.
        if (!RegistroCref.UfsComConsulta.Contains(ufNormalizada))
        {
            return new VerificarCrefResposta(ResultadoCref.Indisponivel, MotivoCref.UfSemConsulta, null);
        }

        var agora = _relogio.GetUtcNow();
        if (await _cref.ContarTentativasAsync(usuarioId, agora.AddHours(-24), ct) >= LimiteTentativas)
        {
            throw new LimiteTentativasCrefException();
        }

        if (await _cref.RegistroUsadoPorOutroAsync(ufNormalizada, numeroNormalizado, usuarioId, ct))
        {
            throw new ConflitoException("Este registro do CREF já está ligado a outra conta.");
        }

        ResultadoConsultaCref consulta;
        try
        {
            consulta = await _consulta.ConsultarPorCpfAsync(ufNormalizada, Cpf.SoDigitos(cpf), ct);
        }
        catch (Exception e) when (e is not OperationCanceledException || !ct.IsCancellationRequested)
        {
            // Falha nossa ou do site nunca recusa. A exceção não é repassada: a
            // mensagem dela poderia carregar o que foi enviado.
            consulta = new ResultadoConsultaCref.Indisponivel();
        }

        var decisao = DecisaoCref.Decidir(numeroNormalizado, consulta);
        if (decisao.Resultado == ResultadoCref.Indisponivel)
        {
            return new VerificarCrefResposta(decisao.Resultado, null, null);
        }

        _cref.AdicionarTentativa(new TentativaCref
        {
            Id = Guid.NewGuid(),
            UsuarioId = usuarioId,
            Em = agora,
            Resultado = decisao.Resultado,
        });

        if (decisao.Resultado == ResultadoCref.Habilitado)
        {
            var usuario = await _usuarios.ObterPorIdAsync(usuarioId, ct)
                ?? throw new RecursoNaoEncontradoException();
            _cref.Adicionar(new EducadorCref
            {
                UsuarioId = usuarioId,
                Uf = ufNormalizada,
                Numero = numeroNormalizado,
                Situacao = decisao.Situacao,
                Categoria = Cortar(decisao.Registro!.Categoria.Trim().ToUpperInvariant(), 30),
                Origem = OrigemCref.Automatica,
                ConsultadoEm = agora,
            });
            if (!usuario.Papeis.Any(p => p.Papel == Papeis.Educador))
            {
                usuario.Papeis.Add(new UsuarioPapel { UsuarioId = usuarioId, Papel = Papeis.Educador });
            }
        }

        // Evidência, papel e tentativa numa transação só.
        if (!await _cref.TentarSalvarAsync(ct))
        {
            throw new ConflitoException("Este registro do CREF já está ligado a outra conta.");
        }

        return new VerificarCrefResposta(
            decisao.Resultado,
            decisao.Motivo,
            decisao.Situacao is null ? null : Cortar(decisao.Situacao, 30));
    }

    /// <summary>
    /// Habilitação declarada (PBI-106, decisão do PO em 27/11): o educador envia
    /// UF, número e a foto da carteira do CREF, e o modo educador é liberado na
    /// hora. Não há consulta ao site; a foto fica como prova para o PO conferir
    /// depois (por script) e revogar se não bater. O formato e a permissão já
    /// foram conferidos pelo <see cref="DeclararCrefValidator"/>.
    /// </summary>
    /// <exception cref="ArgumentException">Foto vazia, grande demais ou que não é JPG/PNG (400).</exception>
    /// <exception cref="ConflitoException">O registro já habilitou outra conta (409).</exception>
    public async Task<VerificarCrefResposta> DeclararAsync(
        Guid usuarioId, string uf, string numero, byte[] foto, CancellationToken ct)
    {
        if (foto.Length == 0 || foto.Length > FotoCarteiraCref.TamanhoMaximo)
        {
            throw new ArgumentException("Envie uma foto JPG ou PNG de até 5 MB.");
        }
        var tipo = FotoCarteiraCref.TipoPelaAssinatura(foto)
            ?? throw new ArgumentException("Envie uma foto JPG ou PNG de até 5 MB.");

        var ufNormalizada = uf.Trim().ToUpperInvariant();
        var numeroNormalizado = RegistroCref.Normalizar(numero);

        var atual = await _cref.ObterAsync(usuarioId, ct);
        if (atual is not null)
        {
            return new VerificarCrefResposta(ResultadoCref.Habilitado, null, null);
        }

        if (await _cref.RegistroUsadoPorOutroAsync(ufNormalizada, numeroNormalizado, usuarioId, ct))
        {
            throw new ConflitoException("Este registro do CREF já está ligado a outra conta.");
        }

        var usuario = await _usuarios.ObterPorIdAsync(usuarioId, ct)
            ?? throw new RecursoNaoEncontradoException();
        var agora = _relogio.GetUtcNow();
        _cref.Adicionar(new EducadorCref
        {
            UsuarioId = usuarioId,
            Uf = ufNormalizada,
            Numero = numeroNormalizado,
            Origem = OrigemCref.Declarada,
            DeclaradoEm = agora,
        });
        _cref.AdicionarFoto(new FotoCarteiraCref
        {
            UsuarioId = usuarioId,
            Conteudo = foto,
            TipoConteudo = tipo,
            EnviadaEm = agora,
        });
        if (!usuario.Papeis.Any(p => p.Papel == Papeis.Educador))
        {
            usuario.Papeis.Add(new UsuarioPapel { UsuarioId = usuarioId, Papel = Papeis.Educador });
        }

        // Registro, foto e papel numa transação só.
        if (!await _cref.TentarSalvarAsync(ct))
        {
            throw new ConflitoException("Este registro do CREF já está ligado a outra conta.");
        }

        return new VerificarCrefResposta(ResultadoCref.Habilitado, null, null);
    }

    /// <summary>
    /// Rota antiga <c>POST /me/papeis/educador</c>. Com a chave ligada, só
    /// devolve o perfil de quem já é educador; não concede o papel a ninguém.
    /// </summary>
    public bool RotaAntigaConcedePapel => !_config.ExigirCref;

    private static string Cortar(string texto, int max) => texto.Length <= max ? texto : texto[..max];
}
