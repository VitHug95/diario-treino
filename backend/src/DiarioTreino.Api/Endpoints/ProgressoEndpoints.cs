using DiarioTreino.Api.Autenticacao;
using DiarioTreino.Application.Identidade;
using DiarioTreino.Application.Progresso;
using DiarioTreino.Application.Relatorios;

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

        // Exercícios que o atleta já treinou (seletor do gráfico).
        grupo.MapGet("/progresso/exercicios", async (
            Guid? atletaId,
            HttpContext http,
            ServicoPerfil perfilServico,
            ServicoProgresso progresso,
            CancellationToken ct) =>
        {
            var perfil = await PerfilAtual.ResolverAsync(http, perfilServico, ct);
            if (perfil is null) return TokenInvalido();

            var alvo = atletaId ?? perfil.Id;
            var itens = await progresso.ListarExerciciosComHistoricoAsync(perfil.Id, alvo, ct);
            return Results.Ok(itens);
        })
        .WithName("ExerciciosComHistorico").WithTags("Progresso")
        .WithSummary("Exercícios que o atleta já treinou");

        // Série de evolução de um exercício no período. de/ate opcionais;
        // atletaId opcional para o educador (PBI-86).
        grupo.MapGet("/progresso/exercicios/{exercicioId:guid}", async (
            Guid exercicioId,
            DateOnly? de,
            DateOnly? ate,
            Guid? atletaId,
            HttpContext http,
            ServicoPerfil perfilServico,
            ServicoProgresso progresso,
            CancellationToken ct) =>
        {
            var perfil = await PerfilAtual.ResolverAsync(http, perfilServico, ct);
            if (perfil is null) return TokenInvalido();

            var alvo = atletaId ?? perfil.Id;
            var dados = await progresso.ObterProgressoAsync(perfil.Id, alvo, exercicioId, de, ate, ct);
            return Results.Ok(dados);
        })
        .WithName("ProgressoExercicio").WithTags("Progresso")
        .WithSummary("Evolução de um exercício no período");

        // PDF do progresso (PBI-89): evolução por exercício + sessões do
        // período. Vale para o próprio atleta ou, com atletaId, para o educador
        // com vínculo ativo (sem acesso → 404). de/ate opcionais: sem eles, os
        // últimos 90 dias. A observação privada do aluno não entra no PDF.
        grupo.MapGet("/progresso/pdf", async (
            DateOnly? de,
            DateOnly? ate,
            Guid? atletaId,
            HttpContext http,
            ServicoPerfil perfilServico,
            ServicoRelatorio relatorio,
            CancellationToken ct) =>
        {
            var perfil = await PerfilAtual.ResolverAsync(http, perfilServico, ct);
            if (perfil is null) return TokenInvalido();

            var alvo = atletaId ?? perfil.Id;
            var pdf = await relatorio.GerarProgressoPdfAsync(perfil.Id, alvo, de, ate, ct);
            return Results.File(pdf, "application/pdf", "progresso.pdf");
        })
        .WithName("ProgressoPdf").WithTags("Progresso")
        .WithSummary("PDF do progresso (evolução + sessões) do período");

        return app;
    }

    private static IResult TokenInvalido() => Results.Problem(
        title: "Token sem identificador de usuário",
        statusCode: StatusCodes.Status401Unauthorized);
}
