namespace DiarioTreino.Application.Acesso;

/// <summary>Consultas de vínculo necessárias ao controle de acesso.</summary>
public interface IRepositorioVinculo
{
    /// <summary>
    /// Verdadeiro se existe vínculo ATIVO entre o educador e o aluno informados.
    /// </summary>
    public Task<bool> ExisteVinculoAtivoAsync(
        Guid educadorId,
        Guid alunoId,
        CancellationToken ct);
}
