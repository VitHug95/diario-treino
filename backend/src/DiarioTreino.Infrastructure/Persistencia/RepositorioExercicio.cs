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

        if (!string.IsNullOrWhiteSpace(busca))
        {
            // Busca sem diferenciar maiúsculas nem acentos (PBI-10).
            var alvo = busca.ToLower();
            query = query.Where(e =>
                EF.Functions.Like(
                    DiarioTreinoDbContext.Unaccent(e.Nome.ToLower()),
                    "%" + DiarioTreinoDbContext.Unaccent(alvo) + "%"));
        }

        // Junta às métricas padrão para trazer código e nome da forma de medir.
        var consulta =
            from e in query
            join mi in _db.Metricas on e.IntensidadeMetricaPadraoId equals mi.Id
            join mv in _db.Metricas on e.VolumeMetricaPadraoId equals mv.Id
            orderby e.Nome
            select new ExercicioResumo(
                e.Id,
                e.Nome,
                e.GrupoMuscular,
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
}
