using DiarioTreino.Api.Autenticacao;
using DiarioTreino.Application.Corpo;
using DiarioTreino.Application.Identidade;
using FluentValidation;

namespace DiarioTreino.Api.Endpoints;

/// <summary>
/// Dados corporais e TMB do próprio usuário (E12 / PBI-93), só o dono, sob
/// <c>/me</c>. Dado de saúde: nenhum valor vai para log nem para mensagem de erro.
/// O <c>GET /me</c> não muda: estes dados têm rota própria.
/// </summary>
public static class PerfilCorporalEndpoints
{
    public static IEndpointRouteBuilder MapPerfilCorporalEndpoints(this IEndpointRouteBuilder app)
    {
        var grupo = app.MapGroup("/api/v1/me/perfil-corporal").RequireAuthorization().WithTags("Perfil corporal");

        grupo.MapGet("", async (
            HttpContext http,
            ServicoPerfil perfilServico,
            ServicoPerfilCorporal servico,
            CancellationToken ct) =>
        {
            var perfil = await PerfilAtual.ResolverAsync(http, perfilServico, ct);
            if (perfil is null) return TokenInvalido();

            return Results.Ok(await servico.ObterAsync(perfil.Id, ct));
        })
        .WithName("PerfilCorporal")
        .WithSummary("Sexo, nascimento, altura, peso mais recente e a TMB calculada");

        grupo.MapPut("", async (
            SalvarPerfilCorporalRequest request,
            HttpContext http,
            ServicoPerfil perfilServico,
            ServicoPerfilCorporal servico,
            IValidator<SalvarPerfilCorporalRequest> validator,
            CancellationToken ct) =>
        {
            var validacao = await validator.ValidateAsync(request, ct);
            if (!validacao.IsValid) return Results.ValidationProblem(validacao.ToDictionary());

            var perfil = await PerfilAtual.ResolverAsync(http, perfilServico, ct);
            if (perfil is null) return TokenInvalido();

            try
            {
                return Results.Ok(await servico.SalvarAsync(perfil.Id, request, ct));
            }
            catch (ArgumentException ex)
            {
                return Results.Problem(title: ex.Message, statusCode: StatusCodes.Status400BadRequest);
            }
        })
        .WithName("SalvarPerfilCorporal")
        .WithSummary("Grava sexo, nascimento e altura (nulo limpa); com pesoKg, grava o peso do dia");

        grupo.MapDelete("", async (
            HttpContext http,
            ServicoPerfil perfilServico,
            ServicoPerfilCorporal servico,
            CancellationToken ct) =>
        {
            var perfil = await PerfilAtual.ResolverAsync(http, perfilServico, ct);
            if (perfil is null) return TokenInvalido();

            await servico.LimparAsync(perfil.Id, ct);
            return Results.NoContent();
        })
        .WithName("LimparPerfilCorporal")
        .WithSummary("Limpa sexo, nascimento e altura (o histórico de peso fica)");

        return app;
    }

    private static IResult TokenInvalido() =>
        Results.Problem(
            title: "Token sem identificador de usuário",
            statusCode: StatusCodes.Status401Unauthorized);
}
