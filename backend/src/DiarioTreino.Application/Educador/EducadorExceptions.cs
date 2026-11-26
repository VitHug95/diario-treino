namespace DiarioTreino.Application.Educador;

/// <summary>
/// Educador sem habilitação pelo CREF (PBI-106): tem o papel, mas não passou pela
/// verificação. Vira 403 <c>educador-nao-habilitado</c>, sempre depois do 404 de
/// quem não é parte do vínculo. Vínculos e dados dos alunos continuam lá.
/// </summary>
public sealed class EducadorNaoHabilitadoException : Exception
{
    public EducadorNaoHabilitadoException()
        : base("Confirme seu registro no CREF para continuar.")
    {
    }
}

/// <summary>Mais de 5 tentativas em 24 h (PBI-106). Vira 429.</summary>
public sealed class LimiteTentativasCrefException : Exception
{
    public LimiteTentativasCrefException()
        : base("Você já tentou 5 vezes hoje. Tente amanhã.")
    {
    }
}
