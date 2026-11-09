namespace DiarioTreino.Domain.Corpo;

/// <summary>
/// Uma medida do corpo de um usuário num dia (E12 / PBI-91): uma linha por
/// (dia, tipo). Peso é um tipo como os outros, o que dá histórico e gráfico.
/// Dado de saúde: só o dono lê e grava; nunca vai para log.
/// </summary>
public class MedidaCorporal
{
    public Guid Id { get; set; }
    public Guid UsuarioId { get; set; }

    /// <summary>Dia da medição (sem hora).</summary>
    public DateOnly Data { get; set; }

    /// <summary>Um dos códigos de <see cref="TipoMedida"/>.</summary>
    public string Tipo { get; set; } = null!;

    /// <summary>kg para <see cref="TipoMedida.Peso"/>, cm para os demais; uma casa decimal.</summary>
    public decimal Valor { get; set; }

    public DateTimeOffset CriadoEm { get; set; }
}
