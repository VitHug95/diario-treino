namespace DiarioTreino.Application.Catalogo;

/// <summary>
/// Membro para o filtro/cadastro (PBI-31), com seus músculos. Ordenado por
/// <c>ordem</c> para os chips aparecerem na sequência definida (MER 3.4.1).
/// </summary>
public sealed record MembroResumo(
    short Id,
    string Codigo,
    string Nome,
    short Ordem,
    IReadOnlyList<MusculoResumo> Musculos);

/// <summary>Músculo dentro de um membro (MER 3.4.2).</summary>
public sealed record MusculoResumo(
    short Id,
    string Codigo,
    string Nome);
