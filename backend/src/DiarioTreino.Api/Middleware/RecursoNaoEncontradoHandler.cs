using DiarioTreino.Application.Acesso;
using Microsoft.AspNetCore.Diagnostics;

namespace DiarioTreino.Api.Middleware;

/// <summary>
/// Traduz <see cref="RecursoNaoEncontradoException"/> em 404 Problem Details.
/// É o que faz a regra de acesso do MAS 11.3 responder 404 (não 403) quando o
/// usuário não pode ver o recurso.
/// </summary>
public sealed class RecursoNaoEncontradoHandler : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(
        HttpContext httpContext,
        Exception exception,
        CancellationToken cancellationToken)
    {
        if (exception is not RecursoNaoEncontradoException)
        {
            return false;
        }

        httpContext.Response.StatusCode = StatusCodes.Status404NotFound;
        await httpContext.Response.WriteAsJsonAsync(
            new ProblemDetailsSimples(
                "https://datatracker.ietf.org/doc/html/rfc9457",
                "Recurso não encontrado",
                StatusCodes.Status404NotFound,
                httpContext.Request.Path,
                httpContext.TraceIdentifier),
            cancellationToken);
        return true;
    }

    private sealed record ProblemDetailsSimples(
        string Type,
        string Title,
        int Status,
        string Instance,
        string CorrelationId);
}
