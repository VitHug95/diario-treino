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
    string Modalidade,
    short Ordem,
    /// <summary>Aviso de onde veio o preenchimento, ex.: "Preenchido com o
    /// último treino (27/09)" ou "Preenchido com os alvos da ficha". Nulo quando
    /// não há séries sugeridas.</summary>
    string? OrigemPreenchimento,
    IReadOnlyList<SerieRascunho> Series);

/// <summary>
/// Rascunho de UM exercício avulso, para o treino livre (PBI-19, GET
/// /exercicios/{id}/ultima-execucao). Sem ficha nem treino_exercicio: traz as
/// séries da última vez que o atleta fez o exercício ou, se nunca fez, uma
/// série em branco com as métricas padrão. É o "mostra a última execução como
/// referência" montado no servidor.
/// </summary>
public sealed record RascunhoExercicioAvulso(
    Guid ExercicioId,
    string Nome,
    string Modalidade,
    /// <summary>Aviso de origem ("Preenchido com o último treino (27/09)") ou
    /// nulo quando a série vem em branco.</summary>
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

/// <summary>
/// Detalhe de uma sessão registrada (PBI-18, GET /sessoes/{id}). Agrupa as
/// séries por exercício, mostra o plano prescrito ao lado quando a sessão veio
/// de uma ficha, e marca os exercícios da ficha que não foram feitos.
/// </summary>
public sealed record SessaoDetalhe(
    Guid Id,
    Guid? TreinoId,
    string? TreinoNome,
    DateOnly Data,
    short? DuracaoMin,
    string? Observacao,
    IReadOnlyList<ExercicioSessaoDetalhe> Exercicios);

/// <summary>
/// Exercício dentro do detalhe da sessão, com as séries feitas e, quando houver
/// prescrição, o resumo do plano ("Plano: 3 × 10 com 30 kg").
/// </summary>
public sealed record ExercicioSessaoDetalhe(
    Guid ExercicioId,
    Guid? TreinoExercicioId,
    string Nome,
    string Modalidade,
    short Ordem,
    /// <summary>True = exercício da ficha sem séries feitas nesta sessão.</summary>
    bool NaoRealizado,
    /// <summary>True = exercício que não estava na ficha (fora do plano).</summary>
    bool ForaDaFicha,
    /// <summary>Resumo do plano prescrito, ou nulo se não há prescrição.</summary>
    string? Plano,
    IReadOnlyList<SerieDetalhe> Series);

/// <summary>
/// Item da listagem de sessões por período (PBI-22, GET /sessoes). Enxuto: só
/// o que a lista mostra. "Treino livre" fica a cargo da UI (TreinoNome nulo).
/// </summary>
public sealed record SessaoResumo(
    Guid Id,
    DateOnly Data,
    Guid? TreinoId,
    /// <summary>Nome da ficha; nulo = treino sem ficha ("Treino livre").</summary>
    string? TreinoNome,
    /// <summary>Quantidade de exercícios distintos realizados na sessão.</summary>
    int QuantidadeExercicios,
    short? DuracaoMin,
    /// <summary>True quando a sessão tem observação (selo "Obs.").</summary>
    bool TemObservacao);

/// <summary>Uma série feita, como aparece no detalhe da sessão.</summary>
public sealed record SerieDetalhe(
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
    decimal Volume,
    short? DescansoSeg);
