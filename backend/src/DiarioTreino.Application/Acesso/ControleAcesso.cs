using DiarioTreino.Application.Educador;

namespace DiarioTreino.Application.Acesso;

/// <summary>
/// Implementação da regra do MAS 11.3:
/// <code>
/// PodeAcessarAtleta(logado, atleta) =
///     logado == atleta
///     OU existe vinculo(educador = logado, aluno = atleta, status = ATIVO)
/// </code>
/// </summary>
/// <remarks>
/// PBI-106: com a chave <c>Educador:ExigirCref</c> ligada, o educador com vínculo
/// ativo também precisa estar habilitado pelo CREF. Sem habilitação, o
/// <see cref="GarantirAcessoAtletaAsync"/> responde 403
/// (<see cref="EducadorNaoHabilitadoException"/>), sempre depois do 404 de quem
/// não tem vínculo. Nada é apagado: o acesso volta ao habilitar.
/// </remarks>
public sealed class ControleAcesso : IControleAcesso
{
    private readonly IRepositorioVinculo _vinculos;
    private readonly IRepositorioEducadorCref _cref;
    private readonly ConfiguracaoEducador _config;

    public ControleAcesso(
        IRepositorioVinculo vinculos,
        IRepositorioEducadorCref cref,
        ConfiguracaoEducador config)
    {
        _vinculos = vinculos;
        _cref = cref;
        _config = config;
    }

    public async Task<bool> PodeAcessarAtletaAsync(
        Guid usuarioLogadoId,
        Guid atletaId,
        CancellationToken ct)
    {
        if (usuarioLogadoId == atletaId)
        {
            return true;
        }

        return await _vinculos.ExisteVinculoAtivoAsync(usuarioLogadoId, atletaId, ct)
            && await EducadorHabilitadoAsync(usuarioLogadoId, ct);
    }

    public async Task GarantirAcessoAtletaAsync(
        Guid usuarioLogadoId,
        Guid atletaId,
        CancellationToken ct)
    {
        if (usuarioLogadoId == atletaId)
        {
            return;
        }

        // 404 primeiro: quem não é parte do vínculo nem sabe que o aluno existe.
        if (!await _vinculos.ExisteVinculoAtivoAsync(usuarioLogadoId, atletaId, ct))
        {
            throw new RecursoNaoEncontradoException();
        }

        if (!await EducadorHabilitadoAsync(usuarioLogadoId, ct))
        {
            throw new EducadorNaoHabilitadoException();
        }
    }

    private async Task<bool> EducadorHabilitadoAsync(Guid educadorId, CancellationToken ct) =>
        !_config.ExigirCref || await _cref.HabilitadoAsync(educadorId, ct);
}
