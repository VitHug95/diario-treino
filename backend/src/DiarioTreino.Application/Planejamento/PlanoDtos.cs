namespace DiarioTreino.Application.Planejamento;

/// <summary>Plano ativo do atleta com suas fichas (PBI-12).</summary>
public sealed record PlanoAtivo(
    Guid Id,
    string Nome,
    IReadOnlyList<TreinoResumo> Treinos);

/// <summary>
/// Um plano na lista de planos do atleta (PBI-44, GET /planos). Traz o resumo
/// que a tela 18 mostra: em uso, autoria (para o chip "Do professor") e as
/// contagens de fichas e exercícios.
/// </summary>
public sealed record PlanoDaLista(
    Guid Id,
    string Nome,
    DateOnly Inicio,
    bool EmUso,
    /// <summary>Nome do autor do plano (para "Prof. Nome" quando não é o atleta).</summary>
    string Autor,
    /// <summary>true quando autor ≠ atleta: o atleta só lê, treina e copia.</summary>
    bool SomenteLeitura,
    int QuantidadeFichas,
    int QuantidadeExercicios);

/// <summary>
/// Detalhe de um plano com suas fichas (PBI-44, GET /planos/{id}). No mesmo
/// formato de fichas do <see cref="PlanoAtivo"/>, mais o estado de uso e a
/// autoria para o cabeçalho da tela 19/20.
/// </summary>
public sealed record PlanoDetalhe(
    Guid Id,
    string Nome,
    DateOnly Inicio,
    bool EmUso,
    string Autor,
    bool SomenteLeitura,
    IReadOnlyList<TreinoResumo> Treinos);

/// <summary>Dados para criar/renomear um plano (PBI-44).</summary>
public sealed record SalvarPlanoRequest(string Nome);

/// <summary>Ficha (treino) dentro do plano.</summary>
public sealed record TreinoResumo(
    Guid Id,
    string Nome,
    string? Descricao,
    short Ordem);

/// <summary>Dados para criar/renomear uma ficha.</summary>
public sealed record SalvarTreinoRequest(string Nome, string? Descricao);

/// <summary>
/// Pedido para criar uma ficha a partir dos exercícios de um treino livre
/// (PBI-19, "Salvar também como ficha"). <see cref="ExercicioIds"/> entram na
/// ordem informada; os alvos ficam para o atleta definir depois (PBI-14).
/// </summary>
public sealed record CriarFichaDeTreinoRequest(
    string Nome,
    string? Descricao,
    IReadOnlyList<Guid> ExercicioIds);

/// <summary>Ficha com seus exercícios prescritos (PBI-13).</summary>
public sealed record TreinoDetalhe(
    Guid Id,
    string Nome,
    string? Descricao,
    short Ordem,
    IReadOnlyList<TreinoExercicioResumo> Exercicios,
    /// <summary>
    /// Ficha de plano do professor (autor ≠ atleta): o atleta só lê e treina.
    /// O app usa para não perguntar "Manter na ficha?" (PBI-72).
    /// </summary>
    bool SomenteLeitura = false);

/// <summary>
/// Exercício prescrito dentro de uma ficha, com os alvos (PBI-14).
/// <see cref="Alvo"/> é nulo até o atleta definir séries/alvos.
/// <see cref="Marcadores"/> traz só as rodadas com tag ≠ VALIDA (TV-1).
/// </summary>
public sealed record TreinoExercicioResumo(
    Guid Id,
    Guid ExercicioId,
    string Nome,
    string Modalidade,
    short Ordem,
    short Rodadas,
    short? DescansoSeg,
    string? Instrucao,
    AlvoExercicio? Alvo,
    IReadOnlyList<MarcadorRodada> Marcadores);

/// <summary>
/// Tag prescrita para uma rodada de um exercício da ficha (TV-1). Só trafega o
/// que for diferente de VALIDA; rodada ausente vale VALIDA.
/// </summary>
public sealed record MarcadorRodada(short Rodada, string Marcador);

/// <summary>Alvos prescritos de um exercício (etapa de esforço).</summary>
public sealed record AlvoExercicio(
    short IntensidadeMetricaId,
    string IntensidadeMetricaCodigo,
    string IntensidadeMetricaNome,
    decimal? IntensidadeAlvo,
    short VolumeMetricaId,
    string VolumeMetricaCodigo,
    string VolumeMetricaNome,
    decimal? VolumeAlvo,
    /// <summary>Máximo da faixa de volume (TV-2); nulo = sem faixa.</summary>
    decimal? VolumeAlvoMax);

/// <summary>Pedido para adicionar um exercício do catálogo à ficha.</summary>
public sealed record AdicionarExercicioRequest(Guid ExercicioId);

/// <summary>Nova ordem dos exercícios da ficha (ids na sequência desejada).</summary>
public sealed record ReordenarExerciciosRequest(IReadOnlyList<Guid> TreinoExercicioIds);

/// <summary>
/// Alvos do exercício na ficha (PBI-14, tela 10). <see cref="Marcadores"/>
/// (TV-1) é opcional e só precisa trazer as rodadas com tag ≠ VALIDA.
/// </summary>
public sealed record DefinirAlvosRequest(
    short Series,
    short IntensidadeMetricaId,
    decimal? IntensidadeAlvo,
    short VolumeMetricaId,
    decimal? VolumeAlvo,
    short? DescansoSeg,
    string? Instrucao,
    IReadOnlyList<MarcadorRodada>? Marcadores = null,
    /// <summary>Máximo da faixa de volume (TV-2); opcional. Exige VolumeAlvo.</summary>
    decimal? VolumeAlvoMax = null);
