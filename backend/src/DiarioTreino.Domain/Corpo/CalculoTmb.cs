namespace DiarioTreino.Domain.Corpo;

/// <summary>Sexo usado só no cálculo da TMB (E12 / PBI-93). Guardado como M ou F.</summary>
public static class SexoBiologico
{
    public const string Masculino = "M";
    public const string Feminino = "F";

    public static readonly IReadOnlyList<string> Todos = [Masculino, Feminino];

    public static bool EhValido(string? sexo) => sexo is not null && Todos.Contains(sexo);
}

/// <summary>Por que não há TMB: dado faltando ou menor de idade.</summary>
public static class MotivoSemTmb
{
    public const string DadosIncompletos = "DADOS_INCOMPLETOS";
    public const string MenorDeIdade = "MENOR_DE_IDADE";
}

/// <summary>Resultado do cálculo: ou há <see cref="Kcal"/>, ou há <see cref="Motivo"/>.</summary>
public sealed record ResultadoTmb(int? Kcal, string? Motivo)
{
    public static ResultadoTmb Calculada(int kcal) => new(kcal, null);

    public static ResultadoTmb Sem(string motivo) => new(null, motivo);
}

/// <summary>
/// Taxa metabólica basal pela equação de Mifflin-St Jeor (E12 / PBI-93):
/// <c>10 × peso(kg) + 6,25 × altura(cm) − 5 × idade + s</c>, com <c>s = +5</c> para
/// M e <c>−161</c> para F, arredondada ao inteiro (meio para cima). Estimativa
/// para adultos: sem número com menos de 18 anos ou com qualquer dado faltando.
/// Função pura: a data de referência entra como argumento.
/// </summary>
public static class CalculoTmb
{
    public const int IdadeMinimaAdulto = 18;

    public static ResultadoTmb Calcular(
        string? sexo,
        DateOnly? dataNascimento,
        int? alturaCm,
        decimal? pesoKg,
        DateOnly hoje)
    {
        if (!SexoBiologico.EhValido(sexo) || dataNascimento is null || alturaCm is null || pesoKg is null)
        {
            return ResultadoTmb.Sem(MotivoSemTmb.DadosIncompletos);
        }

        var idade = IdadeEm(dataNascimento.Value, hoje);
        if (idade < IdadeMinimaAdulto)
        {
            return ResultadoTmb.Sem(MotivoSemTmb.MenorDeIdade);
        }

        var constante = sexo == SexoBiologico.Masculino ? 5m : -161m;
        var kcal = (10m * pesoKg.Value) + (6.25m * alturaCm.Value) - (5m * idade) + constante;
        return ResultadoTmb.Calculada((int)Math.Round(kcal, MidpointRounding.AwayFromZero));
    }

    /// <summary>
    /// Idade em anos completos em <paramref name="hoje"/>. Quem nasceu em 29/02
    /// faz anos em 28/02 nos anos não bissextos (é o que <c>AddYears</c> faz).
    /// </summary>
    public static int IdadeEm(DateOnly nascimento, DateOnly hoje)
    {
        var idade = hoje.Year - nascimento.Year;
        if (hoje < nascimento.AddYears(idade))
        {
            idade--;
        }

        return idade;
    }
}
