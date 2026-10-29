using DiarioTreino.Application.Identidade;
using DiarioTreino.Domain.Identidade;
using Microsoft.EntityFrameworkCore;
using Npgsql;

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

    public Task<Usuario?> ObterPorIdAsync(Guid id, CancellationToken ct)
    {
        return _db.Usuarios
            .Include(u => u.Papeis)
            .FirstOrDefaultAsync(u => u.Id == id, ct);
    }

    public Task<Usuario?> ObterPorEmailAsync(string email, CancellationToken ct)
    {
        var normalizado = email.Trim().ToLowerInvariant();
        return _db.Usuarios
            .Include(u => u.Papeis)
            .FirstOrDefaultAsync(u => u.Email == normalizado, ct);
    }

    public void Adicionar(Usuario usuario) => _db.Usuarios.Add(usuario);

    public Task SalvarAsync(CancellationToken ct) => _db.SaveChangesAsync(ct);

    public async Task<bool> TentarInserirUsuarioAsync(Usuario usuario, CancellationToken ct)
    {
        _db.Usuarios.Add(usuario);
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
            // Outra requisição simultânea já provisionou este usuário. Desfaz o
            // rastreamento do insert que falhou para não poluir o ChangeTracker
            // e sinaliza o conflito ao chamador (que vai re-buscar).
            _db.Entry(usuario).State = EntityState.Detached;
            foreach (var papel in usuario.Papeis)
            {
                _db.Entry(papel).State = EntityState.Detached;
            }
            return false;
        }
    }

    public async Task ExcluirContaAsync(Guid usuarioId, CancellationToken ct)
    {
        // As FKs de plano_treino / sessao / vinculo para usuario são Restrict,
        // então um DELETE direto no usuario falharia. Apaga os dependentes do
        // folha para a raiz, numa transação, para a conta sumir inteira ou nada.
        await using var tx = await _db.Database.BeginTransactionAsync(ct);

        // Sessões do atleta (serie_executada cai por cascade sob a sessão).
        await _db.Sessoes
            .Where(s => s.AtletaId == usuarioId || s.RegistradoPorId == usuarioId)
            .ExecuteDeleteAsync(ct);

        // Fichas/planos do atleta (treino → treino_exercicio → etapa_prescrita
        // caem por cascade sob o plano). Cobre autor e atleta.
        await _db.PlanosTreino
            .Where(p => p.AtletaId == usuarioId || p.AutorId == usuarioId)
            .ExecuteDeleteAsync(ct);

        // Vínculos de educador/aluno (estrutura futura, mas pode existir).
        await _db.Vinculos
            .Where(v => v.EducadorId == usuarioId || v.AlunoId == usuarioId)
            .ExecuteDeleteAsync(ct);

        // Exercícios próprios do catálogo (os globais têm criado_por_id nulo).
        await _db.Exercicios
            .Where(e => e.CriadoPorId == usuarioId)
            .ExecuteDeleteAsync(ct);

        // Papéis (também cairiam por cascade, mas explícito antes do usuário).
        await _db.UsuarioPapeis
            .Where(up => up.UsuarioId == usuarioId)
            .ExecuteDeleteAsync(ct);

        await _db.Usuarios
            .Where(u => u.Id == usuarioId)
            .ExecuteDeleteAsync(ct);

        await tx.CommitAsync(ct);
    }
}
