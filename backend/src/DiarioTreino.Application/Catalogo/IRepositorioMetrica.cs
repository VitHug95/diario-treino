namespace DiarioTreino.Application.Catalogo;

/// <summary>Consultas da tabela de referência de métricas.</summary>
public interface IRepositorioMetrica
{
    /// <summary>Lista todas as métricas, ordenadas por eixo e id.</summary>
    public Task<IReadOnlyList<MetricaResumo>> ListarAsync(CancellationToken ct);

    /// <summary>Eixo (INTENSIDADE/VOLUME) de uma métrica, ou nulo se não existir.</summary>
    public Task<string?> ObterEixoAsync(short metricaId, CancellationToken ct);
}
