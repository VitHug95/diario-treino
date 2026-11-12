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

    // Dados corporais (E12 / PBI-93), todos opcionais. Dado de saúde: só o dono
    // lê e grava; nunca vai para log nem para o GET /me. O peso não fica aqui:
    // é a medida PESO mais recente.

    /// <summary>"M" ou "F", usado só no cálculo da TMB.</summary>
    public string? Sexo { get; set; }

    public DateOnly? DataNascimento { get; set; }

    /// <summary>Altura em cm (100 a 250).</summary>
    public short? AlturaCm { get; set; }

    /// <summary>
    /// TMB informada pelo atleta (PBI-98), em kcal por dia (800 a 5000). Nula =
    /// automática (vale a calculada). Enquanto houver, é ela que vale no app; não é
    /// apagada quando os outros dados mudam.
    /// </summary>
    public short? TmbManualKcal { get; set; }

    public ICollection<UsuarioPapel> Papeis { get; set; } = [];
}
