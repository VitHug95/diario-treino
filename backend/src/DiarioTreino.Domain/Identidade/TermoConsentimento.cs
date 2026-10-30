namespace DiarioTreino.Domain.Identidade;

/// <summary>
/// Termo de consentimento LGPD (PBI-87/88). O texto do termo vive no app; aqui
/// fica só a versão vigente, registrada no <see cref="Consentimento"/> quando o
/// aluno aceita um convite de educador. Subir a versão (novo texto do termo)
/// passa a exigir novo aceite.
/// </summary>
public static class TermoConsentimento
{
    /// <summary>Versão vigente do termo. Incrementar ao mudar o texto do termo.</summary>
    public const string VersaoVigente = "1";
}
