namespace DiarioTreino.Domain.Educador;

/// <summary>
/// Conferência local do CPF (PBI-106): 11 dígitos e os dois dígitos
/// verificadores. Serve para não consultar o CREF com um CPF que não existe. O
/// CPF nunca é guardado nem logado; esta classe só lê.
/// </summary>
public static class Cpf
{
    /// <summary>Só os dígitos (aceita o texto com pontos e traço).</summary>
    public static string SoDigitos(string? texto) =>
        new((texto ?? string.Empty).Where(char.IsAsciiDigit).ToArray());

    /// <summary>
    /// Verdadeiro para 11 dígitos com os verificadores certos. Sequências de um
    /// dígito só (000.000.000-00, 111...) passam na conta, mas não existem.
    /// </summary>
    public static bool EhValido(string? texto)
    {
        var d = SoDigitos(texto);
        if (d.Length != 11 || d.Distinct().Count() == 1)
        {
            return false;
        }

        return Verificador(d, 9) == d[9] - '0' && Verificador(d, 10) == d[10] - '0';
    }

    private static int Verificador(string d, int quantos)
    {
        var soma = 0;
        for (var i = 0; i < quantos; i++)
        {
            soma += (d[i] - '0') * (quantos + 1 - i);
        }
        var resto = soma % 11;
        return resto < 2 ? 0 : 11 - resto;
    }
}
