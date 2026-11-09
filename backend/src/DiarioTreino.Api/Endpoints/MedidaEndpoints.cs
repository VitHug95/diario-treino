using DiarioTreino.Api.Autenticacao;
using DiarioTreino.Application.Corpo;
using DiarioTreino.Application.Identidade;
using FluentValidation;

namespace DiarioTreino.Api.Endpoints;

/// <summary>
/// Medidas corporais do próprio usuário (E12 / PBI-91). Tudo sob <c>/me</c>, só o
/// dono. Dado de saúde: nenhum valor vai para log nem para mensagem de erro.
/// Sem token, o pipeline responde 401; dia inexistente responde 404.
/// </summary>
public static class MedidaEndpoints
{
    public static IEndpointRouteBuilder MapMedidaEndpoints(this IEndpointRouteBuilder app)
    {
        var grupo = app.MapGroup("/api/v1/me/medidas").RequireAuthorization().WithTags("Medidas");

        grupo.MapGet("", async (
            HttpContext http,
            ServicoPerfil perfilServico,
            ServicoMedidas medidas,
            CancellationToken ct) =>
        {
            var perfil = await PerfilAtual.ResolverAsync(http, perfilServico, ct);
            if (perfil is null) return TokenInvalido();

            return Results.Ok(await medidas.ObterResumoAsync(perfil.Id, ct));
        })
        .WithName("ResumoMedidas")
        .WithSummary("Últimas medidas (com variação) e histórico por dia");

        grupo.MapGet("/{data}", async (
            DateOnly data,
            HttpContext http,
            ServicoPerfil perfilServico,
            ServicoMedidas medidas,
            CancellationToken ct) =>
        {
            var perfil = await PerfilAtual.ResolverAsync(http, perfilServico, ct);
            if (perfil is null) return TokenInvalido();

            return Results.Ok(await medidas.ObterDiaAsync(perfil.Id, data, ct));
        })
        .WithName("MedidasDoDia")
        .WithSummary("Valores medidos num dia (404 se não houver)");

        grupo.MapPut("/{data}", async (
            DateOnly data,
            SalvarMedidasRequest request,
            HttpContext http,
            ServicoPerfil perfilServico,
            ServicoMedidas medidas,
            IValidator<SalvarMedidasEntrada> validator,
            CancellationToken ct) =>
        {
            var entrada = new SalvarMedidasEntrada(data, request.Valores);
            var validacao = await validator.ValidateAsync(entrada, ct);
            if (!validacao.IsValid) return Results.ValidationProblem(validacao.ToDictionary());

            var perfil = await PerfilAtual.ResolverAsync(http, perfilServico, ct);
            if (perfil is null) return TokenInvalido();

            try
            {
                var dia = await medidas.SalvarDiaAsync(perfil.Id, data, request.Valores!, ct);
                return Results.Ok(dia);
            }
            catch (ArgumentException ex)
            {
                return Results.Problem(title: ex.Message, statusCode: StatusCodes.Status400BadRequest);
            }
        })
        .WithName("SalvarMedidasDoDia")
        .WithSummary("Grava as medidas do dia (upsert por tipo; valor nulo remove o tipo)");

        grupo.MapDelete("/{data}", async (
            DateOnly data,
            HttpContext http,
            ServicoPerfil perfilServico,
            ServicoMedidas medidas,
            CancellationToken ct) =>
        {
            var perfil = await PerfilAtual.ResolverAsync(http, perfilServico, ct);
            if (perfil is null) return TokenInvalido();

            await medidas.ExcluirDiaAsync(perfil.Id, data, ct);
            return Results.NoContent();
        })
        .WithName("ExcluirMedidasDoDia")
        .WithSummary("Apaga todas as medidas do dia (404 se não houver)");

        return app;
    }

    private static IResult TokenInvalido() =>
        Results.Problem(
            title: "Token sem identificador de usuário",
            statusCode: StatusCodes.Status401Unauthorized);
}
