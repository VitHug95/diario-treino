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

    public async Task<PlanoTreino?> ObterPlanoEmUsoAsync(Guid atletaId, CancellationToken ct)
    {
        // "Plano em uso" (PBI-44) é o que a Início segue. Antes era o único
        // ativo; agora o atleta pode ter vários ativos e no máximo um em uso.
        var plano = await _db.PlanosTreino
            .FirstOrDefaultAsync(p => p.AtletaId == atletaId && p.EmUso, ct);

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

    public Task<bool> AtletaTemAlgumPlanoAsync(Guid atletaId, CancellationToken ct) =>
        _db.PlanosTreino.AnyAsync(p => p.AtletaId == atletaId, ct);

    public async Task<List<PlanoDaLista>> ListarPlanosDoAtletaAsync(Guid atletaId, CancellationToken ct)
    {
        // Planos ativos do atleta (os excluídos-com-histórico, ativo=false,
        // somem da lista). Em uso primeiro, depois pelo início mais recente.
        var planos = await _db.PlanosTreino
            .Where(p => p.AtletaId == atletaId && p.Ativo)
            .OrderByDescending(p => p.EmUso)
            .ThenByDescending(p => p.Inicio)
            .Select(p => new
            {
                p.Id,
                p.Nome,
                p.Inicio,
                p.EmUso,
                Autor = _db.Usuarios.Where(u => u.Id == p.AutorId).Select(u => u.Nome).FirstOrDefault(),
                SomenteLeitura = p.AutorId != p.AtletaId,
                // Fichas ativas do plano e a soma dos exercícios delas.
                QuantidadeFichas = _db.Treinos.Count(t => t.PlanoId == p.Id && t.Ativo),
                QuantidadeExercicios = _db.TreinoExercicios.Count(te =>
                    _db.Treinos.Any(t => t.Id == te.TreinoId && t.PlanoId == p.Id && t.Ativo)),
            })
            .ToListAsync(ct);

        return planos
            .Select(p => new PlanoDaLista(
                p.Id, p.Nome, p.Inicio, p.EmUso, p.Autor ?? string.Empty,
                p.SomenteLeitura, p.QuantidadeFichas, p.QuantidadeExercicios))
            .ToList();
    }

    public async Task<Guid?> ObterAtletaDoPlanoAsync(Guid planoId, CancellationToken ct)
    {
        var atleta = await _db.PlanosTreino
            .Where(p => p.Id == planoId && p.Ativo)
            .Select(p => (Guid?)p.AtletaId)
            .FirstOrDefaultAsync(ct);
        return atleta;
    }

    public async Task<PlanoDetalhe?> ObterPlanoParaDetalheAsync(Guid planoId, CancellationToken ct)
    {
        var plano = await _db.PlanosTreino
            .Where(p => p.Id == planoId && p.Ativo)
            .Select(p => new
            {
                p.Id,
                p.Nome,
                p.Inicio,
                p.EmUso,
                Autor = _db.Usuarios.Where(u => u.Id == p.AutorId).Select(u => u.Nome).FirstOrDefault(),
                SomenteLeitura = p.AutorId != p.AtletaId,
            })
            .FirstOrDefaultAsync(ct);

        if (plano is null)
        {
            return null;
        }

        var treinos = await _db.Treinos
            .Where(t => t.PlanoId == planoId && t.Ativo)
            .OrderBy(t => t.Ordem)
            .Select(t => new TreinoResumo(t.Id, t.Nome, t.Descricao, t.Ordem))
            .ToListAsync(ct);

        return new PlanoDetalhe(
            plano.Id, plano.Nome, plano.Inicio, plano.EmUso,
            plano.Autor ?? string.Empty, plano.SomenteLeitura, treinos);
    }

    public void AdicionarPlano(PlanoTreino plano) => _db.PlanosTreino.Add(plano);

    public void AdicionarTreino(Treino treino) => _db.Treinos.Add(treino);

    public Task<Treino?> ObterTreinoAsync(Guid treinoId, CancellationToken ct) =>
        _db.Treinos.FirstOrDefaultAsync(t => t.Id == treinoId, ct);

    public Task<bool> TreinoTemSessoesAsync(Guid treinoId, CancellationToken ct) =>
        _db.Sessoes.AnyAsync(s => s.TreinoId == treinoId, ct);

    public void RemoverTreino(Treino treino) => _db.Treinos.Remove(treino);

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
            .Include(te => te.Etapas)
            .Include(te => te.Marcadores)
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

    public Task<TreinoExercicio?> ObterTreinoExercicioComEtapasAsync(Guid id, CancellationToken ct) =>
        _db.TreinoExercicios
            .Include(te => te.Etapas)
            .Include(te => te.Marcadores)
            .FirstOrDefaultAsync(te => te.Id == id, ct);

    public async Task<(string Codigo, string Nome)?> ObterMetricaAsync(
        short metricaId, CancellationToken ct)
    {
        var m = await _db.Metricas
            .Where(x => x.Id == metricaId)
            .Select(x => new { x.Codigo, x.Nome })
            .FirstOrDefaultAsync(ct);
        return m is null ? null : (m.Codigo, m.Nome);
    }

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

    public void AdicionarEtapa(EtapaPrescrita etapa) => _db.EtapasPrescritas.Add(etapa);

    public void RemoverEtapa(EtapaPrescrita etapa) => _db.EtapasPrescritas.Remove(etapa);

    public void AdicionarMarcador(RodadaMarcador marcador) => _db.RodadaMarcadores.Add(marcador);

    public void RemoverMarcador(RodadaMarcador marcador) => _db.RodadaMarcadores.Remove(marcador);

    public Task SalvarAsync(CancellationToken ct) => _db.SaveChangesAsync(ct);
}
