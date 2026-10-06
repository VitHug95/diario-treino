using DiarioTreino.Api.Autenticacao;
using DiarioTreino.Application.Catalogo;
using DiarioTreino.Application.Identidade;

namespace DiarioTreino.Api.Endpoints;

/// <summary>
/// <c>GET /api/v1/exercicios</c> (PBI-10): catálogo global + exercícios do
/// usuário, com busca por nome (sem diferenciar maiúsculas/acentos) e filtro de
/// modalidade. Exige autenticação.
/// </summary>
public static class ExercicioEndpoints
{
    public static IEndpointRouteBuilder MapExercicioEndpoints(this IEndpointRouteBuilder app)
    {
        var grupo = app.MapGroup("/api/v1").RequireAuthorization();

        grupo.MapGet("/exercicios", async (
            HttpContext http,
            ServicoPerfil perfilServico,
            ServicoCatalogo catalogo,
            string? busca,
            string? modalidade,
            CancellationToken ct) =>
        {
            var identidade = IdentidadeClaims.Extrair(http.User);
            if (identidade is null)
            {
                return Results.Problem(
                    title: "Token sem identificador de usuário",
                    statusCode: StatusCodes.Status401Unauthorized);
            }

            // Resolve (e provisiona, se for o primeiro acesso) o usuário logado.
            var perfil = await perfilServico.ObterOuProvisionarAsync(identidade, ct);

            try
            {
                var itens = await catalogo.ListarAsync(perfil.Id, busca, modalidade, ct);
                return Results.Ok(itens);
            }
            catch (ArgumentException ex)
            {
                return Results.Problem(
                    title: ex.Message,
                    statusCode: StatusCodes.Status400BadRequest);
            }
        })
        .WithName("ListarExercicios")
        .WithTags("Catálogo")
        .WithSummary("Catálogo global + exercícios do usuário");

        return app;
    }
}
