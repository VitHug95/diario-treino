using DiarioTreino.Api.Autenticacao;
using DiarioTreino.Application.Catalogo;
using DiarioTreino.Application.Comum;
using DiarioTreino.Application.Identidade;
using FluentValidation;

namespace DiarioTreino.Api.Endpoints;

/// <summary>
/// Catálogo de exercícios e métricas (PBI-10 e PBI-11). Tudo exige autenticação.
/// <list type="bullet">
/// <item><c>GET /exercicios</c>: catálogo global + exercícios do usuário.</item>
/// <item><c>POST /exercicios</c>: cria um exercício próprio.</item>
/// <item><c>GET /metricas</c>: métricas disponíveis para medir.</item>
/// </list>
/// </summary>
public static class ExercicioEndpoints
{
    public static IEndpointRouteBuilder MapExercicioEndpoints(this IEndpointRouteBuilder app)
    {
        var grupo = app.MapGroup("/api/v1").RequireAuthorization();

        grupo.MapGet("/metricas", async (
            ServicoCatalogo catalogo,
            CancellationToken ct) =>
        {
            var metricas = await catalogo.ListarMetricasAsync(ct);
            return Results.Ok(metricas);
        })
        .WithName("ListarMetricas")
        .WithTags("Catálogo")
        .WithSummary("Métricas disponíveis");

        grupo.MapGet("/exercicios", async (
            HttpContext http,
            ServicoPerfil perfilServico,
            ServicoCatalogo catalogo,
            string? busca,
            string? modalidade,
            CancellationToken ct) =>
        {
            var perfil = await ResolverPerfilAsync(http, perfilServico, ct);
            if (perfil is null)
            {
                return TokenInvalido();
            }

            try
            {
                var itens = await catalogo.ListarAsync(perfil.Id, busca, modalidade, ct);
                return Results.Ok(itens);
            }
            catch (ArgumentException ex)
            {
                return Results.Problem(title: ex.Message, statusCode: StatusCodes.Status400BadRequest);
            }
        })
        .WithName("ListarExercicios")
        .WithTags("Catálogo")
        .WithSummary("Catálogo global + exercícios do usuário");

        grupo.MapPost("/exercicios", async (
            HttpContext http,
            ServicoPerfil perfilServico,
            ServicoCatalogo catalogo,
            IValidator<CriarExercicioRequest> validator,
            CriarExercicioRequest request,
            CancellationToken ct) =>
        {
            var validacao = await validator.ValidateAsync(request, ct);
            if (!validacao.IsValid)
            {
                return Results.ValidationProblem(validacao.ToDictionary());
            }

            var perfil = await ResolverPerfilAsync(http, perfilServico, ct);
            if (perfil is null)
            {
                return TokenInvalido();
            }

            try
            {
                var id = await catalogo.CriarAsync(perfil.Id, request, ct);
                return Results.Created($"/api/v1/exercicios/{id}", new { id });
            }
            catch (ConflitoException ex)
            {
                return Results.Problem(title: ex.Message, statusCode: StatusCodes.Status409Conflict);
            }
            catch (ArgumentException ex)
            {
                return Results.Problem(title: ex.Message, statusCode: StatusCodes.Status400BadRequest);
            }
        })
        .WithName("CriarExercicio")
        .WithTags("Catálogo")
        .WithSummary("Cria um exercício próprio");

        return app;
    }

    private static async Task<PerfilUsuario?> ResolverPerfilAsync(
        HttpContext http,
        ServicoPerfil perfilServico,
        CancellationToken ct)
    {
        var identidade = IdentidadeClaims.Extrair(http.User);
        if (identidade is null)
        {
            return null;
        }
        return await perfilServico.ObterOuProvisionarAsync(identidade, ct);
    }

    private static IResult TokenInvalido() => Results.Problem(
        title: "Token sem identificador de usuário",
        statusCode: StatusCodes.Status401Unauthorized);
}
