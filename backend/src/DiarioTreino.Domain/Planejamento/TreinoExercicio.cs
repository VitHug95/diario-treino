using DiarioTreino.Domain.Catalogo;

namespace DiarioTreino.Domain.Planejamento;

/// <summary>Exercício prescrito numa ficha (MER 3.8).</summary>
public class TreinoExercicio
{
    public Guid Id { get; set; }
    public Guid TreinoId { get; set; }
    public Guid ExercicioId { get; set; }
    public short Ordem { get; set; }

    /// <summary>Séries na musculação, repetições do bloco no intervalado.</summary>
    public short Rodadas { get; set; }
    public short? DescansoAlvoSeg { get; set; }
    public string? Observacao { get; set; }

    public Treino? Treino { get; set; }
    public Exercicio? Exercicio { get; set; }
    public ICollection<EtapaPrescrita> Etapas { get; set; } = [];
}
