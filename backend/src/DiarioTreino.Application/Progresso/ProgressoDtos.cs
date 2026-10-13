namespace DiarioTreino.Application.Progresso;

/// <summary>
/// Evolução de um exercício ao longo do tempo (PBI-20, GET
/// /progresso/exercicios/{id}). A métrica mostrada depende da modalidade:
/// força = maior carga por sessão (com as repetições daquela carga);
/// isometria = maior tempo sustentado por sessão.
/// </summary>
public sealed record ProgressoExercicio(
    Guid ExercicioId,
    string Nome,
    string Modalidade,
    /// <summary>
    /// Qual grandeza o gráfico mostra: "CARGA" (força) ou "TEMPO" (isometria).
    /// Nulo quando a modalidade não tem gráfico de evolução no MVP (cardio).
    /// </summary>
    string? Metrica,
    IReadOnlyList<PontoProgresso> Pontos,
    ResumoProgresso Resumo);

/// <summary>
/// Um ponto do gráfico (uma sessão). Para força, <see cref="Valor"/> é a maior
/// carga e <see cref="Repeticoes"/> as reps daquela série de maior carga. Para
/// isometria, <see cref="Valor"/> é o maior tempo e <see cref="Repeticoes"/> é
/// nulo.
/// </summary>
public sealed record PontoProgresso(
    DateOnly Data,
    decimal Valor,
    decimal? Repeticoes);

/// <summary>Resumo do período mostrado no gráfico.</summary>
public sealed record ResumoProgresso(
    int Sessoes,
    /// <summary>Variação do valor entre o primeiro e o último ponto (último −
    /// primeiro). Nula quando há menos de dois pontos.</summary>
    decimal? Variacao,
    int SessoesComObservacao);
