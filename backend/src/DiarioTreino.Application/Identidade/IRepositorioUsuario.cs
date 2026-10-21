using DiarioTreino.Domain.Identidade;

namespace DiarioTreino.Application.Identidade;

/// <summary>Acesso de persistência ao agregado de usuário.</summary>
public interface IRepositorioUsuario
{
    /// <summary>Busca o usuário pelo <c>firebase_uid</c>, com os papéis carregados.</summary>
    public Task<Usuario?> ObterPorFirebaseUidAsync(string firebaseUid, CancellationToken ct);

    public void Adicionar(Usuario usuario);

    public Task SalvarAsync(CancellationToken ct);

    /// <summary>
    /// Insere um usuário recém-provisionado tolerando corrida: no primeiro
    /// acesso o app pode disparar várias chamadas autenticadas em paralelo
    /// (ex.: planos e sessões no boot), e todas tentam provisionar o mesmo
    /// usuário. Retorna <c>false</c> quando a inserção colide no índice único
    /// (email/firebase_uid) — sinal de que outra chamada já provisionou — para
    /// o chamador re-buscar o usuário em vez de estourar 500.
    /// </summary>
    public Task<bool> TentarInserirUsuarioAsync(Usuario usuario, CancellationToken ct);

    /// <summary>
    /// Exclui a conta do usuário e todos os seus dados (sessões, planos/fichas,
    /// vínculos, exercícios próprios, papéis e o próprio usuário), numa única
    /// transação. Hard delete: exclusão de conta é o caso em que o atleta quer
    /// os dados removidos de fato (direito de exclusão/LGPD). A remoção no
    /// Firebase é feita pelo app (o back só valida token, não administra conta).
    /// </summary>
    public Task ExcluirContaAsync(Guid usuarioId, CancellationToken ct);
}
