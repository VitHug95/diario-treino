namespace DiarioTreino.Application.Identidade;

/// <summary>Perfil e papéis do usuário logado, devolvido por <c>GET /me</c>.</summary>
public sealed record PerfilUsuario(
    Guid Id,
    string Nome,
    string Email,
    IReadOnlyList<string> Papeis);
