using DiarioTreino.Api.Endpoints;
using DiarioTreino.Api.Middleware;
using DiarioTreino.Infrastructure;
using Serilog;

// Logger de bootstrap: captura falhas de inicialização antes da configuração final.
Log.Logger = new LoggerConfiguration()
    .WriteTo.Console()
    .CreateBootstrapLogger();

try
{
    var builder = WebApplication.CreateBuilder(args);

    // Serilog estruturado, lido da configuração (appsettings) e do contexto.
    builder.Host.UseSerilog((context, services, configuration) => configuration
        .ReadFrom.Configuration(context.Configuration)
        .ReadFrom.Services(services)
        .Enrich.FromLogContext());

    // Problem Details (RFC 9457) como formato padrão de erro da API.
    builder.Services.AddProblemDetails(options =>
    {
        options.CustomizeProblemDetails = ctx =>
        {
            ctx.ProblemDetails.Instance = ctx.HttpContext.Request.Path;
            ctx.ProblemDetails.Extensions["correlationId"] = ctx.HttpContext.TraceIdentifier;
        };
    });

    // OpenAPI nativo do ASP.NET Core (documento em /openapi/v1.json).
    builder.Services.AddOpenApi();

    // Persistência (EF Core + Npgsql). Conexão vem da configuração.
    builder.Services.AddInfrastructure(builder.Configuration);

    var app = builder.Build();

    // Converte exceções não tratadas em Problem Details.
    app.UseExceptionHandler();
    app.UseStatusCodePages();

    // Correlação por requisição, antes do log de requisições do Serilog.
    app.UseMiddleware<CorrelationIdMiddleware>();
    app.UseSerilogRequestLogging();

    if (app.Environment.IsDevelopment())
    {
        app.MapOpenApi();
    }

    app.MapHealthEndpoints();

    app.Run();
}
catch (Exception ex) when (ex is not HostAbortedException)
{
    Log.Fatal(ex, "A API encerrou de forma inesperada durante a inicialização.");
}
finally
{
    Log.CloseAndFlush();
}

/// <summary>Exposto para os testes de integração (WebApplicationFactory).</summary>
public partial class Program;
