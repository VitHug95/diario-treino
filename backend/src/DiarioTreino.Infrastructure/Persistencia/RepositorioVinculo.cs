using DiarioTreino.Application.Acesso;
using DiarioTreino.Domain.Comum;
using DiarioTreino.Domain.Vinculos;
using Microsoft.EntityFrameworkCore;
using Npgsql;

namespace DiarioTreino.Infrastructure.Persistencia;

public sealed class RepositorioVinculo : IRepositorioVinculo
{
    private readonly DiarioTreinoDbContext _db;

    public RepositorioVinculo(DiarioTreinoDbContext db)
    {
        _db = db;
    }

    public Task<bool> ExisteVinculoAtivoAsync(
        Guid educadorId,
        Guid alunoId,
        CancellationToken ct)
    {
        return _db.Vinculos.AnyAsync(
            v => v.EducadorId == educadorId
                && v.AlunoId == alunoId
                && v.Status == StatusVinculo.Ativo,
            ct);
    }

    public Task<bool> ExisteVinculoAbertoAsync(
        Guid educadorId,
        Guid alunoId,
        CancellationToken ct)
    {
        return _db.Vinculos.AnyAsync(
            v => v.EducadorId == educadorId
                && v.AlunoId == alunoId
                && (v.Status == StatusVinculo.Pendente || v.Status == StatusVinculo.Ativo),
            ct);
    }

    public Task<Vinculo?> ObterPorIdAsync(Guid id, CancellationToken ct) =>
        _db.Vinculos.FirstOrDefaultAsync(v => v.Id == id, ct);

    public Task<List<Vinculo>> ListarPendentesDoAlunoAsync(Guid alunoId, CancellationToken ct) =>
        _db.Vinculos
            .Where(v => v.AlunoId == alunoId && v.Status == StatusVinculo.Pendente)
            .ToListAsync(ct);

    public Task<List<Vinculo>> ListarAtivosDoEducadorAsync(Guid educadorId, CancellationToken ct) =>
        _db.Vinculos
            .Where(v => v.EducadorId == educadorId && v.Status == StatusVinculo.Ativo)
            .ToListAsync(ct);

    public Task SalvarAsync(CancellationToken ct) => _db.SaveChangesAsync(ct);

    public async Task<bool> TentarCriarAsync(Vinculo vinculo, CancellationToken ct)
    {
        _db.Vinculos.Add(vinculo);
        try
        {
            await _db.SaveChangesAsync(ct);
            return true;
        }
        catch (DbUpdateException e) when (e.InnerException is PostgresException
        {
            SqlState: PostgresErrorCodes.UniqueViolation
        })
        {
            // Dois convites simultâneos ao mesmo aluno colidem no índice único
            // parcial ux_vinculo_aberto: outra requisição já abriu o vínculo.
            // Desfaz o rastreamento do insert que falhou e sinaliza o conflito
            // (o serviço traduz em 409) em vez de deixar virar 500.
            _db.Entry(vinculo).State = EntityState.Detached;
            return false;
        }
    }
}
