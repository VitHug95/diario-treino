namespace DiarioTreino.Application.Acesso;

/// <summary>
/// Regra única de autorização (MAS 11.3). Todo caso de uso que lê ou grava dados
/// de um atleta passa por aqui; a regra nunca é reescrita no endpoint.
/// </summary>
public interface IControleAcesso
{
    /// <summary>
    /// Verdadeiro se o usuário logado pode acessar os dados do atleta: é o
    /// próprio atleta OU é educador com vínculo ATIVO com ele.
    /// </summary>
    public Task<bool> PodeAcessarAtletaAsync(
        Guid usuarioLogadoId,
        Guid atletaId,
        CancellationToken ct);

    /// <summary>
    /// Garante o acesso; se não puder, lança <see cref="RecursoNaoEncontradoException"/>
    /// para a API responder 404 (não 403), sem revelar que o recurso existe.
    /// </summary>
    public Task GarantirAcessoAtletaAsync(
        Guid usuarioLogadoId,
        Guid atletaId,
        CancellationToken ct);
}
