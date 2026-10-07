using DiarioTreino.Application.Identidade;

namespace DiarioTreino.Api.Autenticacao;

/// <summary>
/// Resolve (e provisiona no primeiro acesso) o perfil do usuário logado a
/// partir dos claims do token. Reutilizado pelos endpoints protegidos.
/// </summary>
public static class PerfilAtual
{
    public static async Task<PerfilUsuario?> ResolverAsync(
        HttpContext http,
        ServicoPerfil servico,
        CancellationToken ct)
    {
        var identidade = IdentidadeClaims.Extrair(http.User);
        if (identidade is null)
        {
            return null;
        }
        return await servico.ObterOuProvisionarAsync(identidade, ct);
    }
}
