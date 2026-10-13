using DiarioTreino.Api.Autenticacao;
using DiarioTreino.Api.Endpoints;
using DiarioTreino.Api.Infraestrutura;
using DiarioTreino.Api.Middleware;
using DiarioTreino.Application;
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

    // Traduz RecursoNaoEncontradoException em 404 (MAS 11.3).
    builder.Services.AddExceptionHandler<DiarioTreino.Api.Middleware.RecursoNaoEncontradoHandler>();

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

    // Casos de uso e persistência.
    builder.Services.AddApplication();
    builder.Services.AddInfrastructure(builder.Configuration);

    // Autenticação via token do Firebase (MAS 11.2).
    builder.Services.AddAutenticacaoFirebase(builder.Configuration);

    // CORS: o app web chama a API de outra origem (dev: localhost do Flutter;
    // produção: domínio do front). As origens vêm da configuração
    // "Cors:OrigensPermitidas" (lista). Em Development, se nada for informado,
    // libera qualquer localhost para não travar o desenvolvimento.
    const string politicaCors = "AppWeb";
    var origensPermitidas = builder.Configuration
        .GetSection("Cors:OrigensPermitidas").Get<string[]>() ?? [];
    builder.Services.AddCors(options =>
    {
        options.AddPolicy(politicaCors, policy =>
        {
            if (origensPermitidas.Length > 0)
            {
                policy.WithOrigins(origensPermitidas);
            }
            else if (builder.Environment.IsDevelopment())
            {
                // Flutter web usa porta aleatória em localhost; libera todas.
                policy.SetIsOriginAllowed(origem =>
                {
                    if (!Uri.TryCreate(origem, UriKind.Absolute, out var uri))
                    {
                        return false;
                    }
                    return uri.Host is "localhost" or "127.0.0.1";
                });
            }

            policy.AllowAnyHeader().AllowAnyMethod();
        });
    });

    var app = builder.Build();

    // Converte exceções não tratadas em Problem Details.
    app.UseExceptionHandler();
    app.UseStatusCodePages();

    // Correlação por requisição, antes do log de requisições do Serilog.
    app.UseMiddleware<CorrelationIdMiddleware>();
    app.UseSerilogRequestLogging();

    // CORS antes da autenticação, para o preflight (OPTIONS) passar.
    app.UseCors(politicaCors);

    app.UseAuthentication();
    app.UseAuthorization();

    if (app.Environment.IsDevelopment())
    {
        app.MapOpenApi();
    }

    app.MapHealthEndpoints();
    app.MapMeEndpoints();
    app.MapExercicioEndpoints();
    app.MapPlanoEndpoints();
    app.MapSessaoEndpoints();
    app.MapProgressoEndpoints();

    // Em produção, aplica as migrations pendentes antes de atender requisições.
    await app.AplicarMigracoesSeConfiguradoAsync();

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
