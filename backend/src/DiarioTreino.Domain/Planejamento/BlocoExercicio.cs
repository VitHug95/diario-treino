namespace DiarioTreino.Domain.Planejamento;

/// <summary>
/// Bloco conjugado da ficha (PBI-101, MER 3.8a): dois a quatro exercícios feitos
/// alternando, com um descanso só depois de cada rodada. As rodadas não são
/// coluna: valem o maior número de séries entre os membros
/// (<see cref="RegrasBloco.Rodadas"/>). Dentro do bloco, o descanso de cada
/// membro (<see cref="TreinoExercicio.DescansoAlvoSeg"/>) é ignorado.
/// </summary>
public class BlocoExercicio
{
    public Guid Id { get; set; }
    public Guid TreinoId { get; set; }

    /// <summary>Descanso depois de cada rodada; nulo ou zero = sem descanso.</summary>
    public short? DescansoSeg { get; set; }

    public Treino? Treino { get; set; }
    public ICollection<TreinoExercicio> Membros { get; set; } = [];
}
