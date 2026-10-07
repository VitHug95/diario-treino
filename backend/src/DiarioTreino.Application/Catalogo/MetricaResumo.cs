namespace DiarioTreino.Application.Catalogo;

/// <summary>Métrica disponível para medir intensidade ou volume (MER 3.4).</summary>
public sealed record MetricaResumo(
    short Id,
    string Codigo,
    string Nome,
    string Unidade,
    string Eixo);
