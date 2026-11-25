namespace DiarioTreino.Application.Corpo;

/// <summary>
/// O educador tem vínculo ativo, mas o aluno não liberou esta parte do corpo
/// (PBI-95). Vira 403 <c>corpo-nao-compartilhado</c>, sempre depois do controle
/// de acesso (sem vínculo é 404, MAS 11.3).
/// </summary>
public sealed class CorpoNaoCompartilhadoException : Exception
{
    public CorpoNaoCompartilhadoException()
        : base("O aluno não compartilhou esta informação.")
    {
    }
}
