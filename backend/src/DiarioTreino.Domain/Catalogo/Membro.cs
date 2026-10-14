namespace DiarioTreino.Domain.Catalogo;

/// <summary>
/// Membro (região do corpo) usado para filtrar e organizar exercícios
/// (MER 3.4.1 / ADR-10). Tabela de referência: PK <see cref="short"/> atribuída
/// pela aplicação. Substitui o antigo texto livre <c>grupo_muscular</c>.
/// </summary>
public class Membro
{
    public short Id { get; set; }
    public string Codigo { get; set; } = null!;
    public string Nome { get; set; } = null!;
    public short Ordem { get; set; }
}
