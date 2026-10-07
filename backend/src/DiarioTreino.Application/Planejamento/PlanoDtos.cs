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
