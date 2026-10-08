using DiarioTreino.Application.Planejamento;
using DiarioTreino.Domain.Planejamento;
using Microsoft.EntityFrameworkCore;

namespace DiarioTreino.Infrastructure.Persistencia;

public sealed class RepositorioPlano : IRepositorioPlano
{
    private readonly DiarioTreinoDbContext _db;

    public RepositorioPlano(DiarioTreinoDbContext db)
    {
        _db = db;
    }

    public async Task<PlanoTreino?> ObterPlanoAtivoAsync(Guid atletaId, CancellationToken ct)
    {
        var plano = await _db.PlanosTreino
            .FirstOrDefaultAsync(p => p.AtletaId == atletaId && p.Ativo, ct);

        if (plano is null)
        {
            return null;
        }

        // Carrega as fichas ativas, na ordem.
        plano.Treinos = await _db.Treinos
            .Where(t => t.PlanoId == plano.Id && t.Ativo)
            .OrderBy(t => t.Ordem)
            .ToListAsync(ct);

        return plano;
    }

    public void AdicionarPlano(PlanoTreino plano) => _db.PlanosTreino.Add(plano);

    public void AdicionarTreino(Treino treino) => _db.Treinos.Add(treino);

    public Task<Treino?> ObterTreinoAsync(Guid treinoId, CancellationToken ct) =>
        _db.Treinos.FirstOrDefaultAsync(t => t.Id == treinoId, ct);

    public async Task<Guid?> ObterAtletaDoTreinoAsync(Guid treinoId, CancellationToken ct)
    {
        var dados = await _db.Treinos
            .Where(t => t.Id == treinoId)
            .Join(_db.PlanosTreino, t => t.PlanoId, p => p.Id, (t, p) => p.AtletaId)
            .Cast<Guid?>()
            .FirstOrDefaultAsync(ct);
        return dados;
    }

    public async Task<short> ObterMaiorOrdemAsync(Guid planoId, CancellationToken ct)
    {
        var ordens = await _db.Treinos
            .Where(t => t.PlanoId == planoId && t.Ativo)
            .Select(t => (short?)t.Ordem)
            .ToListAsync(ct);
        return ordens.Count == 0 ? (short)0 : ordens.Max()!.Value;
    }

    // ---- Exercícios da ficha (PBI-13) ----

    public async Task<Treino?> ObterTreinoComExerciciosAsync(Guid treinoId, CancellationToken ct)
    {
        var treino = await _db.Treinos.FirstOrDefaultAsync(t => t.Id == treinoId, ct);
        if (treino is null)
        {
            return null;
        }

        treino.Exercicios = await _db.TreinoExercicios
            .Include(te => te.Exercicio)
            .Where(te => te.TreinoId == treinoId)
            .OrderBy(te => te.Ordem)
            .ToListAsync(ct);

        return treino;
    }

    public void AdicionarTreinoExercicio(TreinoExercicio treinoExercicio) =>
        _db.TreinoExercicios.Add(treinoExercicio);

    public void RemoverTreinoExercicio(TreinoExercicio treinoExercicio) =>
        _db.TreinoExercicios.Remove(treinoExercicio);

    public Task<TreinoExercicio?> ObterTreinoExercicioAsync(Guid id, CancellationToken ct) =>
        _db.TreinoExercicios.FirstOrDefaultAsync(te => te.Id == id, ct);

    public Task<List<TreinoExercicio>> ObterExerciciosDaFichaAsync(Guid treinoId, CancellationToken ct) =>
        _db.TreinoExercicios
            .Where(te => te.TreinoId == treinoId)
            .OrderBy(te => te.Ordem)
            .ToListAsync(ct);

    public async Task<short> ObterMaiorOrdemExercicioAsync(Guid treinoId, CancellationToken ct)
    {
        var ordens = await _db.TreinoExercicios
            .Where(te => te.TreinoId == treinoId)
            .Select(te => (short?)te.Ordem)
            .ToListAsync(ct);
        return ordens.Count == 0 ? (short)0 : ordens.Max()!.Value;
    }

    public Task SalvarAsync(CancellationToken ct) => _db.SaveChangesAsync(ct);
}
