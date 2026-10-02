namespace DiarioTreino.Domain.Planejamento;

/// <summary>Ficha (A, B, C) dentro do plano (MER 3.7).</summary>
public class Treino
{
    public Guid Id { get; set; }
    public Guid PlanoId { get; set; }
    public string Nome { get; set; } = null!;
    public string? Descricao { get; set; }
    public short Ordem { get; set; }
    public bool Ativo { get; set; } = true;

    public PlanoTreino? Plano { get; set; }
    public ICollection<TreinoExercicio> Exercicios { get; set; } = [];
}
