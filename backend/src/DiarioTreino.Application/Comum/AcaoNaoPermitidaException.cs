namespace DiarioTreino.Application.Comum;

/// <summary>
/// Ação barrada por falta de permissão do usuário (não por acesso a recurso de
/// outro atleta, que é 404). Ex.: convidar aluno sem ter o papel EDUCADOR. A
/// API traduz em 403 Forbidden (Problem Details).
/// </summary>
public sealed class AcaoNaoPermitidaException : Exception
{
    public AcaoNaoPermitidaException(string message) : base(message)
    {
    }
}
