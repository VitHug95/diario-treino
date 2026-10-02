namespace DiarioTreino.Domain.Identidade;

/// <summary>
/// Pessoa que usa o app (MER 3.1). A identidade (senha, Google) fica no Firebase;
/// aqui fica o vínculo com o domínio.
/// </summary>
public class Usuario
{
    public Guid Id { get; set; }
    public string FirebaseUid { get; set; } = null!;
    public string Nome { get; set; } = null!;
    public string Email { get; set; } = null!;
    public bool Ativo { get; set; } = true;
    public DateTimeOffset CriadoEm { get; set; }

    public ICollection<UsuarioPapel> Papeis { get; set; } = [];
}
