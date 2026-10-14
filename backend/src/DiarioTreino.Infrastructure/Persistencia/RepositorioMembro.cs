using DiarioTreino.Application.Catalogo;
using Microsoft.EntityFrameworkCore;

namespace DiarioTreino.Infrastructure.Persistencia;

public sealed class RepositorioMembro : IRepositorioMembro
{
    private readonly DiarioTreinoDbContext _db;

    public RepositorioMembro(DiarioTreinoDbContext db)
    {
        _db = db;
    }

    public async Task<IReadOnlyList<MembroResumo>> ListarAsync(CancellationToken ct)
    {
        var membros = await _db.Membros
            .AsNoTracking()
            .OrderBy(m => m.Ordem)
            .ToListAsync(ct);

        var musculos = await _db.Musculos
            .AsNoTracking()
            .OrderBy(m => m.Nome)
            .ToListAsync(ct);

        return membros
            .Select(m => new MembroResumo(
                m.Id,
                m.Codigo,
                m.Nome,
                m.Ordem,
                musculos
                    .Where(mu => mu.MembroId == m.Id)
                    .Select(mu => new MusculoResumo(mu.Id, mu.Codigo, mu.Nome))
                    .ToList()))
            .ToList();
    }

    public Task<bool> ExisteMembroAsync(short membroId, CancellationToken ct) =>
        _db.Membros.AnyAsync(m => m.Id == membroId, ct);

    public Task<bool> MusculoPertenceAoMembroAsync(
        short musculoId, short membroId, CancellationToken ct) =>
        _db.Musculos.AnyAsync(m => m.Id == musculoId && m.MembroId == membroId, ct);
}
