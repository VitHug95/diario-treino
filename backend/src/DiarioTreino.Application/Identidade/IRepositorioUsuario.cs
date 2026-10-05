using DiarioTreino.Domain.Identidade;

namespace DiarioTreino.Application.Identidade;

/// <summary>Acesso de persistência ao agregado de usuário.</summary>
public interface IRepositorioUsuario
{
    /// <summary>Busca o usuário pelo <c>firebase_uid</c>, com os papéis carregados.</summary>
    public Task<Usuario?> ObterPorFirebaseUidAsync(string firebaseUid, CancellationToken ct);

    public void Adicionar(Usuario usuario);

    public Task SalvarAsync(CancellationToken ct);
}
