using DiarioTreino.Domain.Catalogo;

namespace DiarioTreino.Domain.Planejamento;

/// <summary>
/// Etapas de cada rodada (MER 3.9). Musculação tem uma etapa; intervalado tem
/// esforço e recuperação.
/// </summary>
public class EtapaPrescrita
{
    public Guid Id { get; set; }
    public Guid TreinoExercicioId { get; set; }
    public short Ordem { get; set; }
    public string Tipo { get; set; } = null!;
    public short IntensidadeMetricaId { get; set; }

    /// <summary>Nulo = livre.</summary>
    public decimal? IntensidadeAlvo { get; set; }
    public short VolumeMetricaId { get; set; }
    public decimal? VolumeAlvo { get; set; }

    public TreinoExercicio? TreinoExercicio { get; set; }
    public Metrica? IntensidadeMetrica { get; set; }
    public Metrica? VolumeMetrica { get; set; }
}
