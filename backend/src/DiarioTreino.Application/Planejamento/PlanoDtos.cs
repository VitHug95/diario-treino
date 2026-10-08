namespace DiarioTreino.Application.Planejamento;

/// <summary>Plano ativo do atleta com suas fichas (PBI-12).</summary>
public sealed record PlanoAtivo(
    Guid Id,
    string Nome,
    IReadOnlyList<TreinoResumo> Treinos);

/// <summary>Ficha (treino) dentro do plano.</summary>
public sealed record TreinoResumo(
    Guid Id,
    string Nome,
    string? Descricao,
    short Ordem);

/// <summary>Dados para criar/renomear uma ficha.</summary>
public sealed record SalvarTreinoRequest(string Nome, string? Descricao);

/// <summary>Ficha com seus exercícios prescritos (PBI-13).</summary>
public sealed record TreinoDetalhe(
    Guid Id,
    string Nome,
    string? Descricao,
    short Ordem,
    IReadOnlyList<TreinoExercicioResumo> Exercicios);

/// <summary>Exercício prescrito dentro de uma ficha.</summary>
public sealed record TreinoExercicioResumo(
    Guid Id,
    Guid ExercicioId,
    string Nome,
    string? GrupoMuscular,
    string Modalidade,
    short Ordem,
    short Rodadas);

/// <summary>Pedido para adicionar um exercício do catálogo à ficha.</summary>
public sealed record AdicionarExercicioRequest(Guid ExercicioId);

/// <summary>Nova ordem dos exercícios da ficha (ids na sequência desejada).</summary>
public sealed record ReordenarExerciciosRequest(IReadOnlyList<Guid> TreinoExercicioIds);
