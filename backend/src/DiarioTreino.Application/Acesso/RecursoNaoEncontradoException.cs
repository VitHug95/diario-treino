namespace DiarioTreino.Application.Acesso;

/// <summary>
/// Lançada quando o recurso não existe OU o usuário não tem acesso a ele. Em
/// ambos os casos a API responde 404 (MAS 11.3): não revelar que o recurso
/// existe para quem não pode vê-lo.
/// </summary>
public sealed class RecursoNaoEncontradoException : Exception
{
    public RecursoNaoEncontradoException()
        : base("Recurso não encontrado.")
    {
    }

    public RecursoNaoEncontradoException(string message)
        : base(message)
    {
    }
}
