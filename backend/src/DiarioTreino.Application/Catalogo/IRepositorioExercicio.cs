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

    /// <summary>
    /// Já existe exercício com esse nome no catálogo do usuário (comparação sem
    /// diferenciar maiúsculas)? Considera só os exercícios do próprio usuário.
    /// </summary>
    public Task<bool> ExisteNomeNoCatalogoAsync(
        Guid usuarioId,
        string nome,
        CancellationToken ct);

    public Task AdicionarAsync(Domain.Catalogo.Exercicio exercicio, CancellationToken ct);

    /// <summary>
    /// O exercício existe e está disponível para o usuário (catálogo global ou
    /// criado por ele próprio)?
    /// </summary>
    public Task<bool> ExisteDisponivelAsync(Guid exercicioId, Guid usuarioId, CancellationToken ct);

    /// <summary>
    /// Dados básicos (nome, grupo, modalidade) dos exercícios indicados, por id.
    /// Usado no detalhe da sessão (PBI-18), onde a série guarda só o id.
    /// </summary>
    public Task<IReadOnlyDictionary<Guid, ExercicioBasico>> ObterBasicosPorIdsAsync(
        IReadOnlyCollection<Guid> ids, CancellationToken ct);
}

/// <summary>Dados mínimos de um exercício para exibição.</summary>
public sealed record ExercicioBasico(
    Guid Id,
    string Nome,
    string? GrupoMuscular,
    string Modalidade);
