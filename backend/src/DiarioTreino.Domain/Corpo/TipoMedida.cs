namespace DiarioTreino.Domain.Corpo;

/// <summary>
/// Tipos de medida corporal (E12 / PBI-91). Fonte única: o CHECK da migration, a
/// validação e as faixas derivam daqui. Tipo novo = entrada aqui + migration
/// pequena do CHECK.
/// </summary>
public static class TipoMedida
{
    public const string Peso = "PESO";
    public const string Pescoco = "PESCOCO";
    public const string Ombros = "OMBROS";
    public const string Peito = "PEITO";
    public const string Cintura = "CINTURA";
    public const string Quadril = "QUADRIL";
    public const string BracoD = "BRACO_D";
    public const string BracoE = "BRACO_E";
    public const string CoxaD = "COXA_D";
    public const string CoxaE = "COXA_E";
    public const string PanturrilhaD = "PANTURRILHA_D";
    public const string PanturrilhaE = "PANTURRILHA_E";

    /// <summary>Na ordem em que o app mostra (corpo todo, tronco, braços, pernas).</summary>
    public static readonly IReadOnlyList<string> Todos =
    [
        Peso, Pescoco, Ombros, Peito, Cintura, Quadril,
        BracoD, BracoE, CoxaD, CoxaE, PanturrilhaD, PanturrilhaE,
    ];

    public static bool EhValido(string? tipo) => tipo is not null && Todos.Contains(tipo);

    /// <summary>Faixa aceita (inclusive): peso 30 a 300 kg; as demais 5 a 250 cm.</summary>
    public static (decimal Minimo, decimal Maximo) Faixa(string tipo) =>
        tipo == Peso ? (30m, 300m) : (5m, 250m);

    public static string Unidade(string tipo) => tipo == Peso ? "kg" : "cm";
}
