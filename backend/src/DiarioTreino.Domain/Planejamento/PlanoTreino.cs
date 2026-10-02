namespace DiarioTreino.Domain.Planejamento;

/// <summary>
/// Conjunto de fichas de um atleta (MER 3.6). No MVP, autor e atleta são a mesma
/// pessoa. Um plano ativo por atleta (índice único parcial).
/// </summary>
public class PlanoTreino
{
    public Guid Id { get; set; }
    public Guid AutorId { get; set; }
    public Guid AtletaId { get; set; }
    public string Nome { get; set; } = null!;
    public DateOnly Inicio { get; set; }
    public DateOnly? Fim { get; set; }
    public bool Ativo { get; set; } = true;

    public ICollection<Treino> Treinos { get; set; } = [];
}
