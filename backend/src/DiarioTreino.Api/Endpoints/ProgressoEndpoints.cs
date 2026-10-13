using DiarioTreino.Api.Autenticacao;
using DiarioTreino.Application.Identidade;
using DiarioTreino.Application.Progresso;

namespace DiarioTreino.Api.Endpoints;

/// <summary>
/// Evolução por exercício (PBI-20). O progresso é do atleta logado; o
/// <see cref="RecursoNaoEncontradoHandler"/> traduz exercício inexistente em
/// 404. Exige autenticação.
/// </summary>
public static class ProgressoEndpoints
{
    public static IEndpointRouteBuilder MapProgressoEndpoints(this IEndpointRouteBuilder app)
    {
        var grupo = app.MapGroup("/api/v1").RequireAuthorization();

        // Série de evolução de um exercício no período. de/ate opcionais.
        grupo.MapGet("/progresso/exercicios/{exercicioId:guid}", async (
            Guid exercicioId,
            DateOnly? de,
            DateOnly? ate,
            HttpContext http,
            ServicoPerfil perfilServico,
            ServicoProgresso progresso,
            CancellationToken ct) =>
        {
            var perfil = await PerfilAtual.ResolverAsync(http, perfilServico, ct);
            if (perfil is null) return TokenInvalido();

            var dados = await progresso.ObterProgressoAsync(perfil.Id, exercicioId, de, ate, ct);
            return Results.Ok(dados);
        })
        .WithName("ProgressoExercicio").WithTags("Progresso")
        .WithSummary("Evolução de um exercício no período");

        return app;
    }

    private static IResult TokenInvalido() => Results.Problem(
        title: "Token sem identificador de usuário",
        statusCode: StatusCodes.Status401Unauthorized);
}
