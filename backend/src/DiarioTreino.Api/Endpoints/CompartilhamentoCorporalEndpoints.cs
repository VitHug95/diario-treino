using DiarioTreino.Api.Autenticacao;
using DiarioTreino.Application.Corpo;
using DiarioTreino.Application.Identidade;
using FluentValidation;

namespace DiarioTreino.Api.Endpoints;

/// <summary>
/// Compartilhamento do corpo com o educador (E12 / PBI-95). O atleta define os
/// dois cadeados em <c>/me/compartilhamento-corporal</c>; o educador lê em
/// <c>/alunos/{atletaId}/...</c>, só com vínculo ativo (senão 404) e só o que
/// estiver destrancado (a evolução trancada é 403 <c>corpo-nao-compartilhado</c>).
/// Dado de saúde: nenhum valor vai para log nem para mensagem de erro.
/// </summary>
public static class CompartilhamentoCorporalEndpoints
{
    public static IEndpointRouteBuilder MapCompartilhamentoCorporalEndpoints(this IEndpointRouteBuilder app)
    {
        var me = app.MapGroup("/api/v1/me/compartilhamento-corporal")
            .RequireAuthorization()
            .WithTags("Compartilhamento corporal");

        me.MapGet("", async (
            HttpContext http,
            ServicoPerfil perfilServico,
            ServicoCompartilhamentoCorporal servico,
            CancellationToken ct) =>
        {
            var perfil = await PerfilAtual.ResolverAsync(http, perfilServico, ct);
            if (perfil is null) return TokenInvalido();

            return Results.Ok(await servico.ObterAsync(perfil.Id, ct));
        })
        .WithName("ObterCompartilhamentoCorporal")
        .WithSummary("Os dois cadeados do corpo e quem vê (educadores com vínculo ativo)");

        me.MapPut("", async (
            DefinirCompartilhamentoRequest request,
            HttpContext http,
            ServicoPerfil perfilServico,
            ServicoCompartilhamentoCorporal servico,
            IValidator<DefinirCompartilhamentoRequest> validator,
            CancellationToken ct) =>
        {
            var validacao = await validator.ValidateAsync(request, ct);
            if (!validacao.IsValid) return Results.ValidationProblem(validacao.ToDictionary());

            var perfil = await PerfilAtual.ResolverAsync(http, perfilServico, ct);
            if (perfil is null) return TokenInvalido();

            return Results.Ok(await servico.DefinirAsync(
                perfil.Id, request.DadosCorporais!.Value, request.Medidas!.Value, ct));
        })
        .WithName("DefinirCompartilhamentoCorporal")
        .WithSummary("Tranca ou destranca os dados corporais e as medidas");

        var alunos = app.MapGroup("/api/v1/alunos/{atletaId:guid}")
            .RequireAuthorization()
            .WithTags("Educador");

        alunos.MapGet("/corpo", async (
            Guid atletaId,
            HttpContext http,
            ServicoPerfil perfilServico,
            ServicoCompartilhamentoCorporal servico,
            CancellationToken ct) =>
        {
            var perfil = await PerfilAtual.ResolverAsync(http, perfilServico, ct);
            if (perfil is null) return TokenInvalido();

            return Results.Ok(await servico.ObterCorpoDoAlunoAsync(perfil.Id, atletaId, ct));
        })
        .WithName("CorpoDoAluno")
        .WithSummary("Dados corporais e medidas do aluno; seção trancada volta nula");

        alunos.MapGet("/medidas/{tipo}/evolucao", async (
            Guid atletaId,
            string tipo,
            DateOnly? de,
            DateOnly? ate,
            HttpContext http,
            ServicoPerfil perfilServico,
            ServicoCompartilhamentoCorporal servico,
            CancellationToken ct) =>
        {
            var perfil = await PerfilAtual.ResolverAsync(http, perfilServico, ct);
            if (perfil is null) return TokenInvalido();

            try
            {
                return Results.Ok(await servico.ObterEvolucaoDoAlunoAsync(
                    perfil.Id, atletaId, tipo, de, ate, ct));
            }
            catch (ArgumentException ex)
            {
                return Results.Problem(title: ex.Message, statusCode: StatusCodes.Status400BadRequest);
            }
        })
        .WithName("EvolucaoMedidaDoAluno")
        .WithSummary("Evolução de uma medida do aluno (403 se as medidas estão trancadas)");

        return app;
    }

    private static IResult TokenInvalido() => Results.Problem(
        title: "Token sem identificador de usuário",
        statusCode: StatusCodes.Status401Unauthorized);
}
