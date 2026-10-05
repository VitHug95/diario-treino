using DiarioTreino.Api.Autenticacao;
using DiarioTreino.Application.Identidade;

namespace DiarioTreino.Api.Endpoints;

/// <summary>
/// <c>GET /api/v1/me</c>: perfil e papéis do usuário logado. No primeiro acesso
/// provisiona o usuário com o papel ATLETA (MAS 11.1 / PBI-06). Exige token
/// válido; sem token ou token inválido, o pipeline responde 401.
/// </summary>
public static class MeEndpoints
{
    public static IEndpointRouteBuilder MapMeEndpoints(this IEndpointRouteBuilder app)
    {
        var grupo = app.MapGroup("/api/v1").RequireAuthorization();

        grupo.MapGet("/me", async (
            HttpContext http,
            ServicoPerfil servico,
            CancellationToken ct) =>
        {
            var identidade = IdentidadeClaims.Extrair(http.User);
            if (identidade is null)
            {
                return Results.Problem(
                    title: "Token sem identificador de usuário",
                    statusCode: StatusCodes.Status401Unauthorized);
            }

            var perfil = await servico.ObterOuProvisionarAsync(identidade, ct);
            return Results.Ok(perfil);
        })
        .WithName("Me")
        .WithTags("Identidade")
        .WithSummary("Perfil e papéis do usuário logado");

        return app;
    }
}
