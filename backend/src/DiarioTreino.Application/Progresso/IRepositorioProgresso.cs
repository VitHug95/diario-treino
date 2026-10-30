namespace DiarioTreino.Application.Progresso;

/// <summary>
/// Grandeza que o gráfico de evolução acompanha, decidida por exercício
/// (PBI-73): força com carga usa a carga; força sem carga (ex.: peso corporal)
/// e isometria usam o volume (repetições/tempo).
/// </summary>
public enum MetricaProgresso
{
    /// <summary>Maior carga (intensidade) por sessão, com as reps daquela série.</summary>
    Carga,

    /// <summary>Maior volume (repetições) por sessão; sem segundo valor.</summary>
    Repeticoes,

    /// <summary>Maior tempo sustentado (volume) por sessão; sem segundo valor.</summary>
    Tempo,
}

/// <summary>Consultas de evolução por exercício (PBI-20).</summary>
public interface IRepositorioProgresso
{
    /// <summary>
    /// Um ponto por sessão do atleta que tem o exercício (séries de esforço),
    /// no período, em ordem crescente de data. Conforme <paramref name="metrica"/>:
    /// <list type="bullet">
    /// <item><c>Carga</c>: <c>Valor</c> = maior carga da sessão e
    /// <c>Repeticoes</c> = repetições daquela série de maior carga.</item>
    /// <item><c>Repeticoes</c>/<c>Tempo</c>: <c>Valor</c> = maior volume
    /// (reps/tempo) da sessão; <c>Repeticoes</c> = nulo.</item>
    /// </list>
    /// </summary>
    public Task<IReadOnlyList<PontoBruto>> ObterPontosAsync(
        Guid atletaId,
        Guid exercicioId,
        MetricaProgresso metrica,
        DateOnly? de,
        DateOnly? ate,
        CancellationToken ct);

    /// <summary>
    /// Indica se o exercício tem ALGUMA série de esforço com carga
    /// (intensidade preenchida) do atleta, no período. Decide se o gráfico de
    /// força usa a carga ou cai para repetições (PBI-73).
    /// </summary>
    public Task<bool> ExercicioTemCargaAsync(
        Guid atletaId,
        Guid exercicioId,
        DateOnly? de,
        DateOnly? ate,
        CancellationToken ct);

    /// <summary>
    /// Exercícios que o atleta já treinou (têm séries de esforço em alguma
    /// sessão dele), com nome e modalidade, em ordem alfabética. Base do seletor
    /// do gráfico de progresso.
    /// </summary>
    public Task<IReadOnlyList<ExercicioComHistorico>> ListarExerciciosComHistoricoAsync(
        Guid atletaId, CancellationToken ct);
}

/// <summary>Ponto bruto vindo do banco, antes de virar DTO.</summary>
public sealed record PontoBruto(
    DateOnly Data,
    decimal Valor,
    decimal? Repeticoes,
    Guid SessaoId,
    string? Observacao,
    bool ObservacaoPrivada = false)
{
    /// <summary>Houve observação registrada na sessão deste ponto.</summary>
    public bool TemObservacao => Observacao != null;
}
