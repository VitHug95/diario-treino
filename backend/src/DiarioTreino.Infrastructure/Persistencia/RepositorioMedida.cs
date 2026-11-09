using DiarioTreino.Application.Corpo;
using DiarioTreino.Domain.Corpo;
using Microsoft.EntityFrameworkCore;

namespace DiarioTreino.Infrastructure.Persistencia;

public sealed class RepositorioMedida : IRepositorioMedida
{
    private readonly DiarioTreinoDbContext _db;

    public RepositorioMedida(DiarioTreinoDbContext db)
    {
        _db = db;
    }

    public async Task<List<MedidaCorporal>> UltimasDuasPorTipoAsync(Guid usuarioId, CancellationToken ct)
    {
        // Poucos tipos (12) e duas linhas por tipo: busca o último e o anterior de
        // cada um sem carregar o histórico inteiro.
        var tipos = TipoMedida.Todos;
        var resultado = new List<MedidaCorporal>();
        foreach (var tipo in tipos)
        {
            var duas = await _db.MedidasCorporais
                .AsNoTracking()
                .Where(m => m.UsuarioId == usuarioId && m.Tipo == tipo)
                .OrderByDescending(m => m.Data)
                .Take(2)
                .ToListAsync(ct);
            resultado.AddRange(duas);
        }

        return resultado;
    }

    public async Task<List<DiaHistoricoMedidas>> HistoricoAsync(Guid usuarioId, CancellationToken ct)
    {
        var dias = await _db.MedidasCorporais
            .AsNoTracking()
            .Where(m => m.UsuarioId == usuarioId)
            .GroupBy(m => m.Data)
            .Select(g => new { Data = g.Key, Quantidade = g.Count() })
            .OrderByDescending(d => d.Data)
            .ToListAsync(ct);

        return dias.Select(d => new DiaHistoricoMedidas(d.Data, d.Quantidade)).ToList();
    }

    public Task<List<MedidaCorporal>> ListarDoDiaAsync(Guid usuarioId, DateOnly data, CancellationToken ct) =>
        _db.MedidasCorporais
            .Where(m => m.UsuarioId == usuarioId && m.Data == data)
            .ToListAsync(ct);

    public void Adicionar(MedidaCorporal medida) => _db.MedidasCorporais.Add(medida);

    public void Remover(MedidaCorporal medida) => _db.MedidasCorporais.Remove(medida);

    public Task SalvarAsync(CancellationToken ct) => _db.SaveChangesAsync(ct);

    public Task<int> ExcluirDiaAsync(Guid usuarioId, DateOnly data, CancellationToken ct) =>
        _db.MedidasCorporais
            .Where(m => m.UsuarioId == usuarioId && m.Data == data)
            .ExecuteDeleteAsync(ct);
}
