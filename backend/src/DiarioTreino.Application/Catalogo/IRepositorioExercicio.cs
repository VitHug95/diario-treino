namespace DiarioTreino.Application.Catalogo;

/// <summary>Consultas do catálogo de exercícios.</summary>
public interface IRepositorioExercicio
{
    /// <summary>
    /// Lista o catálogo global (sem dono) mais os exercícios do próprio usuário,
    /// aplicando busca por nome (sem diferenciar maiúsculas e acentos) e filtro
    /// de modalidade. <paramref name="modalidade"/> nulo = todas.
    /// </summary>
    public Task<IReadOnlyList<ExercicioResumo>> BuscarAsync(
        Guid usuarioId,
        string? busca,
        string? modalidade,
        CancellationToken ct);
}
