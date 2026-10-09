using DiarioTreino.Api.Autenticacao;
using DiarioTreino.Application.Execucao;
using DiarioTreino.Application.Identidade;
using FluentValidation;

namespace DiarioTreino.Api.Endpoints;

/// <summary>
/// Registro de treino (PBI-15) e ver/editar/excluir sessão (PBI-18). O
/// <see cref="RecursoNaoEncontradoHandler"/> traduz o acesso negado em 404.
/// Tudo exige autenticação.
/// </summary>
public static class SessaoEndpoints
{
    public static IEndpointRouteBuilder MapSessaoEndpoints(this IEndpointRouteBuilder app)
    {
        var grupo = app.MapGroup("/api/v1").RequireAuthorization();

        // Rascunho pré-preenchido para registrar a partir de uma ficha.
        grupo.MapGet("/treinos/{id:guid}/rascunho-sessao", async (
            Guid id,
            HttpContext http,
            ServicoPerfil perfilServico,
            ServicoSessao sessoes,
            CancellationToken ct) =>
        {
            var perfil = await PerfilAtual.ResolverAsync(http, perfilServico, ct);
            if (perfil is null) return TokenInvalido();

            var rascunho = await sessoes.MontarRascunhoAsync(perfil.Id, id, ct);
            return Results.Ok(rascunho);
        })
        .WithName("RascunhoSessao").WithTags("Sessões")
        .WithSummary("Rascunho de sessão pré-preenchido a partir da ficha");

        // Grava a sessão com as séries feitas.
        grupo.MapPost("/sessoes", async (
            HttpContext http,
            ServicoPerfil perfilServico,
            ServicoSessao sessoes,
            IValidator<CriarSessaoRequest> validator,
            CriarSessaoRequest request,
            CancellationToken ct) =>
        {
            var validacao = await validator.ValidateAsync(request, ct);
            if (!validacao.IsValid) return Results.ValidationProblem(validacao.ToDictionary());

            var perfil = await PerfilAtual.ResolverAsync(http, perfilServico, ct);
            if (perfil is null) return TokenInvalido();

            try
            {
                var id = await sessoes.CriarSessaoAsync(perfil.Id, request, ct);
                return Results.Created($"/api/v1/sessoes/{id}", new SessaoCriada(id));
            }
            catch (ArgumentException ex)
            {
                return Results.Problem(title: ex.Message, statusCode: StatusCodes.Status400BadRequest);
            }
        })
        .WithName("CriarSessao").WithTags("Sessões")
        .WithSummary("Registra uma sessão de treino");

        // ---- Ver / editar / excluir (PBI-18) ----

        // Detalhe de uma sessão (séries por exercício, plano, não realizados).
        grupo.MapGet("/sessoes/{id:guid}", async (
            Guid id,
            HttpContext http,
            ServicoPerfil perfilServico,
            ServicoSessao sessoes,
            CancellationToken ct) =>
        {
            var perfil = await PerfilAtual.ResolverAsync(http, perfilServico, ct);
            if (perfil is null) return TokenInvalido();

            var detalhe = await sessoes.ObterSessaoAsync(perfil.Id, id, ct);
            return Results.Ok(detalhe);
        })
        .WithName("DetalheSessao").WithTags("Sessões")
        .WithSummary("Detalhe de uma sessão registrada");

        // Edita uma sessão (data, duração, observação e séries).
        grupo.MapPut("/sessoes/{id:guid}", async (
            Guid id,
            HttpContext http,
            ServicoPerfil perfilServico,
            ServicoSessao sessoes,
            IValidator<CriarSessaoRequest> validator,
            CriarSessaoRequest request,
            CancellationToken ct) =>
        {
            var validacao = await validator.ValidateAsync(request, ct);
            if (!validacao.IsValid) return Results.ValidationProblem(validacao.ToDictionary());

            var perfil = await PerfilAtual.ResolverAsync(http, perfilServico, ct);
            if (perfil is null) return TokenInvalido();

            try
            {
                await sessoes.EditarSessaoAsync(perfil.Id, id, request, ct);
                return Results.NoContent();
            }
            catch (ArgumentException ex)
            {
                return Results.Problem(title: ex.Message, statusCode: StatusCodes.Status400BadRequest);
            }
        })
        .WithName("EditarSessao").WithTags("Sessões")
        .WithSummary("Edita uma sessão registrada");

        // Exclui uma sessão (remove do histórico e do gráfico).
        grupo.MapDelete("/sessoes/{id:guid}", async (
            Guid id,
            HttpContext http,
            ServicoPerfil perfilServico,
            ServicoSessao sessoes,
            CancellationToken ct) =>
        {
            var perfil = await PerfilAtual.ResolverAsync(http, perfilServico, ct);
            if (perfil is null) return TokenInvalido();

            await sessoes.ExcluirSessaoAsync(perfil.Id, id, ct);
            return Results.NoContent();
        })
        .WithName("ExcluirSessao").WithTags("Sessões")
        .WithSummary("Exclui uma sessão registrada");

        return app;
    }

    private static IResult TokenInvalido() => Results.Problem(
        title: "Token sem identificador de usuário",
        statusCode: StatusCodes.Status401Unauthorized);
}
