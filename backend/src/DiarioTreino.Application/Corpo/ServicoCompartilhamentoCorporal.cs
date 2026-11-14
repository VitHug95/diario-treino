using DiarioTreino.Application.Acesso;
using DiarioTreino.Application.Identidade;

namespace DiarioTreino.Application.Corpo;

/// <summary>
/// Compartilhamento do corpo com o educador (E12 / PBI-95). O atleta tranca e
/// destranca, separadamente, os dados corporais e as medidas; destrancado, todo
/// educador com vínculo ATIVO vê, só leitura. Trancar corta na hora.
///
/// O educador lê por rotas próprias (<c>/alunos/{atletaId}/...</c>). A ordem é
/// fixa: sem vínculo ativo, 404 (MAS 11.3, inclusive o próprio atleta, que usa
/// <c>/me</c>); com vínculo, o cadeado decide. O educador nunca grava.
/// </summary>
public sealed class ServicoCompartilhamentoCorporal
{
    private readonly IRepositorioUsuario _usuarios;
    private readonly IRepositorioVinculo _vinculos;
    private readonly IControleAcesso _acesso;
    private readonly ServicoPerfilCorporal _perfilCorporal;
    private readonly ServicoMedidas _medidas;

    public ServicoCompartilhamentoCorporal(
        IRepositorioUsuario usuarios,
        IRepositorioVinculo vinculos,
        IControleAcesso acesso,
        ServicoPerfilCorporal perfilCorporal,
        ServicoMedidas medidas)
    {
        _usuarios = usuarios;
        _vinculos = vinculos;
        _acesso = acesso;
        _perfilCorporal = perfilCorporal;
        _medidas = medidas;
    }

    // ---- O atleta (/me) ----

    public async Task<CompartilhamentoCorporalResposta> ObterAsync(Guid usuarioId, CancellationToken ct)
    {
        var usuario = await _usuarios.ObterPorIdAsync(usuarioId, ct)
            ?? throw new RecursoNaoEncontradoException();
        return await MontarAsync(usuario, ct);
    }

    /// <summary>
    /// Define os dois cadeados. Destrancar guarda o instante (e mantém o de
    /// antes, se já estava destrancado); trancar zera.
    /// </summary>
    public async Task<CompartilhamentoCorporalResposta> DefinirAsync(
        Guid usuarioId, bool dadosCorporais, bool medidas, CancellationToken ct)
    {
        var usuario = await _usuarios.ObterPorIdAsync(usuarioId, ct)
            ?? throw new RecursoNaoEncontradoException();
        // Em microssegundos, a precisão do timestamptz: a resposta bate com o
        // que fica gravado.
        var agoraTicks = DateTimeOffset.UtcNow.UtcTicks;
        var agora = new DateTimeOffset(agoraTicks - (agoraTicks % 10), TimeSpan.Zero);

        usuario.DadosCorporaisCompartilhadosEm = dadosCorporais
            ? usuario.DadosCorporaisCompartilhadosEm ?? agora
            : null;
        usuario.MedidasCompartilhadasEm = medidas
            ? usuario.MedidasCompartilhadasEm ?? agora
            : null;

        await _usuarios.SalvarAsync(ct);
        return await MontarAsync(usuario, ct);
    }

    private async Task<CompartilhamentoCorporalResposta> MontarAsync(
        Domain.Identidade.Usuario usuario, CancellationToken ct)
    {
        var educadores = new List<EducadorQueVe>();
        foreach (var vinculo in await _vinculos.ListarAtivosDoAlunoAsync(usuario.Id, ct))
        {
            var educador = await _usuarios.ObterPorIdAsync(vinculo.EducadorId, ct);
            if (educador is not null)
            {
                educadores.Add(new EducadorQueVe(educador.Id, educador.Nome));
            }
        }

        return new CompartilhamentoCorporalResposta(
            usuario.DadosCorporaisCompartilhadosEm is not null,
            usuario.DadosCorporaisCompartilhadosEm,
            usuario.MedidasCompartilhadasEm is not null,
            usuario.MedidasCompartilhadasEm,
            educadores.OrderBy(e => e.Nome, StringComparer.CurrentCultureIgnoreCase).ToList());
    }

    // ---- O educador (/alunos/{atletaId}) ----

    /// <summary>
    /// O corpo do aluno: cada seção vem só se estiver destrancada; trancada
    /// volta nula (não é erro, a tela mostra o cadeado).
    /// </summary>
    public async Task<CorpoDoAluno> ObterCorpoDoAlunoAsync(
        Guid educadorId, Guid atletaId, CancellationToken ct)
    {
        var aluno = await AlunoComVinculoAsync(educadorId, atletaId, ct);

        var dadosLiberados = aluno.DadosCorporaisCompartilhadosEm is not null;
        var medidasLiberadas = aluno.MedidasCompartilhadasEm is not null;

        return new CorpoDoAluno(
            dadosLiberados,
            dadosLiberados ? await _perfilCorporal.ObterAsync(atletaId, ct) : null,
            medidasLiberadas,
            medidasLiberadas ? await _medidas.ObterResumoAsync(atletaId, ct) : null);
    }

    /// <summary>Evolução de uma medida do aluno; trancado vira 403.</summary>
    public async Task<EvolucaoMedida> ObterEvolucaoDoAlunoAsync(
        Guid educadorId, Guid atletaId, string tipo, DateOnly? de, DateOnly? ate, CancellationToken ct)
    {
        var aluno = await AlunoComVinculoAsync(educadorId, atletaId, ct);
        if (aluno.MedidasCompartilhadasEm is null)
        {
            throw new CorpoNaoCompartilhadoException();
        }

        return await _medidas.ObterEvolucaoAsync(atletaId, tipo, de, ate, ct);
    }

    /// <summary>
    /// Só educador com vínculo ATIVO. Pendente, recusado, encerrado, sem vínculo
    /// e o próprio atleta respondem 404, sem revelar se o aluno existe.
    /// </summary>
    private async Task<Domain.Identidade.Usuario> AlunoComVinculoAsync(
        Guid educadorId, Guid atletaId, CancellationToken ct)
    {
        // O próprio atleta usa /me; nesta rota só o educador entra. O resto é a
        // regra única (MAS 11.3): sem vínculo ATIVO, 404.
        if (educadorId == atletaId)
        {
            throw new RecursoNaoEncontradoException();
        }

        await _acesso.GarantirAcessoAtletaAsync(educadorId, atletaId, ct);

        return await _usuarios.ObterPorIdAsync(atletaId, ct)
            ?? throw new RecursoNaoEncontradoException();
    }
}
