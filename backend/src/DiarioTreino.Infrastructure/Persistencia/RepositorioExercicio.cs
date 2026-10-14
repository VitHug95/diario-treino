using DiarioTreino.Application.Catalogo;
using Microsoft.EntityFrameworkCore;

namespace DiarioTreino.Infrastructure.Persistencia;

public sealed class RepositorioExercicio : IRepositorioExercicio
{
    private readonly DiarioTreinoDbContext _db;

    public RepositorioExercicio(DiarioTreinoDbContext db)
    {
        _db = db;
    }

    public async Task<IReadOnlyList<ExercicioResumo>> BuscarAsync(
        Guid usuarioId,
        string? busca,
        string? modalidade,
        short? membroId,
        CancellationToken ct)
    {
        // Catálogo global (sem dono) + exercícios do próprio usuário, só ativos.
        var query = _db.Exercicios
            .AsNoTracking()
            .Where(e => e.Ativo && (e.CriadoPorId == null || e.CriadoPorId == usuarioId));

        if (!string.IsNullOrWhiteSpace(modalidade))
        {
            query = query.Where(e => e.Modalidade == modalidade);
        }

        if (membroId is { } mId)
        {
            query = query.Where(e => e.MembroId == mId);
        }

        if (!string.IsNullOrWhiteSpace(busca))
        {
            // Busca sem diferenciar maiúsculas nem acentos (PBI-10).
            var alvo = busca.ToLower();
            query = query.Where(e =>
                EF.Functions.Like(
                    DiarioTreinoDbContext.Unaccent(e.Nome.ToLower()),
                    "%" + DiarioTreinoDbContext.Unaccent(alvo) + "%"));
        }

        // Junta às métricas padrão (forma de medir) e, por LEFT JOIN, ao membro
        // e músculo (podem ser nulos enquanto a etapa 1 convive com o legado).
        var consulta =
            from e in query
            join mi in _db.Metricas on e.IntensidadeMetricaPadraoId equals mi.Id
            join mv in _db.Metricas on e.VolumeMetricaPadraoId equals mv.Id
            join mbJoin in _db.Membros on e.MembroId equals mbJoin.Id into mbg
            from mb in mbg.DefaultIfEmpty()
            join muJoin in _db.Musculos on e.MusculoId equals muJoin.Id into mug
            from mu in mug.DefaultIfEmpty()
            orderby e.Nome
            select new ExercicioResumo(
                e.Id,
                e.Nome,
                e.MembroId,
                mb != null ? mb.Nome : null,
                e.MusculoId,
                mu != null ? mu.Nome : null,
                e.Modalidade,
                mi.Codigo,
                mi.Nome,
                mv.Codigo,
                mv.Nome,
                e.CriadoPorId != null);

        return await consulta.ToListAsync(ct);
    }

    public async Task<bool> ExisteNomeNoCatalogoAsync(
        Guid usuarioId,
        string nome,
        CancellationToken ct)
    {
        var alvo = nome.Trim().ToLower();
        return await _db.Exercicios
            .AnyAsync(e => e.CriadoPorId == usuarioId && e.Nome.ToLower() == alvo, ct);
    }

    public async Task AdicionarAsync(
        DiarioTreino.Domain.Catalogo.Exercicio exercicio,
        CancellationToken ct)
    {
        _db.Exercicios.Add(exercicio);
        await _db.SaveChangesAsync(ct);
    }

    public Task<bool> ExisteDisponivelAsync(Guid exercicioId, Guid usuarioId, CancellationToken ct) =>
        _db.Exercicios.AnyAsync(
            e => e.Id == exercicioId
                && e.Ativo
                && (e.CriadoPorId == null || e.CriadoPorId == usuarioId),
            ct);

    public async Task<IReadOnlyDictionary<Guid, ExercicioBasico>> ObterBasicosPorIdsAsync(
        IReadOnlyCollection<Guid> ids, CancellationToken ct)
    {
        if (ids.Count == 0)
        {
            return new Dictionary<Guid, ExercicioBasico>();
        }

        var itens = await _db.Exercicios
            .AsNoTracking()
            .Where(e => ids.Contains(e.Id))
            .Select(e => new ExercicioBasico(e.Id, e.Nome, e.Modalidade))
            .ToListAsync(ct);

        return itens.ToDictionary(e => e.Id);
    }
}
