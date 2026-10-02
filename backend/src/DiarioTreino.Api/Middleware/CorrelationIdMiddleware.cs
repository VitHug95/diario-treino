using Serilog.Context;

namespace DiarioTreino.Api.Middleware;

/// <summary>
/// Garante um identificador de correlação por requisição. Usa o cabeçalho
/// <c>X-Correlation-Id</c> quando o cliente envia, ou gera um novo. O valor é
/// propagado para os logs (via Serilog LogContext) e devolvido na resposta.
/// </summary>
public sealed class CorrelationIdMiddleware
{
    public const string HeaderName = "X-Correlation-Id";

    private readonly RequestDelegate _next;

    public CorrelationIdMiddleware(RequestDelegate next)
    {
        _next = next;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        var correlationId = ResolverCorrelationId(context);
        context.TraceIdentifier = correlationId;

        context.Response.OnStarting(() =>
        {
            context.Response.Headers[HeaderName] = correlationId;
            return Task.CompletedTask;
        });

        using (LogContext.PushProperty("CorrelationId", correlationId))
        {
            await _next(context);
        }
    }

    private static string ResolverCorrelationId(HttpContext context)
    {
        if (context.Request.Headers.TryGetValue(HeaderName, out var valor) &&
            !string.IsNullOrWhiteSpace(valor))
        {
            return valor.ToString();
        }

        return Guid.NewGuid().ToString("n");
    }
}
