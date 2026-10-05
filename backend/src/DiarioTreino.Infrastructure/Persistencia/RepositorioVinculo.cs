using DiarioTreino.Application.Acesso;
using DiarioTreino.Domain.Comum;
using Microsoft.EntityFrameworkCore;

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
}
