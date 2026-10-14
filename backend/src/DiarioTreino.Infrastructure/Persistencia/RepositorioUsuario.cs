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
