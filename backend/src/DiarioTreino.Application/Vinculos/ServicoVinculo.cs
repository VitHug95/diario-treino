using DiarioTreino.Application.Acesso;
using DiarioTreino.Application.Comum;
using DiarioTreino.Application.Identidade;
using DiarioTreino.Domain.Comum;
using DiarioTreino.Domain.Identidade;
using DiarioTreino.Domain.Vinculos;

namespace DiarioTreino.Application.Vinculos;

/// <summary>
/// Casos de uso do vínculo educador-aluno (PBI-85): convite, aceite, recusa e
/// encerramento, e as listas de convites (aluno) e alunos (educador). A regra
/// de acesso do MAS 11.3 ("recurso de outro usuário → 404") é aplicada aqui:
/// quem não é parte do vínculo recebe <see cref="RecursoNaoEncontradoException"/>.
/// </summary>
public sealed class ServicoVinculo
{
    private readonly IRepositorioVinculo _vinculos;
    private readonly IRepositorioUsuario _usuarios;
    private readonly IRepositorioConsentimento _consentimentos;

    public ServicoVinculo(
        IRepositorioVinculo vinculos,
        IRepositorioUsuario usuarios,
        IRepositorioConsentimento consentimentos)
    {
        _vinculos = vinculos;
        _usuarios = usuarios;
        _consentimentos = consentimentos;
    }

    /// <summary>
    /// Educador convida um aluno pelo e-mail. Exige papel EDUCADOR (403 sem ele).
    /// E-mail inexistente → 404 (sem revelar se existe). Convite para si mesmo →
    /// 400. Já existe vínculo aberto (PENDENTE/ATIVO) com este aluno → 409.
    /// Cria o vínculo PENDENTE e devolve o id.
    /// </summary>
    public async Task<Guid> ConvidarAsync(Guid educadorId, string emailAluno, CancellationToken ct)
    {
        var educador = await _usuarios.ObterPorIdAsync(educadorId, ct)
            ?? throw new RecursoNaoEncontradoException();

        if (!educador.Papeis.Any(p => p.Papel == Papeis.Educador))
        {
            throw new AcaoNaoPermitidaException(
                "Você precisa ativar o modo educador para convidar alunos.");
        }

        // Aluno inexistente responde 404, igual a recurso de outro usuário: não
        // revela se o e-mail está ou não cadastrado.
        var aluno = await _usuarios.ObterPorEmailAsync(emailAluno, ct)
            ?? throw new RecursoNaoEncontradoException();

        if (aluno.Id == educadorId)
        {
            throw new ArgumentException("Você não pode convidar a si mesmo.");
        }

        if (await _vinculos.ExisteVinculoAbertoAsync(educadorId, aluno.Id, ct))
        {
            throw new ConflitoException("Já existe um convite ou vínculo ativo com este aluno.");
        }

        var vinculo = new Vinculo
        {
            Id = Guid.NewGuid(),
            EducadorId = educadorId,
            AlunoId = aluno.Id,
            Status = StatusVinculo.Pendente,
        };

        // TentarCriarAsync fecha a janela de corrida com a checagem acima: se
        // dois convites simultâneos passarem pelo ExisteVinculoAbertoAsync, o
        // índice único barra o segundo e devolvemos 409 (não 500).
        if (!await _vinculos.TentarCriarAsync(vinculo, ct))
        {
            throw new ConflitoException("Já existe um convite ou vínculo ativo com este aluno.");
        }
        return vinculo.Id;
    }

    /// <summary>Convites PENDENTES em que o usuário logado é o aluno.</summary>
    public async Task<List<ConvitePendente>> ListarPendentesAsync(Guid alunoId, CancellationToken ct)
    {
        var pendentes = await _vinculos.ListarPendentesDoAlunoAsync(alunoId, ct);
        var lista = new List<ConvitePendente>(pendentes.Count);
        foreach (var v in pendentes)
        {
            var educador = await _usuarios.ObterPorIdAsync(v.EducadorId, ct);
            if (educador is null) continue; // educador removido: ignora o convite órfão.
            lista.Add(new ConvitePendente(v.Id, educador.Id, educador.Nome, educador.Email));
        }
        return lista;
    }

    /// <summary>
    /// O aluno aceita um convite PENDENTE: vira ATIVO e grava o início. Vínculo
    /// de outro aluno (ou inexistente) → 404. Só convite PENDENTE pode ser aceito.
    ///
    /// Consentimento LGPD (PBI-87/88, opção 1): aceitar o convite É o ato de
    /// consentir que aquele educador veja os dados. Registramos o aceite do
    /// termo vigente do aluno na MESMA transação em que o vínculo vira ATIVO
    /// (idempotente). Assim o vínculo ATIVO já é a prova do consentimento e a
    /// regra de acesso (MAS 11.3) não precisa de gate extra.
    /// </summary>
    public async Task AceitarAsync(Guid alunoLogadoId, Guid vinculoId, CancellationToken ct)
    {
        var vinculo = await CarregarComoAlunoAsync(vinculoId, alunoLogadoId, ct);
        if (vinculo.Status != StatusVinculo.Pendente)
        {
            throw new ConflitoException("Este convite não está mais pendente.");
        }

        vinculo.Status = StatusVinculo.Ativo;
        vinculo.Inicio = DateTimeOffset.UtcNow;
        await _consentimentos.RegistrarSeAusenteAsync(
            alunoLogadoId, TermoConsentimento.VersaoVigente, ct);
        await _vinculos.SalvarAsync(ct);
    }

    /// <summary>
    /// O aluno recusa um convite PENDENTE: vira ENCERRADO e grava o fim (libera o
    /// par para um novo convite no futuro). Vínculo de outro aluno → 404.
    /// </summary>
    public async Task RecusarAsync(Guid alunoLogadoId, Guid vinculoId, CancellationToken ct)
    {
        var vinculo = await CarregarComoAlunoAsync(vinculoId, alunoLogadoId, ct);
        if (vinculo.Status != StatusVinculo.Pendente)
        {
            throw new ConflitoException("Este convite não está mais pendente.");
        }

        vinculo.Status = StatusVinculo.Encerrado;
        vinculo.Fim = DateTimeOffset.UtcNow;
        await _vinculos.SalvarAsync(ct);
    }

    /// <summary>
    /// Encerra um vínculo ATIVO. Pode partir do educador OU do aluno do vínculo;
    /// qualquer outro usuário → 404. Grava o fim. Encerrar não apaga nada: o
    /// educador só perde o acesso (o histórico do aluno permanece).
    /// </summary>
    public async Task EncerrarAsync(Guid usuarioLogadoId, Guid vinculoId, CancellationToken ct)
    {
        var vinculo = await _vinculos.ObterPorIdAsync(vinculoId, ct)
            ?? throw new RecursoNaoEncontradoException();

        // Só as duas partes do vínculo o enxergam; o resto recebe 404.
        if (vinculo.EducadorId != usuarioLogadoId && vinculo.AlunoId != usuarioLogadoId)
        {
            throw new RecursoNaoEncontradoException();
        }

        if (vinculo.Status != StatusVinculo.Ativo)
        {
            throw new ConflitoException("Este vínculo não está ativo.");
        }

        vinculo.Status = StatusVinculo.Encerrado;
        vinculo.Fim = DateTimeOffset.UtcNow;
        await _vinculos.SalvarAsync(ct);
    }

    /// <summary>Alunos com vínculo ATIVO do educador logado (<c>GET /alunos</c>).</summary>
    public async Task<List<AlunoVinculado>> ListarAlunosAtivosAsync(Guid educadorId, CancellationToken ct)
    {
        var ativos = await _vinculos.ListarAtivosDoEducadorAsync(educadorId, ct);
        var lista = new List<AlunoVinculado>(ativos.Count);
        foreach (var v in ativos)
        {
            var aluno = await _usuarios.ObterPorIdAsync(v.AlunoId, ct);
            if (aluno is null) continue;
            lista.Add(new AlunoVinculado(v.Id, aluno.Id, aluno.Nome, aluno.Email));
        }
        return lista;
    }

    /// <summary>
    /// Carrega o vínculo garantindo que o usuário logado é o ALUNO dele; caso
    /// contrário (vínculo de outro, ou inexistente) responde 404.
    /// </summary>
    private async Task<Vinculo> CarregarComoAlunoAsync(
        Guid vinculoId,
        Guid alunoLogadoId,
        CancellationToken ct)
    {
        var vinculo = await _vinculos.ObterPorIdAsync(vinculoId, ct)
            ?? throw new RecursoNaoEncontradoException();

        if (vinculo.AlunoId != alunoLogadoId)
        {
            throw new RecursoNaoEncontradoException();
        }
        return vinculo;
    }
}
