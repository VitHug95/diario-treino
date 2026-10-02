using DiarioTreino.Domain.Catalogo;
using DiarioTreino.Domain.Planejamento;

namespace DiarioTreino.Domain.Execucao;

/// <summary>O que de fato aconteceu, série por série (MER 3.11).</summary>
public class SerieExecutada
{
    public Guid Id { get; set; }
    public Guid SessaoId { get; set; }
    public Guid ExercicioId { get; set; }

    /// <summary>Nulo = fora do plano. Liga ao prescrito para comparação.</summary>
    public Guid? TreinoExercicioId { get; set; }
    public short Rodada { get; set; }
    public short Ordem { get; set; }
    public string Tipo { get; set; } = null!;
    public short IntensidadeMetricaId { get; set; }

    /// <summary>Nulo quando a métrica é peso corporal.</summary>
    public decimal? Intensidade { get; set; }
    public short VolumeMetricaId { get; set; }
    public decimal Volume { get; set; }
    public short? DescansoSeg { get; set; }

    public Sessao? Sessao { get; set; }
    public Exercicio? Exercicio { get; set; }
    public TreinoExercicio? TreinoExercicio { get; set; }
}
