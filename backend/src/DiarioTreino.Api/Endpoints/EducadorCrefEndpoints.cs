using DiarioTreino.Api.Autenticacao;
using DiarioTreino.Application.Comum;
using DiarioTreino.Application.Educador;
using DiarioTreino.Application.Identidade;
using FluentValidation;

namespace DiarioTreino.Api.Endpoints;

/// <summary>
/// Habilitação do educador pelo CREF (PBI-106), só do próprio usuário. O CPF
/// chega no corpo do <c>POST</c> (nunca na URL), não é logado (o log de
/// requisições não lê corpo) e não volta em nenhuma resposta ou erro.
/// </summary>
public static class EducadorCrefEndpoints
{
    public static IEndpointRouteBuilder MapEducadorCrefEndpoints(this IEndpointRouteBuilder app)
    {
        var grupo = app.MapGroup("/api/v1/me/educador/cref")
            .RequireAuthorization()
            .WithTags("Educador");

        grupo.MapGet("", async (
            HttpContext http,
            ServicoPerfil perfilServico,
            ServicoCref servico,
            CancellationToken ct) =>
        {
            var perfil = await PerfilAtual.ResolverAsync(http, perfilServico, ct);
            if (perfil is null) return TokenInvalido();

            return Results.Ok(await servico.ObterAsync(perfil.Id, ct));
        })
        .WithName("SituacaoCrefEducador")
        .WithSummary("Se a verificação do CREF é exigida e o registro do usuário, se houver");

        grupo.MapPost("/verificar", async (
            VerificarCrefRequest request,
            HttpContext http,
            ServicoPerfil perfilServico,
            ServicoCref servico,
            IValidator<VerificarCrefRequest> validator,
            CancellationToken ct) =>
        {
            var validacao = await validator.ValidateAsync(request, ct);
            if (!validacao.IsValid) return Results.ValidationProblem(validacao.ToDictionary());

            var perfil = await PerfilAtual.ResolverAsync(http, perfilServico, ct);
            if (perfil is null) return TokenInvalido();

            try
            {
                return Results.Ok(await servico.VerificarAsync(
                    perfil.Id, request.Uf!, request.Numero!, request.Cpf!, ct));
            }
            catch (ConflitoException ex)
            {
                return Results.Problem(title: ex.Message, statusCode: StatusCodes.Status409Conflict);
            }
        })
        .WithName("VerificarCrefEducador")
        .WithSummary("Consulta o CREF por CPF e habilita o modo educador se o registro estiver ativo");

        return app;
    }

    private static IResult TokenInvalido() => Results.Problem(
        title: "Token sem identificador de usuário",
        statusCode: StatusCodes.Status401Unauthorized);
}
