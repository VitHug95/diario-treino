using System.Security.Claims;
using DiarioTreino.Application.Identidade;

namespace DiarioTreino.Api.Autenticacao;

/// <summary>Extrai a identidade do chamador dos claims do token Firebase.</summary>
public static class IdentidadeClaims
{
    public static IdentidadeDoChamador? Extrair(ClaimsPrincipal principal)
    {
        // O Firebase coloca o uid em "user_id"; o handler JWT costuma mapear o
        // "sub" para ClaimTypes.NameIdentifier. Tentamos ambos.
        var uid = principal.FindFirstValue("user_id")
            ?? principal.FindFirstValue(ClaimTypes.NameIdentifier)
            ?? principal.FindFirstValue("sub");

        if (string.IsNullOrWhiteSpace(uid))
        {
            return null;
        }

        var email = principal.FindFirstValue("email")
            ?? principal.FindFirstValue(ClaimTypes.Email);
        var nome = principal.FindFirstValue("name")
            ?? principal.FindFirstValue(ClaimTypes.Name);

        return new IdentidadeDoChamador(uid, email, nome);
    }
}
