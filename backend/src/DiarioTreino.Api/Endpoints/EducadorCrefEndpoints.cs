using DiarioTreino.Api.Autenticacao;
using DiarioTreino.Application.Comum;
using DiarioTreino.Application.Educador;
using DiarioTreino.Application.Identidade;
using DiarioTreino.Domain.Educador;
using FluentValidation;
using Microsoft.AspNetCore.Mvc;

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

        // Habilitação declarada (PBI-106, 27/11): UF, número e foto da carteira,
        // em multipart/form-data. A foto não vai para log (o log de requisições
        // não lê corpo) nem volta em resposta. A API usa token Bearer, não
        // cookie, então o antiforgery não se aplica.
        grupo.MapPost("/declarar", async (
            [FromForm] string? uf,
            [FromForm] string? numero,
            [FromForm] bool? permiteUso,
            IFormFile? foto,
            HttpContext http,
            ServicoPerfil perfilServico,
            ServicoCref servico,
            IValidator<DeclararCrefRequest> validator,
            CancellationToken ct) =>
        {
            var validacao = await validator.ValidateAsync(new DeclararCrefRequest(uf, numero, permiteUso), ct);
            if (!validacao.IsValid) return Results.ValidationProblem(validacao.ToDictionary());

            if (foto is null || foto.Length == 0 || foto.Length > FotoCarteiraCref.TamanhoMaximo)
            {
                return Results.ValidationProblem(new Dictionary<string, string[]>
                {
                    ["foto"] = ["Envie uma foto JPG ou PNG de até 5 MB."],
                });
            }

            var perfil = await PerfilAtual.ResolverAsync(http, perfilServico, ct);
            if (perfil is null) return TokenInvalido();

            using var memoria = new MemoryStream((int)foto.Length);
            await foto.CopyToAsync(memoria, ct);

            try
            {
                return Results.Ok(await servico.DeclararAsync(perfil.Id, uf!, numero!, memoria.ToArray(), ct));
            }
            catch (ArgumentException ex)
            {
                return Results.ValidationProblem(new Dictionary<string, string[]> { ["foto"] = [ex.Message] });
            }
            catch (ConflitoException ex)
            {
                return Results.Problem(title: ex.Message, statusCode: StatusCodes.Status409Conflict);
            }
        })
        .DisableAntiforgery()
        .WithName("DeclararCrefEducador")
        .WithSummary("Habilita o modo educador com UF, número e foto da carteira do CREF");

        return app;
    }

    private static IResult TokenInvalido() => Results.Problem(
        title: "Token sem identificador de usuário",
        statusCode: StatusCodes.Status401Unauthorized);
}
