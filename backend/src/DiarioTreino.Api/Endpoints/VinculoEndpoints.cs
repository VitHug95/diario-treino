using DiarioTreino.Api.Autenticacao;
using DiarioTreino.Application.Comum;
using DiarioTreino.Application.Identidade;
using DiarioTreino.Application.Vinculos;
using FluentValidation;

namespace DiarioTreino.Api.Endpoints;

/// <summary>
/// Vínculo educador-aluno (PBI-85, épico E7): o educador convida por e-mail, o
/// aluno aceita ou recusa, e qualquer um dos dois encerra. <c>GET /alunos</c>
/// lista os alunos ativos do educador. O <see cref="Middleware.RecursoNaoEncontradoHandler"/>
/// traduz o acesso negado em 404 (vínculo de outro usuário). Tudo exige token.
/// </summary>
public static class VinculoEndpoints
{
    public static IEndpointRouteBuilder MapVinculoEndpoints(this IEndpointRouteBuilder app)
    {
        var grupo = app.MapGroup("/api/v1").RequireAuthorization();

        // Educador convida um aluno por e-mail (cria vínculo PENDENTE).
        grupo.MapPost("/vinculos", async (
            HttpContext http,
            ServicoPerfil perfilServico,
            ServicoVinculo vinculos,
            IValidator<ConvidarAlunoRequest> validator,
            ConvidarAlunoRequest request,
            CancellationToken ct) =>
        {
            var validacao = await validator.ValidateAsync(request, ct);
            if (!validacao.IsValid) return Results.ValidationProblem(validacao.ToDictionary());

            var perfil = await PerfilAtual.ResolverAsync(http, perfilServico, ct);
            if (perfil is null) return TokenInvalido();

            try
            {
                var id = await vinculos.ConvidarAsync(perfil.Id, request.Email, ct);
                return Results.Created($"/api/v1/vinculos/{id}", new { id });
            }
            catch (ArgumentException ex)
            {
                // Convite para si mesmo.
                return Results.Problem(title: ex.Message, statusCode: StatusCodes.Status400BadRequest);
            }
            catch (ConflitoException ex)
            {
                // Já existe convite/vínculo ativo com este aluno.
                return Results.Problem(title: ex.Message, statusCode: StatusCodes.Status409Conflict);
            }
        })
        .WithName("ConvidarAluno").WithTags("Vínculos").WithSummary("Convida um aluno por e-mail");

        // Convites pendentes do aluno logado.
        grupo.MapGet("/vinculos/pendentes", async (
            HttpContext http,
            ServicoPerfil perfilServico,
            ServicoVinculo vinculos,
            CancellationToken ct) =>
        {
            var perfil = await PerfilAtual.ResolverAsync(http, perfilServico, ct);
            if (perfil is null) return TokenInvalido();

            var pendentes = await vinculos.ListarPendentesAsync(perfil.Id, ct);
            return Results.Ok(pendentes);
        })
        .WithName("ConvitesPendentes").WithTags("Vínculos").WithSummary("Convites pendentes do aluno");

        // Aluno aceita o convite (PENDENTE → ATIVO). Vínculo de outro → 404.
        grupo.MapPost("/vinculos/{id:guid}/aceitar", async (
            Guid id,
            HttpContext http,
            ServicoPerfil perfilServico,
            ServicoVinculo vinculos,
            CancellationToken ct) =>
        {
            var perfil = await PerfilAtual.ResolverAsync(http, perfilServico, ct);
            if (perfil is null) return TokenInvalido();

            try
            {
                await vinculos.AceitarAsync(perfil.Id, id, ct);
                return Results.NoContent();
            }
            catch (ConflitoException ex)
            {
                return Results.Problem(title: ex.Message, statusCode: StatusCodes.Status409Conflict);
            }
        })
        .WithName("AceitarVinculo").WithTags("Vínculos").WithSummary("Aluno aceita o convite");

        // Aluno recusa o convite (PENDENTE → ENCERRADO). Vínculo de outro → 404.
        grupo.MapPost("/vinculos/{id:guid}/recusar", async (
            Guid id,
            HttpContext http,
            ServicoPerfil perfilServico,
            ServicoVinculo vinculos,
            CancellationToken ct) =>
        {
            var perfil = await PerfilAtual.ResolverAsync(http, perfilServico, ct);
            if (perfil is null) return TokenInvalido();

            try
            {
                await vinculos.RecusarAsync(perfil.Id, id, ct);
                return Results.NoContent();
            }
            catch (ConflitoException ex)
            {
                return Results.Problem(title: ex.Message, statusCode: StatusCodes.Status409Conflict);
            }
        })
        .WithName("RecusarVinculo").WithTags("Vínculos").WithSummary("Aluno recusa o convite");

        // Encerra um vínculo ativo (educador OU aluno). Vínculo de outro → 404.
        grupo.MapPost("/vinculos/{id:guid}/encerrar", async (
            Guid id,
            HttpContext http,
            ServicoPerfil perfilServico,
            ServicoVinculo vinculos,
            CancellationToken ct) =>
        {
            var perfil = await PerfilAtual.ResolverAsync(http, perfilServico, ct);
            if (perfil is null) return TokenInvalido();

            try
            {
                await vinculos.EncerrarAsync(perfil.Id, id, ct);
                return Results.NoContent();
            }
            catch (ConflitoException ex)
            {
                return Results.Problem(title: ex.Message, statusCode: StatusCodes.Status409Conflict);
            }
        })
        .WithName("EncerrarVinculo").WithTags("Vínculos").WithSummary("Encerra o vínculo ativo");

        // Alunos com vínculo ativo do educador logado.
        grupo.MapGet("/alunos", async (
            HttpContext http,
            ServicoPerfil perfilServico,
            ServicoVinculo vinculos,
            CancellationToken ct) =>
        {
            var perfil = await PerfilAtual.ResolverAsync(http, perfilServico, ct);
            if (perfil is null) return TokenInvalido();

            var alunos = await vinculos.ListarAlunosAtivosAsync(perfil.Id, ct);
            return Results.Ok(alunos);
        })
        .WithName("ListarAlunos").WithTags("Vínculos").WithSummary("Alunos com vínculo ativo");

        return app;
    }

    private static IResult TokenInvalido() => Results.Problem(
        title: "Token sem identificador de usuário",
        statusCode: StatusCodes.Status401Unauthorized);
}
