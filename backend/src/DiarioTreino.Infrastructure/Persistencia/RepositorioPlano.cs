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

        var semana = await ObterSemanaAsync(planoId, ct);

        return new PlanoDetalhe(
            plano.Id, plano.Nome, plano.Inicio, plano.EmUso,
            plano.Autor ?? string.Empty, plano.SomenteLeitura, treinos, semana);
    }

    // ---- Semana planejada (PBI-35) ----

    public Task<List<DiaPlanejado>> ObterSemanaAsync(Guid planoId, CancellationToken ct) =>
        _db.PlanoDiasSemana
            .Where(d => d.PlanoId == planoId
                && _db.Treinos.Any(t => t.Id == d.TreinoId && t.Ativo))
            .OrderBy(d => d.DiaSemana)
            .Select(d => new DiaPlanejado(d.DiaSemana, d.TreinoId))
            .ToListAsync(ct);

    public async Task<HashSet<Guid>> ObterIdsFichasAtivasAsync(Guid planoId, CancellationToken ct) =>
        (await _db.Treinos
            .Where(t => t.PlanoId == planoId && t.Ativo)
            .Select(t => t.Id)
            .ToListAsync(ct))
        .ToHashSet();

    public async Task SubstituirSemanaAsync(
        Guid planoId, IReadOnlyList<DiaPlanejado> dias, CancellationToken ct)
    {
        // Diferença em vez de "apaga tudo e insere": remover e reinserir a mesma
        // PK (plano, dia) no mesmo SaveChanges conflita no rastreamento do EF.
        var atuais = await _db.PlanoDiasSemana
            .Where(d => d.PlanoId == planoId)
            .ToListAsync(ct);
        var novos = dias.ToDictionary(d => d.DiaSemana, d => d.TreinoId);

        foreach (var atual in atuais)
        {
            if (novos.TryGetValue(atual.DiaSemana, out var treinoId))
            {
                atual.TreinoId = treinoId; // mesmo dia: só troca a ficha
                novos.Remove(atual.DiaSemana);
            }
            else
            {
                _db.PlanoDiasSemana.Remove(atual); // dia saiu da semana
            }
        }

        foreach (var (dia, treinoId) in novos)
        {
            _db.PlanoDiasSemana.Add(new PlanoDiaSemana
            {
                PlanoId = planoId,
                DiaSemana = dia,
                TreinoId = treinoId,
            });
        }
    }

    public async Task RemoverFichaDaSemanaAsync(Guid treinoId, CancellationToken ct)
    {
        var dias = await _db.PlanoDiasSemana
            .Where(d => d.TreinoId == treinoId)
            .ToListAsync(ct);
        _db.PlanoDiasSemana.RemoveRange(dias);
    }

    public Task<PlanoTreino?> ObterPlanoAsync(Guid planoId, CancellationToken ct) =>
        _db.PlanosTreino.FirstOrDefaultAsync(p => p.Id == planoId, ct);

    public async Task DefinirEmUsoAsync(Guid atletaId, Guid planoId, CancellationToken ct)
    {
        await using var tx = await _db.Database.BeginTransactionAsync(ct);

        // Zera o em uso atual do atleta e liga o escolhido, na mesma transação:
        // nunca há instante com zero nem com dois em uso. O índice único parcial
        // (atleta_id) WHERE em_uso é respeitado porque o commit é atômico.
        await _db.PlanosTreino
            .Where(p => p.AtletaId == atletaId && p.EmUso && p.Id != planoId)
            .ExecuteUpdateAsync(s => s.SetProperty(p => p.EmUso, false), ct);

        await _db.PlanosTreino
            .Where(p => p.Id == planoId)
            .ExecuteUpdateAsync(s => s.SetProperty(p => p.EmUso, true), ct);

        await tx.CommitAsync(ct);
    }

    public async Task<Guid> DuplicarPlanoAsync(Guid planoId, string novoNome, CancellationToken ct)
    {
        var original = await _db.PlanosTreino
            .FirstOrDefaultAsync(p => p.Id == planoId, ct)
            ?? throw new InvalidOperationException("Plano não encontrado para duplicar.");

        // Fichas ativas + exercícios + etapas + marcadores (o grafo prescrito;
        // sessões ficam de fora de propósito — a cópia nasce sem histórico).
        var fichas = await _db.Treinos
            .Where(t => t.PlanoId == planoId && t.Ativo)
            .OrderBy(t => t.Ordem)
            .ToListAsync(ct);
        var fichaIds = fichas.Select(f => f.Id).ToList();

        var exercicios = await _db.TreinoExercicios
            .Where(te => fichaIds.Contains(te.TreinoId))
            .ToListAsync(ct);
        var exIds = exercicios.Select(e => e.Id).ToList();

        var etapas = await _db.EtapasPrescritas
            .Where(e => exIds.Contains(e.TreinoExercicioId))
            .ToListAsync(ct);
        var marcadores = await _db.RodadaMarcadores
            .Where(m => exIds.Contains(m.TreinoExercicioId))
            .ToListAsync(ct);
        var semana = await _db.PlanoDiasSemana
            .Where(d => d.PlanoId == planoId)
            .ToListAsync(ct);
        var blocos = await _db.BlocosExercicio
            .Where(b => fichaIds.Contains(b.TreinoId))
            .ToListAsync(ct);

        // Bloco original → bloco copiado (PBI-101): mesmos membros, ordem e descanso.
        var blocoCopiado = new Dictionary<Guid, Guid>();
        foreach (var b in blocos)
        {
            blocoCopiado[b.Id] = Guid.NewGuid();
        }

        // Ficha original → ficha copiada, para levar a semana junto (PBI-35).
        var fichaCopiada = new Dictionary<Guid, Guid>();

        var copia = new PlanoTreino
        {
            Id = Guid.NewGuid(),
            AutorId = original.AtletaId, // cópia é sempre de autoria do atleta
            AtletaId = original.AtletaId,
            Nome = novoNome,
            Inicio = DateOnly.FromDateTime(DateTime.UtcNow),
            Ativo = true,
            EmUso = false, // nasce fora de uso
        };
        _db.PlanosTreino.Add(copia);

        foreach (var ficha in fichas)
        {
            var novaFicha = new Treino
            {
                Id = Guid.NewGuid(),
                PlanoId = copia.Id,
                Nome = ficha.Nome,
                Descricao = ficha.Descricao,
                Ordem = ficha.Ordem,
                Ativo = true,
            };
            _db.Treinos.Add(novaFicha);
            fichaCopiada[ficha.Id] = novaFicha.Id;

            foreach (var b in blocos.Where(x => x.TreinoId == ficha.Id))
            {
                _db.BlocosExercicio.Add(new BlocoExercicio
                {
                    Id = blocoCopiado[b.Id],
                    TreinoId = novaFicha.Id,
                    DescansoSeg = b.DescansoSeg,
                });
            }

            foreach (var te in exercicios.Where(e => e.TreinoId == ficha.Id))
            {
                var novoTe = new TreinoExercicio
                {
                    Id = Guid.NewGuid(),
                    TreinoId = novaFicha.Id,
                    ExercicioId = te.ExercicioId,
                    Ordem = te.Ordem,
                    Rodadas = te.Rodadas,
                    DescansoAlvoSeg = te.DescansoAlvoSeg,
                    Observacao = te.Observacao,
                    BlocoId = te.BlocoId is { } blocoId ? blocoCopiado[blocoId] : null,
                };
                _db.TreinoExercicios.Add(novoTe);

                foreach (var etapa in etapas.Where(e => e.TreinoExercicioId == te.Id))
                {
                    _db.EtapasPrescritas.Add(new EtapaPrescrita
                    {
                        Id = Guid.NewGuid(),
                        TreinoExercicioId = novoTe.Id,
                        Ordem = etapa.Ordem,
                        Tipo = etapa.Tipo,
                        IntensidadeMetricaId = etapa.IntensidadeMetricaId,
                        IntensidadeAlvo = etapa.IntensidadeAlvo,
                        VolumeMetricaId = etapa.VolumeMetricaId,
                        VolumeAlvo = etapa.VolumeAlvo,
                        VolumeAlvoMax = etapa.VolumeAlvoMax,
                    });
                }

                foreach (var m in marcadores.Where(x => x.TreinoExercicioId == te.Id))
                {
                    _db.RodadaMarcadores.Add(new RodadaMarcador
                    {
                        TreinoExercicioId = novoTe.Id,
                        Rodada = m.Rodada,
                        Marcador = m.Marcador,
                    });
                }
            }
        }

        // A semana vai junto, apontando para as fichas copiadas. Dia de ficha
        // arquivada (que não foi copiada) fica de fora.
        foreach (var dia in semana)
        {
            if (fichaCopiada.TryGetValue(dia.TreinoId, out var novaFichaId))
            {
                _db.PlanoDiasSemana.Add(new PlanoDiaSemana
                {
                    PlanoId = copia.Id,
                    DiaSemana = dia.DiaSemana,
                    TreinoId = novaFichaId,
                });
            }
        }

        await _db.SaveChangesAsync(ct);
        return copia.Id;
    }

    public async Task ExcluirPlanoAsync(Guid planoId, CancellationToken ct)
    {
        await using var tx = await _db.Database.BeginTransactionAsync(ct);

        var plano = await _db.PlanosTreino.FirstOrDefaultAsync(p => p.Id == planoId, ct);
        if (plano is null)
        {
            await tx.CommitAsync(ct);
            return;
        }

        // Alguma ficha do plano já foi usada numa sessão? (sessao.treino_id é
        // Restrict: nesse caso não dá para apagar, só arquivar.)
        var temSessoes = await _db.Sessoes.AnyAsync(
            s => _db.Treinos.Any(t => t.Id == s.TreinoId && t.PlanoId == planoId), ct);

        var eraEmUso = plano.EmUso;

        if (temSessoes)
        {
            // Esconde: histórico e gráficos continuam. Sai de uso.
            plano.Ativo = false;
            plano.EmUso = false;
            await _db.SaveChangesAsync(ct);
        }
        else
        {
            // Sem sessões: apaga de verdade (treino → treino_exercicio → etapa →
            // marcador caem por cascade sob o plano).
            _db.PlanosTreino.Remove(plano);
            await _db.SaveChangesAsync(ct);
        }

        // Se o excluído estava em uso, o uso passa para o plano do atleta com a
        // sessão mais recente; sem outro plano, fica sem plano em uso.
        if (eraEmUso)
        {
            var candidato = await _db.PlanosTreino
                .Where(p => p.AtletaId == plano.AtletaId && p.Ativo && p.Id != planoId)
                .Select(p => new
                {
                    p.Id,
                    UltimaSessao = _db.Sessoes
                        .Where(s => _db.Treinos.Any(t => t.Id == s.TreinoId && t.PlanoId == p.Id))
                        .Max(s => (DateOnly?)s.Data),
                })
                // Com sessão mais recente primeiro; empate/sem sessão vai por fim.
                .OrderByDescending(x => x.UltimaSessao.HasValue)
                .ThenByDescending(x => x.UltimaSessao)
                .FirstOrDefaultAsync(ct);

            if (candidato is not null)
            {
                await _db.PlanosTreino
                    .Where(p => p.Id == candidato.Id)
                    .ExecuteUpdateAsync(s => s.SetProperty(p => p.EmUso, true), ct);
            }
        }

        await tx.CommitAsync(ct);
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

    public Task<bool> ExercicioJaNaFichaAsync(Guid treinoId, Guid exercicioId, CancellationToken ct) =>
        _db.TreinoExercicios.AnyAsync(
            te => te.TreinoId == treinoId && te.ExercicioId == exercicioId, ct);

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

    public Task<List<BlocoExercicio>> ObterBlocosDaFichaAsync(Guid treinoId, CancellationToken ct) =>
        _db.BlocosExercicio
            .Where(b => b.TreinoId == treinoId)
            .ToListAsync(ct);

    public void AdicionarBloco(BlocoExercicio bloco) => _db.BlocosExercicio.Add(bloco);

    public void RemoverBloco(BlocoExercicio bloco) => _db.BlocosExercicio.Remove(bloco);

    public void AdicionarEtapa(EtapaPrescrita etapa) => _db.EtapasPrescritas.Add(etapa);

    public void RemoverEtapa(EtapaPrescrita etapa) => _db.EtapasPrescritas.Remove(etapa);

    public void AdicionarMarcador(RodadaMarcador marcador) => _db.RodadaMarcadores.Add(marcador);

    public void RemoverMarcador(RodadaMarcador marcador) => _db.RodadaMarcadores.Remove(marcador);

    public Task SalvarAsync(CancellationToken ct) => _db.SaveChangesAsync(ct);
}
