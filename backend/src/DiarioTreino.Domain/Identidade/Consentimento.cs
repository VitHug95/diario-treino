namespace DiarioTreino.Domain.Identidade;

/// <summary>
/// Aceite de um termo de consentimento pelo usuário (MER 7, LGPD). Registra que
/// o atleta autorizou o acesso de educadores vinculados aos seus dados. Guarda a
/// versão do termo aceita e quando. A estrutura entra na PBI-87; o uso como
/// porteira do acesso do educador é ligado na PBI-88 (quando houver a tela que
/// apresenta o termo para o aluno aceitar).
/// </summary>
public class Consentimento
{
    public Guid Id { get; set; }
    public Guid UsuarioId { get; set; }

    /// <summary>Versão do termo aceita (ex.: "1"). O texto do termo vive no app.</summary>
    public string VersaoTermo { get; set; } = null!;
    public DateTimeOffset AceitoEm { get; set; }

    public Usuario? Usuario { get; set; }
}
