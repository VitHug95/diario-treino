using DiarioTreino.Api.Autenticacao;
using DiarioTreino.Application.Identidade;
using DiarioTreino.Application.Planejamento;
using FluentValidation;

namespace DiarioTreino.Api.Endpoints;

/// <summary>
/// Fichas de treino (PBI-12). O <see cref="RecursoNaoEncontradoHandler"/> traduz
/// o acesso negado em 404. Tudo exige autenticação.
/// </summary>
public static class PlanoEndpoints
{
    public static IEndpointRouteBuilder MapPlanoEndpoints(this IEndpointRouteBuilder app)
    {
        var grupo = app.MapGroup("/api/v1").RequireAuthorization();

        // Plano ativo do usuário logado (com as fichas).
        grupo.MapGet("/planos/ativo", async (
            HttpContext http,
            ServicoPerfil perfilServico,
            ServicoPlanejamento planejamento,
            CancellationToken ct) =>
        {
            var perfil = await PerfilAtual.ResolverAsync(http, perfilServico, ct);
            if (perfil is null) return TokenInvalido();

            var plano = await planejamento.ObterPlanoAtivoAsync(perfil.Id, ct);
            return plano is null ? Results.NoContent() : Results.Ok(plano);
        })
        .WithName("PlanoAtivo").WithTags("Fichas").WithSummary("Plano ativo com as fichas");

        // Cria o plano ativo (idempotente: devolve o existente se já houver).
        grupo.MapPost("/planos", async (
            HttpContext http,
            ServicoPerfil perfilServico,
            ServicoPlanejamento planejamento,
            CancellationToken ct) =>
        {
            var perfil = await PerfilAtual.ResolverAsync(http, perfilServico, ct);
            if (perfil is null) return TokenInvalido();

            var plano = await planejamento.CriarPlanoAsync(perfil.Id, ct);
            return Results.Ok(plano);
        })
        .WithName("CriarPlano").WithTags("Fichas").WithSummary("Garante um plano ativo");

        // Adiciona uma ficha ao plano ativo (cria o plano se for a primeira).
        grupo.MapPost("/planos/{id:guid}/treinos", async (
            Guid id,
            HttpContext http,
            ServicoPerfil perfilServico,
            ServicoPlanejamento planejamento,
            IValidator<SalvarTreinoRequest> validator,
            SalvarTreinoRequest request,
            CancellationToken ct) =>
        {
            var validacao = await validator.ValidateAsync(request, ct);
            if (!validacao.IsValid) return Results.ValidationProblem(validacao.ToDictionary());

            var perfil = await PerfilAtual.ResolverAsync(http, perfilServico, ct);
            if (perfil is null) return TokenInvalido();

            var treinoId = await planejamento.AdicionarFichaAsync(perfil.Id, request, ct);
            return Results.Created($"/api/v1/treinos/{treinoId}", new { id = treinoId });
        })
        .WithName("AdicionarFicha").WithTags("Fichas").WithSummary("Adiciona uma ficha");

        // Renomeia/edita a ficha.
        grupo.MapPut("/treinos/{id:guid}", async (
            Guid id,
            HttpContext http,
            ServicoPerfil perfilServico,
            ServicoPlanejamento planejamento,
            IValidator<SalvarTreinoRequest> validator,
            SalvarTreinoRequest request,
            CancellationToken ct) =>
        {
            var validacao = await validator.ValidateAsync(request, ct);
            if (!validacao.IsValid) return Results.ValidationProblem(validacao.ToDictionary());

            var perfil = await PerfilAtual.ResolverAsync(http, perfilServico, ct);
            if (perfil is null) return TokenInvalido();

            await planejamento.EditarFichaAsync(perfil.Id, id, request, ct);
            return Results.NoContent();
        })
        .WithName("EditarFicha").WithTags("Fichas").WithSummary("Renomeia/edita a ficha");

        // Arquiva a ficha (não apaga: histórico preservado).
        grupo.MapDelete("/treinos/{id:guid}", async (
            Guid id,
            HttpContext http,
            ServicoPerfil perfilServico,
            ServicoPlanejamento planejamento,
            CancellationToken ct) =>
        {
            var perfil = await PerfilAtual.ResolverAsync(http, perfilServico, ct);
            if (perfil is null) return TokenInvalido();

            await planejamento.ArquivarFichaAsync(perfil.Id, id, ct);
            return Results.NoContent();
        })
        .WithName("ArquivarFicha").WithTags("Fichas").WithSummary("Arquiva a ficha");

        return app;
    }

    private static IResult TokenInvalido() => Results.Problem(
        title: "Token sem identificador de usuário",
        statusCode: StatusCodes.Status401Unauthorized);
}
