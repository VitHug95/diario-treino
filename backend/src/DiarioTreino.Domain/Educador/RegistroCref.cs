namespace DiarioTreino.Domain.Educador;

/// <summary>
/// Regras do número de registro e das UFs do CREF (PBI-106).
/// </summary>
public static class RegistroCref
{
    /// <summary>As 27 UFs.</summary>
    public static readonly IReadOnlyList<string> Ufs =
    [
        "AC", "AL", "AM", "AP", "BA", "CE", "DF", "ES", "GO", "MA", "MG", "MS", "MT", "PA",
        "PB", "PE", "PI", "PR", "RJ", "RN", "RO", "RR", "RS", "SC", "SE", "SP", "TO",
    ];

    /// <summary>
    /// UFs com consulta por CPF levantada na PBI-105 (docs/INVESTIGACAO-CREF.md,
    /// seção 3.1): CREF 3, 5, 6, 7, 8, 9, 10, 13, 14, 17, 20 e 22 (Spiderware) e
    /// CREF 1 e 2 (Implanta). SP tem consulta, mas sem busca por CPF; MS, PE, PI,
    /// PA, AP, AL e MA ainda sem o endereço da consulta. As outras não habilitam
    /// até haver consulta (decisão "seguir só em parte").
    /// </summary>
    public static readonly IReadOnlySet<string> UfsComConsulta = new HashSet<string>
    {
        "SC", "MG", "DF", "PR", "PB", "RN", "BA", "GO", "TO", "MT", "SE", "ES", // Spiderware
        "CE", "AM", "AC", "RO", "RR", // Spiderware (CREF 5 e 8)
        "RJ", "RS", // Implanta (CREF 1 e 2)
    };

    /// <summary>Situação que habilita: exatamente ATIVO (sem diferenciar maiúsculas).</summary>
    public const string SituacaoAtiva = "ATIVO";

    public static bool UfValida(string? uf) => uf is not null && Ufs.Contains(uf.ToUpperInvariant());

    /// <summary>
    /// Número para comparar: só os dígitos, sem prefixo de UF ("MG-") e sem
    /// zeros à esquerda. "MG-001234", "1234" e "001234" dão "1234".
    /// </summary>
    public static string Normalizar(string? numero)
    {
        var digitos = new string((numero ?? string.Empty).Where(char.IsAsciiDigit).ToArray());
        var semZeros = digitos.TrimStart('0');
        return semZeros.Length == 0 && digitos.Length > 0 ? "0" : semZeros;
    }

    public static bool MesmoNumero(string? a, string? b)
    {
        var na = Normalizar(a);
        return na.Length > 0 && na == Normalizar(b);
    }
}
