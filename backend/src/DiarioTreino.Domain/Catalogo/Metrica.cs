namespace DiarioTreino.Domain.Catalogo;

/// <summary>
/// Tabela de referência com o que pode ser medido (MER 3.4). Nunca é texto livre,
/// para os gráficos conseguirem agrupar. PK é <see cref="short"/> (smallint).
/// </summary>
public class Metrica
{
    public short Id { get; set; }
    public string Codigo { get; set; } = null!;
    public string Nome { get; set; } = null!;
    public string Unidade { get; set; } = null!;
    public string Eixo { get; set; } = null!;
}
