using DiarioTreino.Infrastructure.Persistencia;

namespace DiarioTreino.Api.Endpoints;

/// <summary>
/// Endpoints de verificação de saúde (MAS seção 17).
/// <list type="bullet">
/// <item><c>/health</c>: liveness barata, usada pelo Docker para reiniciar a API
/// se ela travar. Não toca no banco.</item>
/// <item><c>/health/ready</c>: readiness, confirma a conexão com o banco.</item>
/// </list>
/// </summary>
public static class HealthEndpoints
{
    public static IEndpointRouteBuilder MapHealthEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapGet("/health", () => Results.Ok(new HealthResponse("healthy")))
            .WithName("Health")
            .WithTags("Infra")
            .WithSummary("Liveness da API")
            .AllowAnonymous();

        app.MapGet("/health/ready", async (DiarioTreinoDbContext db, CancellationToken ct) =>
            {
                var bancoOk = await db.Database.CanConnectAsync(ct);
                return bancoOk
                    ? Results.Ok(new HealthResponse("ready"))
                    : Results.Json(
                        new HealthResponse("degraded"),
                        statusCode: StatusCodes.Status503ServiceUnavailable);
            })
            .WithName("HealthReady")
            .WithTags("Infra")
            .WithSummary("Readiness: API e conexão com o banco")
            .AllowAnonymous();

        return app;
    }

    private sealed record HealthResponse(string Status);
}
