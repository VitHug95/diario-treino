using DiarioTreino.Application.Execucao;
using DiarioTreino.Domain.Execucao;
using Microsoft.EntityFrameworkCore;

namespace DiarioTreino.Infrastructure.Persistencia;

public sealed class RepositorioSessao : IRepositorioSessao
{
    private readonly DiarioTreinoDbContext _db;

    public RepositorioSessao(DiarioTreinoDbContext db)
    {
        _db = db;
    }

    public void AdicionarSessao(Sessao sessao) => _db.Sessoes.Add(sessao);

    public async Task<(DateOnly Data, IReadOnlyList<SerieExecutada> Series)?> ObterUltimaExecucaoAsync(
        Guid atletaId, Guid exercicioId, CancellationToken ct)
    {
        // Sessão mais recente do atleta que contém o exercício. Empata por data?
        // Desempata pela mais recém-criada (criado_em).
        var sessao = await _db.Sessoes
            .Where(s => s.AtletaId == atletaId
                && s.Series.Any(se => se.ExercicioId == exercicioId))
            .OrderByDescending(s => s.Data)
            .ThenByDescending(s => s.CriadoEm)
            .Select(s => new { s.Id, s.Data })
            .FirstOrDefaultAsync(ct);

        if (sessao is null)
        {
            return null;
        }

        var series = await _db.SeriesExecutadas
            .Where(se => se.SessaoId == sessao.Id && se.ExercicioId == exercicioId)
            .OrderBy(se => se.Rodada)
            .ThenBy(se => se.Ordem)
            .ToListAsync(ct);

        return (sessao.Data, series);
    }

    public Task SalvarAsync(CancellationToken ct) => _db.SaveChangesAsync(ct);
}
