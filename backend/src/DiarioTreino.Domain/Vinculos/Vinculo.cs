namespace DiarioTreino.Domain.Vinculos;

/// <summary>
/// Relação entre educador e aluno (MER 3.3). Estrutura pronta, uso futuro.
/// É a base da regra de acesso do educador.
/// </summary>
public class Vinculo
{
    public Guid Id { get; set; }
    public Guid EducadorId { get; set; }
    public Guid AlunoId { get; set; }
    public string Status { get; set; } = null!;
    public DateTimeOffset? Inicio { get; set; }
    public DateTimeOffset? Fim { get; set; }
}
