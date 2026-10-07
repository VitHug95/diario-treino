namespace DiarioTreino.Application.Catalogo;

/// <summary>Dados para criar um exercício próprio (PBI-11).</summary>
public sealed record CriarExercicioRequest(
    string Nome,
    string? GrupoMuscular,
    string Modalidade,
    short IntensidadeMetricaId,
    short VolumeMetricaId);
