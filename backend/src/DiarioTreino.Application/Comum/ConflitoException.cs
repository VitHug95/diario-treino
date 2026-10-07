namespace DiarioTreino.Application.Comum;

/// <summary>
/// Regra de negócio violada por conflito de estado (ex.: nome já existente).
/// A API traduz em 409 Conflict (Problem Details).
/// </summary>
public sealed class ConflitoException : Exception
{
    public ConflitoException(string message) : base(message)
    {
    }
}
