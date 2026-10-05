using DiarioTreino.Application.Identidade;
using DiarioTreino.Domain.Identidade;
using Microsoft.EntityFrameworkCore;

namespace DiarioTreino.Infrastructure.Persistencia;

public sealed class RepositorioUsuario : IRepositorioUsuario
{
    private readonly DiarioTreinoDbContext _db;

    public RepositorioUsuario(DiarioTreinoDbContext db)
    {
        _db = db;
    }

    public Task<Usuario?> ObterPorFirebaseUidAsync(string firebaseUid, CancellationToken ct)
    {
        return _db.Usuarios
            .Include(u => u.Papeis)
            .FirstOrDefaultAsync(u => u.FirebaseUid == firebaseUid, ct);
    }

    public void Adicionar(Usuario usuario) => _db.Usuarios.Add(usuario);

    public Task SalvarAsync(CancellationToken ct) => _db.SaveChangesAsync(ct);
}
