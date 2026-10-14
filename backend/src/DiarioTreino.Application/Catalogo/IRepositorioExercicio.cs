namespace DiarioTreino.Application.Catalogo;

/// <summary>Consultas do catálogo de exercícios.</summary>
public interface IRepositorioExercicio
{
    /// <summary>
    /// Lista o catálogo global (sem dono) mais os exercícios do próprio usuário,
    /// aplicando busca por nome (sem diferenciar maiúsculas e acentos), filtro de
    /// modalidade e filtro de membro (PBI-31). Qualquer filtro nulo = sem filtro.
    /// </summary>
    public Task<IReadOnlyList<ExercicioResumo>> BuscarAsync(
        Guid usuarioId,
        string? busca,
        string? modalidade,
        short? membroId,
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

    /// <summary>
    /// Exercício disponível ao usuário (global ou próprio), com as métricas
    /// padrão, para montar o rascunho de treino livre (PBI-19). Nulo se não
    /// existe ou não está disponível para o usuário.
    /// </summary>
    public Task<ExercicioParaRascunho?> ObterParaRascunhoAsync(
        Guid exercicioId, Guid usuarioId, CancellationToken ct);
}

/// <summary>Dados mínimos de um exercício para exibição.</summary>
public sealed record ExercicioBasico(
    Guid Id,
    string Nome,
    string Modalidade);

/// <summary>
/// Exercício com as métricas padrão, para montar uma série em branco no treino
/// livre (PBI-19).
/// </summary>
public sealed record ExercicioParaRascunho(
    Guid Id,
    string Nome,
    string Modalidade,
    short IntensidadeMetricaPadraoId,
    short VolumeMetricaPadraoId);
