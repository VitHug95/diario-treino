namespace DiarioTreino.Application.Acesso;

/// <summary>
/// Implementação da regra do MAS 11.3:
/// <code>
/// PodeAcessarAtleta(logado, atleta) =
///     logado == atleta
///     OU existe vinculo(educador = logado, aluno = atleta, status = ATIVO)
/// </code>
/// </summary>
public sealed class ControleAcesso : IControleAcesso
{
    private readonly IRepositorioVinculo _vinculos;

    public ControleAcesso(IRepositorioVinculo vinculos)
    {
        _vinculos = vinculos;
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

        return await _vinculos.ExisteVinculoAtivoAsync(usuarioLogadoId, atletaId, ct);
    }

    public async Task GarantirAcessoAtletaAsync(
        Guid usuarioLogadoId,
        Guid atletaId,
        CancellationToken ct)
    {
        var pode = await PodeAcessarAtletaAsync(usuarioLogadoId, atletaId, ct);
        if (!pode)
        {
            throw new RecursoNaoEncontradoException();
        }
    }
}
