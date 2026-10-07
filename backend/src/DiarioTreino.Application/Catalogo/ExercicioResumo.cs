namespace DiarioTreino.Application.Catalogo;

/// <summary>
/// Item do catálogo como aparece na busca (PBI-10). Traz a forma de medir
/// (métricas de intensidade e volume) e se é um exercício próprio do usuário.
/// </summary>
public sealed record ExercicioResumo(
    Guid Id,
    string Nome,
    string? GrupoMuscular,
    string Modalidade,
    string IntensidadeMetricaCodigo,
    string IntensidadeMetricaNome,
    string VolumeMetricaCodigo,
    string VolumeMetricaNome,
    bool Proprio);
