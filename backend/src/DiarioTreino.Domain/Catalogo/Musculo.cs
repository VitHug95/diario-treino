namespace DiarioTreino.Domain.Catalogo;

/// <summary>
/// Músculo, detalhe opcional dentro de um <see cref="Membro"/> (MER 3.4.2 /
/// PBI-31). Tabela de referência: PK <see cref="short"/> atribuída pela
/// aplicação, com restrição única em <c>(id, membro_id)</c> para servir de alvo
/// da FK composta de <c>exercicio</c>.
/// </summary>
public class Musculo
{
    public short Id { get; set; }
    public short MembroId { get; set; }
    public string Codigo { get; set; } = null!;
    public string Nome { get; set; } = null!;
}
