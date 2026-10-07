using DiarioTreino.Application.Catalogo;
using Microsoft.EntityFrameworkCore;

namespace DiarioTreino.Infrastructure.Persistencia;

public sealed class RepositorioMetrica : IRepositorioMetrica
{
    private readonly DiarioTreinoDbContext _db;

    public RepositorioMetrica(DiarioTreinoDbContext db)
    {
        _db = db;
    }

    public async Task<IReadOnlyList<MetricaResumo>> ListarAsync(CancellationToken ct)
    {
        return await _db.Metricas
            .AsNoTracking()
            .OrderBy(m => m.Eixo).ThenBy(m => m.Id)
            .Select(m => new MetricaResumo(m.Id, m.Codigo, m.Nome, m.Unidade, m.Eixo))
            .ToListAsync(ct);
    }

    public async Task<string?> ObterEixoAsync(short metricaId, CancellationToken ct)
    {
        return await _db.Metricas
            .AsNoTracking()
            .Where(m => m.Id == metricaId)
            .Select(m => m.Eixo)
            .FirstOrDefaultAsync(ct);
    }
}
