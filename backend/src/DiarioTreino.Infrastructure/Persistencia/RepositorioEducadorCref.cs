using DiarioTreino.Application.Educador;
using DiarioTreino.Domain.Educador;
using Microsoft.EntityFrameworkCore;
using Npgsql;

namespace DiarioTreino.Infrastructure.Persistencia;

public sealed class RepositorioEducadorCref : IRepositorioEducadorCref
{
    private readonly DiarioTreinoDbContext _db;

    public RepositorioEducadorCref(DiarioTreinoDbContext db)
    {
        _db = db;
    }

    public Task<EducadorCref?> ObterAsync(Guid usuarioId, CancellationToken ct) =>
        _db.EducadoresCref.AsNoTracking().FirstOrDefaultAsync(e => e.UsuarioId == usuarioId, ct);

    public Task<bool> HabilitadoAsync(Guid usuarioId, CancellationToken ct) =>
        _db.EducadoresCref.AnyAsync(e => e.UsuarioId == usuarioId, ct);

    public Task<bool> RegistroUsadoPorOutroAsync(string uf, string numero, Guid usuarioId, CancellationToken ct) =>
        _db.EducadoresCref.AnyAsync(e => e.Uf == uf && e.Numero == numero && e.UsuarioId != usuarioId, ct);

    public Task<int> ContarTentativasAsync(Guid usuarioId, DateTimeOffset desde, CancellationToken ct) =>
        _db.TentativasCref.CountAsync(
            t => t.UsuarioId == usuarioId && t.Em >= desde && t.Resultado != ResultadoCref.Indisponivel, ct);

    public void AdicionarTentativa(TentativaCref tentativa) => _db.TentativasCref.Add(tentativa);

    public void Adicionar(EducadorCref educador) => _db.EducadoresCref.Add(educador);

    public void AdicionarFoto(FotoCarteiraCref foto) => _db.FotosCarteiraCref.Add(foto);

    public async Task<bool> TentarSalvarAsync(CancellationToken ct)
    {
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
            // Outra conta se habilitou com o mesmo registro ao mesmo tempo. Desfaz
            // o que estava pendente (habilitação, papel e tentativa) para não
            // gravar nada pela metade.
            foreach (var entrada in _db.ChangeTracker.Entries()
                         .Where(x => x.State is EntityState.Added or EntityState.Modified).ToList())
            {
                entrada.State = EntityState.Detached;
            }
            return false;
        }
    }
}
