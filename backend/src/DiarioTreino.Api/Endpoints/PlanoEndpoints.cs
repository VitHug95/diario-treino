using DiarioTreino.Api.Autenticacao;
using DiarioTreino.Application.Comum;
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
        .WithName("PlanoAtivo").WithTags("Fichas").WithSummary("Plano em uso com as fichas");

        // Lista os planos do atleta logado (PBI-44): em uso primeiro.
        grupo.MapGet("/planos", async (
            HttpContext http,
            ServicoPerfil perfilServico,
            ServicoPlanejamento planejamento,
            CancellationToken ct) =>
        {
            var perfil = await PerfilAtual.ResolverAsync(http, perfilServico, ct);
            if (perfil is null) return TokenInvalido();

            var planos = await planejamento.ListarPlanosAsync(perfil.Id, ct);
            return Results.Ok(planos);
        })
        .WithName("ListarPlanos").WithTags("Planos").WithSummary("Planos do atleta");

        // Detalhe de um plano com as fichas (PBI-44). Plano de outro usuário → 404.
        grupo.MapGet("/planos/{id:guid}", async (
            Guid id,
            HttpContext http,
            ServicoPerfil perfilServico,
            ServicoPlanejamento planejamento,
            CancellationToken ct) =>
        {
            var perfil = await PerfilAtual.ResolverAsync(http, perfilServico, ct);
            if (perfil is null) return TokenInvalido();

            var plano = await planejamento.ObterPlanoAsync(perfil.Id, id, ct);
            return Results.Ok(plano);
        })
        .WithName("DetalhePlano").WithTags("Planos").WithSummary("Plano com as fichas");

        // Cria um plano. Com corpo { nome } cria um plano nomeado (PBI-44);
        // SEM corpo mantém o comportamento antigo (idempotente: devolve o plano
        // em uso, criando um se não houver) — contrato usado pelo E2E.
        grupo.MapPost("/planos", async (
            HttpContext http,
            ServicoPerfil perfilServico,
            ServicoPlanejamento planejamento,
            CancellationToken ct) =>
        {
            var perfil = await PerfilAtual.ResolverAsync(http, perfilServico, ct);
            if (perfil is null) return TokenInvalido();

            // Corpo opcional: lê { nome } de forma tolerante a corpo vazio.
            var nome = await LerNomeOpcionalAsync(http, ct);
            if (!string.IsNullOrWhiteSpace(nome))
            {
                var criado = await planejamento.CriarPlanoNomeadoAsync(perfil.Id, nome!, ct);
                return Results.Created($"/api/v1/planos/{criado.Id}", criado);
            }

            var plano = await planejamento.CriarPlanoAsync(perfil.Id, ct);
            return Results.Ok(plano);
        })
        .WithName("CriarPlano").WithTags("Planos").WithSummary("Cria um plano (com nome) ou garante o em uso");

        // Renomeia o plano (PBI-44). Plano de outro usuário → 404; plano de
        // autor diferente do atleta → 403 (somente leitura).
        grupo.MapPut("/planos/{id:guid}", async (
            Guid id,
            HttpContext http,
            ServicoPerfil perfilServico,
            ServicoPlanejamento planejamento,
            IValidator<SalvarPlanoRequest> validator,
            SalvarPlanoRequest request,
            CancellationToken ct) =>
        {
            var validacao = await validator.ValidateAsync(request, ct);
            if (!validacao.IsValid) return Results.ValidationProblem(validacao.ToDictionary());

            var perfil = await PerfilAtual.ResolverAsync(http, perfilServico, ct);
            if (perfil is null) return TokenInvalido();

            await planejamento.RenomearPlanoAsync(perfil.Id, id, request.Nome, ct);
            return Results.NoContent();
        })
        .WithName("RenomearPlano").WithTags("Planos").WithSummary("Renomeia o plano");

        // Define o plano como o em uso do atleta (transação; nunca zero/dois).
        grupo.MapPost("/planos/{id:guid}/em-uso", async (
            Guid id,
            HttpContext http,
            ServicoPerfil perfilServico,
            ServicoPlanejamento planejamento,
            CancellationToken ct) =>
        {
            var perfil = await PerfilAtual.ResolverAsync(http, perfilServico, ct);
            if (perfil is null) return TokenInvalido();

            await planejamento.DefinirEmUsoAsync(perfil.Id, id, ct);
            return Results.NoContent();
        })
        .WithName("DefinirPlanoEmUso").WithTags("Planos").WithSummary("Define o plano em uso");

        // Duplica o plano: cópia de autoria do atleta, fora de uso, sem sessões.
        grupo.MapPost("/planos/{id:guid}/duplicar", async (
            Guid id,
            HttpContext http,
            ServicoPerfil perfilServico,
            ServicoPlanejamento planejamento,
            CancellationToken ct) =>
        {
            var perfil = await PerfilAtual.ResolverAsync(http, perfilServico, ct);
            if (perfil is null) return TokenInvalido();

            var copiaId = await planejamento.DuplicarPlanoAsync(perfil.Id, id, ct);
            return Results.Created($"/api/v1/planos/{copiaId}", new { id = copiaId });
        })
        .WithName("DuplicarPlano").WithTags("Planos").WithSummary("Duplica o plano");

        // Exclui o plano (apaga se sem sessões, esconde se com; passa o uso).
        grupo.MapDelete("/planos/{id:guid}", async (
            Guid id,
            HttpContext http,
            ServicoPerfil perfilServico,
            ServicoPlanejamento planejamento,
            CancellationToken ct) =>
        {
            var perfil = await PerfilAtual.ResolverAsync(http, perfilServico, ct);
            if (perfil is null) return TokenInvalido();

            await planejamento.ExcluirPlanoAsync(perfil.Id, id, ct);
            return Results.NoContent();
        })
        .WithName("ExcluirPlano").WithTags("Planos").WithSummary("Exclui o plano");

        // Adiciona uma ficha AO PLANO do id da URL (PBI-44: antes ignorava o id
        // e usava o plano em uso). Plano de autor diferente → 403.
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

            var treinoId = await planejamento.AdicionarFichaAsync(perfil.Id, id, request, ct);
            return Results.Created($"/api/v1/treinos/{treinoId}", new { id = treinoId });
        })
        .WithName("AdicionarFicha").WithTags("Fichas").WithSummary("Adiciona uma ficha ao plano");

        // Cria uma ficha a partir dos exercícios de um treino livre (PBI-19,
        // "Salvar também como ficha"). Garante o plano, cria a ficha e adiciona
        // os exercícios na ordem informada.
        grupo.MapPost("/planos/fichas-de-treino", async (
            HttpContext http,
            ServicoPerfil perfilServico,
            ServicoPlanejamento planejamento,
            IValidator<CriarFichaDeTreinoRequest> validator,
            CriarFichaDeTreinoRequest request,
            CancellationToken ct) =>
        {
            var validacao = await validator.ValidateAsync(request, ct);
            if (!validacao.IsValid) return Results.ValidationProblem(validacao.ToDictionary());

            var perfil = await PerfilAtual.ResolverAsync(http, perfilServico, ct);
            if (perfil is null) return TokenInvalido();

            var treinoId = await planejamento.CriarFichaDeExerciciosAsync(perfil.Id, request, ct);
            return Results.Created($"/api/v1/treinos/{treinoId}", new { id = treinoId });
        })
        .WithName("CriarFichaDeTreino").WithTags("Fichas")
        .WithSummary("Cria uma ficha a partir dos exercícios de um treino livre");

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

        // Exclui a ficha: apaga de verdade se não tem sessões; arquiva se tem
        // (histórico e gráfico preservados). PBI-36.
        grupo.MapDelete("/treinos/{id:guid}", async (
            Guid id,
            HttpContext http,
            ServicoPerfil perfilServico,
            ServicoPlanejamento planejamento,
            CancellationToken ct) =>
        {
            var perfil = await PerfilAtual.ResolverAsync(http, perfilServico, ct);
            if (perfil is null) return TokenInvalido();

            await planejamento.ExcluirFichaAsync(perfil.Id, id, ct);
            return Results.NoContent();
        })
        .WithName("ExcluirFicha").WithTags("Fichas").WithSummary("Exclui a ficha (apaga ou arquiva)");

        // ---- Exercícios da ficha (PBI-13) ----

        // Detalhe da ficha com os exercícios.
        grupo.MapGet("/treinos/{id:guid}", async (
            Guid id,
            HttpContext http,
            ServicoPerfil perfilServico,
            ServicoPlanejamento planejamento,
            CancellationToken ct) =>
        {
            var perfil = await PerfilAtual.ResolverAsync(http, perfilServico, ct);
            if (perfil is null) return TokenInvalido();

            var ficha = await planejamento.ObterFichaAsync(perfil.Id, id, ct);
            return Results.Ok(ficha);
        })
        .WithName("DetalheFicha").WithTags("Fichas").WithSummary("Ficha com os exercícios");

        // Adiciona um exercício do catálogo à ficha.
        grupo.MapPost("/treinos/{id:guid}/exercicios", async (
            Guid id,
            HttpContext http,
            ServicoPerfil perfilServico,
            ServicoPlanejamento planejamento,
            AdicionarExercicioRequest request,
            CancellationToken ct) =>
        {
            var perfil = await PerfilAtual.ResolverAsync(http, perfilServico, ct);
            if (perfil is null) return TokenInvalido();

            try
            {
                var teId = await planejamento.AdicionarExercicioAsync(
                    perfil.Id, id, request.ExercicioId, ct);
                return Results.Created($"/api/v1/treinos/{id}/exercicios/{teId}", new { id = teId });
            }
            catch (ConflitoException ex)
            {
                // PBI-74: exercício já na ficha → 409 (o app trata como "já estava").
                return Results.Problem(title: ex.Message, statusCode: StatusCodes.Status409Conflict);
            }
        })
        .WithName("AdicionarExercicioFicha").WithTags("Fichas")
        .WithSummary("Adiciona um exercício do catálogo à ficha");

        // Reordena os exercícios da ficha.
        grupo.MapPut("/treinos/{id:guid}/exercicios/ordem", async (
            Guid id,
            HttpContext http,
            ServicoPerfil perfilServico,
            ServicoPlanejamento planejamento,
            ReordenarExerciciosRequest request,
            CancellationToken ct) =>
        {
            var perfil = await PerfilAtual.ResolverAsync(http, perfilServico, ct);
            if (perfil is null) return TokenInvalido();

            await planejamento.ReordenarExerciciosAsync(
                perfil.Id, id, request.TreinoExercicioIds, ct);
            return Results.NoContent();
        })
        .WithName("ReordenarExerciciosFicha").WithTags("Fichas")
        .WithSummary("Reordena os exercícios da ficha");

        // Remove um exercício da ficha (histórico preservado).
        grupo.MapDelete("/treinos/{id:guid}/exercicios/{treinoExercicioId:guid}", async (
            Guid id,
            Guid treinoExercicioId,
            HttpContext http,
            ServicoPerfil perfilServico,
            ServicoPlanejamento planejamento,
            CancellationToken ct) =>
        {
            var perfil = await PerfilAtual.ResolverAsync(http, perfilServico, ct);
            if (perfil is null) return TokenInvalido();

            await planejamento.RemoverExercicioAsync(perfil.Id, treinoExercicioId, ct);
            return Results.NoContent();
        })
        .WithName("RemoverExercicioFicha").WithTags("Fichas")
        .WithSummary("Remove um exercício da ficha");

        // Define os alvos do exercício na ficha (séries, carga/reps, descanso). PBI-14.
        grupo.MapPut("/treinos/{id:guid}/exercicios/{treinoExercicioId:guid}/alvos", async (
            Guid id,
            Guid treinoExercicioId,
            HttpContext http,
            ServicoPerfil perfilServico,
            ServicoPlanejamento planejamento,
            IValidator<DefinirAlvosRequest> validator,
            DefinirAlvosRequest request,
            CancellationToken ct) =>
        {
            var validacao = await validator.ValidateAsync(request, ct);
            if (!validacao.IsValid) return Results.ValidationProblem(validacao.ToDictionary());

            var perfil = await PerfilAtual.ResolverAsync(http, perfilServico, ct);
            if (perfil is null) return TokenInvalido();

            try
            {
                await planejamento.DefinirAlvosAsync(perfil.Id, treinoExercicioId, request, ct);
                return Results.NoContent();
            }
            catch (ArgumentException ex)
            {
                return Results.Problem(title: ex.Message, statusCode: StatusCodes.Status400BadRequest);
            }
        })
        .WithName("DefinirAlvosExercicio").WithTags("Fichas")
        .WithSummary("Define séries e alvos do exercício na ficha");

        return app;
    }

    private static IResult TokenInvalido() => Results.Problem(
        title: "Token sem identificador de usuário",
        statusCode: StatusCodes.Status401Unauthorized);

    /// <summary>
    /// Lê { "nome": ... } do corpo do POST /planos de forma tolerante: corpo
    /// vazio (o E2E chama sem corpo) devolve nulo, mantendo o comportamento
    /// idempotente antigo. Não lança em JSON malformado — trata como sem nome.
    /// </summary>
    private static async Task<string?> LerNomeOpcionalAsync(HttpContext http, CancellationToken ct)
    {
        if (http.Request.ContentLength is null or 0)
        {
            return null;
        }

        try
        {
            var corpo = await http.Request.ReadFromJsonAsync<SalvarPlanoRequest>(ct);
            return corpo?.Nome;
        }
        catch (System.Text.Json.JsonException)
        {
            return null;
        }
    }
}
