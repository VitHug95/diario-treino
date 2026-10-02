namespace DiarioTreino.Domain.Identidade;

/// <summary>
/// Papel do usuário (MER 3.2). Tabela separada porque uma pessoa pode ser atleta
/// e educador ao mesmo tempo. PK composta (usuario_id, papel).
/// </summary>
public class UsuarioPapel
{
    public Guid UsuarioId { get; set; }
    public string Papel { get; set; } = null!;

    public Usuario? Usuario { get; set; }
}
