using DiarioTreino.Application.Identidade;
using DiarioTreino.Domain.Identidade;
using Microsoft.EntityFrameworkCore;

namespace DiarioTreino.Infrastructure.Persistencia;

public sealed class RepositorioConsentimento : IRepositorioConsentimento
{
    private readonly DiarioTreinoDbContext _db;

    public RepositorioConsentimento(DiarioTreinoDbContext db)
    {
        _db = db;
    }

    public Task<bool> ExisteAsync(Guid usuarioId, string versaoTermo, CancellationToken ct) =>
        _db.Consentimentos.AnyAsync(
            c => c.UsuarioId == usuarioId && c.VersaoTermo == versaoTermo, ct);

    public async Task RegistrarSeAusenteAsync(Guid usuarioId, string versaoTermo, CancellationToken ct)
    {
        if (await ExisteAsync(usuarioId, versaoTermo, ct))
        {
            return;
        }

        _db.Consentimentos.Add(new Consentimento
        {
            Id = Guid.NewGuid(),
            UsuarioId = usuarioId,
            VersaoTermo = versaoTermo,
            AceitoEm = DateTimeOffset.UtcNow,
        });
        // Não salva aqui: o chamador (aceite do vínculo) persiste tudo junto.
    }
}
