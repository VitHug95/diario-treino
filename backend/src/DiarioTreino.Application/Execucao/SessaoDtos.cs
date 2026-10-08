namespace DiarioTreino.Application.Execucao;

/// <summary>
/// Rascunho de sessão a partir de uma ficha (PBI-15, GET
/// /treinos/{id}/rascunho-sessao). Cada exercício já vem com as séries
/// pré-preenchidas pelo histórico ou pelos alvos da ficha.
/// </summary>
public sealed record RascunhoSessao(
    Guid TreinoId,
    string TreinoNome,
    DateOnly Data,
    IReadOnlyList<RascunhoExercicio> Exercicios);

/// <summary>Exercício do rascunho com a origem do pré-preenchimento.</summary>
public sealed record RascunhoExercicio(
    Guid TreinoExercicioId,
    Guid ExercicioId,
    string Nome,
    string? GrupoMuscular,
    string Modalidade,
    short Ordem,
    /// <summary>Aviso de onde veio o preenchimento, ex.: "Preenchido com o
    /// último treino (27/09)" ou "Preenchido com os alvos da ficha". Nulo quando
    /// não há séries sugeridas.</summary>
    string? OrigemPreenchimento,
    IReadOnlyList<SerieRascunho> Series);

/// <summary>Série sugerida no rascunho (espelha o par intensidade/volume).</summary>
public sealed record SerieRascunho(
    short Rodada,
    short Ordem,
    string Tipo,
    short IntensidadeMetricaId,
    string IntensidadeMetricaCodigo,
    string IntensidadeMetricaNome,
    decimal? Intensidade,
    short VolumeMetricaId,
    string VolumeMetricaCodigo,
    string VolumeMetricaNome,
    decimal? Volume,
    short? DescansoSeg);

/// <summary>Pedido para gravar uma sessão (PBI-15, POST /sessoes).</summary>
public sealed record CriarSessaoRequest(
    Guid? TreinoId,
    DateOnly Data,
    short? DuracaoMin,
    string? Observacao,
    IReadOnlyList<ExercicioSessaoRequest> Exercicios);

/// <summary>
/// Exercício da sessão. Sem séries = exercício não realizado (não grava nada).
/// </summary>
public sealed record ExercicioSessaoRequest(
    Guid ExercicioId,
    Guid? TreinoExercicioId,
    IReadOnlyList<SerieRequest> Series);

/// <summary>Uma série feita de verdade.</summary>
public sealed record SerieRequest(
    short Rodada,
    short Ordem,
    string Tipo,
    short IntensidadeMetricaId,
    decimal? Intensidade,
    short VolumeMetricaId,
    decimal Volume,
    short? DescansoSeg);

/// <summary>Resposta ao criar a sessão.</summary>
public sealed record SessaoCriada(Guid Id);
