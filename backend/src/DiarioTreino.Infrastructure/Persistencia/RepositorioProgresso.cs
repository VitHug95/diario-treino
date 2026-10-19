using DiarioTreino.Application.Progresso;
using DiarioTreino.Domain.Comum;
using Microsoft.EntityFrameworkCore;

namespace DiarioTreino.Infrastructure.Persistencia;

public sealed class RepositorioProgresso : IRepositorioProgresso
{
    private readonly DiarioTreinoDbContext _db;

    public RepositorioProgresso(DiarioTreinoDbContext db)
    {
        _db = db;
    }

    public async Task<bool> ExercicioTemCargaAsync(
        Guid atletaId,
        Guid exercicioId,
        DateOnly? de,
        DateOnly? ate,
        CancellationToken ct)
    {
        var series = _db.SeriesExecutadas.Where(se =>
            se.ExercicioId == exercicioId
            && se.Tipo == TipoEtapa.Esforco
            && se.Intensidade != null
            && se.Sessao!.AtletaId == atletaId);
        if (de is { } d) series = series.Where(se => se.Sessao!.Data >= d);
        if (ate is { } a) series = series.Where(se => se.Sessao!.Data <= a);
        return await series.AnyAsync(ct);
    }

    public async Task<IReadOnlyList<PontoBruto>> ObterPontosAsync(
        Guid atletaId,
        Guid exercicioId,
        MetricaProgresso metrica,
        DateOnly? de,
        DateOnly? ate,
        CancellationToken ct)
    {
        // Sessões do atleta que têm séries de ESFORÇO do exercício, no período.
        var sessoes = _db.Sessoes.Where(s =>
            s.AtletaId == atletaId
            && s.Series.Any(se =>
                se.ExercicioId == exercicioId && se.Tipo == TipoEtapa.Esforco));
        if (de is { } d) sessoes = sessoes.Where(s => s.Data >= d);
        if (ate is { } a) sessoes = sessoes.Where(s => s.Data <= a);

        if (metrica == MetricaProgresso.Carga)
        {
            // Por sessão: a série de esforço de MAIOR carga (intensidade) e as
            // repetições (volume) DAQUELA série. Empate de carga: desempata pela
            // maior quantidade de repetições.
            var pontos = await sessoes
                .Select(s => new
                {
                    s.Id,
                    s.Data,
                    s.Observacao,
                    Maior = s.Series
                        .Where(se => se.ExercicioId == exercicioId
                            && se.Tipo == TipoEtapa.Esforco
                            && se.Intensidade != null)
                        .OrderByDescending(se => se.Intensidade)
                        .ThenByDescending(se => se.Volume)
                        .Select(se => new { se.Intensidade, se.Volume })
                        .FirstOrDefault(),
                })
                .Where(x => x.Maior != null)
                .OrderBy(x => x.Data)
                .ToListAsync(ct);

            return pontos
                .Select(x => new PontoBruto(
                    x.Data,
                    x.Maior!.Intensidade!.Value,
                    x.Maior.Volume,
                    x.Id,
                    x.Observacao))
                .ToList();
        }

        // Repetições (força sem carga) ou Tempo (isometria): por sessão, o MAIOR
        // volume (reps/tempo) entre as séries de esforço do exercício. Sem
        // segundo valor (Repeticoes = nulo), pois o próprio Valor é o volume.
        var pontosIso = await sessoes
            .Select(s => new
            {
                s.Id,
                s.Data,
                s.Observacao,
                MaiorTempo = s.Series
                    .Where(se => se.ExercicioId == exercicioId
                        && se.Tipo == TipoEtapa.Esforco)
                    .Max(se => (decimal?)se.Volume),
            })
            .Where(x => x.MaiorTempo != null)
            .OrderBy(x => x.Data)
            .ToListAsync(ct);

        return pontosIso
            .Select(x => new PontoBruto(x.Data, x.MaiorTempo!.Value, null, x.Id, x.Observacao))
            .ToList();
    }

    public async Task<IReadOnlyList<ExercicioComHistorico>> ListarExerciciosComHistoricoAsync(
        Guid atletaId, CancellationToken ct)
    {
        // Ids de exercício que aparecem em séries de esforço de sessões do
        // atleta (distintos).
        var ids = _db.SeriesExecutadas
            .Where(se => se.Tipo == TipoEtapa.Esforco
                && se.Sessao!.AtletaId == atletaId)
            .Select(se => se.ExercicioId)
            .Distinct();

        // Junta ao catálogo para nome/modalidade, em ordem alfabética.
        return await _db.Exercicios
            .Where(e => ids.Contains(e.Id))
            .OrderBy(e => e.Nome)
            .Select(e => new ExercicioComHistorico(e.Id, e.Nome, e.Modalidade))
            .ToListAsync(ct);
    }
}
