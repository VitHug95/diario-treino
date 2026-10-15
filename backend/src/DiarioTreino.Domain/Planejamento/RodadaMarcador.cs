using DiarioTreino.Domain.Comum;

namespace DiarioTreino.Domain.Planejamento;

/// <summary>
/// Marcador (tag) prescrito para uma rodada específica de um exercício da ficha
/// (TV-1). A tag é de uma série específica — por isso não cabe em
/// <see cref="EtapaPrescrita"/>, que é o molde único de todas as séries.
/// Só existe linha para rodada com tag diferente de <see cref="TagSerie.Valida"/>;
/// rodada sem linha vale <c>VALIDA</c>. PK composta (TreinoExercicioId, Rodada).
/// </summary>
public class RodadaMarcador
{
    public Guid TreinoExercicioId { get; set; }

    /// <summary>Número da série prescrita (1..Rodadas do exercício).</summary>
    public short Rodada { get; set; }

    public string Marcador { get; set; } = TagSerie.Valida;

    public TreinoExercicio? TreinoExercicio { get; set; }
}
