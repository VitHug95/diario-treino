using DiarioTreino.Api.Autenticacao;
using DiarioTreino.Application.Identidade;

namespace DiarioTreino.Api.Endpoints;

/// <summary>
/// <c>GET /api/v1/me</c>: perfil e papéis do usuário logado. No primeiro acesso
/// provisiona o usuário com o papel ATLETA (MAS 11.1 / PBI-06).
/// <c>DELETE /api/v1/me</c>: exclui a conta e todos os dados do usuário
/// (PBI-25). Ambos exigem token válido; sem token, o pipeline responde 401.
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

        // Ativar o modo educador: concede o papel EDUCADOR ao usuário logado
        // (PBI-85). Idempotente; devolve o perfil com os papéis atuais.
        grupo.MapPost("/me/papeis/educador", async (
            HttpContext http,
            ServicoPerfil servico,
            CancellationToken ct) =>
        {
            var perfil = await PerfilAtual.ResolverAsync(http, servico, ct);
            if (perfil is null)
            {
                return Results.Problem(
                    title: "Token sem identificador de usuário",
                    statusCode: StatusCodes.Status401Unauthorized);
            }

            var atualizado = await servico.ConcederPapelEducadorAsync(perfil.Id, ct);
            return Results.Ok(atualizado);
        })
        .WithName("AtivarEducador")
        .WithTags("Identidade")
        .WithSummary("Concede o papel de educador ao usuário logado");

        // Excluir conta: apaga os dados do usuário no Postgres (hard delete
        // transacional). O app remove o usuário no Firebase depois do 204.
        grupo.MapDelete("/me", async (
            HttpContext http,
            ServicoPerfil servico,
            CancellationToken ct) =>
        {
            var perfil = await PerfilAtual.ResolverAsync(http, servico, ct);
            if (perfil is null)
            {
                return Results.Problem(
                    title: "Token sem identificador de usuário",
                    statusCode: StatusCodes.Status401Unauthorized);
            }

            await servico.ExcluirContaAsync(perfil.Id, ct);
            return Results.NoContent();
        })
        .WithName("ExcluirConta")
        .WithTags("Identidade")
        .WithSummary("Exclui a conta e todos os dados do usuário logado");

        return app;
    }
}
