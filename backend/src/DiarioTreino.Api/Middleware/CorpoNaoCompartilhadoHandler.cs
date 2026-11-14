using DiarioTreino.Application.Corpo;
using Microsoft.AspNetCore.Diagnostics;

namespace DiarioTreino.Api.Middleware;

/// <summary>
/// Traduz <see cref="CorpoNaoCompartilhadoException"/> em 403 Problem Details
/// com type <c>corpo-nao-compartilhado</c> (PBI-95). O app usa o type para
/// mostrar o estado "trancado". Nunca leva valor corporal na mensagem.
/// </summary>
public sealed class CorpoNaoCompartilhadoHandler : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(
        HttpContext httpContext,
        Exception exception,
        CancellationToken cancellationToken)
    {
        if (exception is not CorpoNaoCompartilhadoException)
        {
            return false;
        }

        httpContext.Response.StatusCode = StatusCodes.Status403Forbidden;
        await httpContext.Response.WriteAsJsonAsync(
            new ProblemDetailsSimples(
                "corpo-nao-compartilhado",
                "Não compartilhado",
                StatusCodes.Status403Forbidden,
                "O aluno não compartilhou esta informação.",
                httpContext.Request.Path,
                httpContext.TraceIdentifier),
            cancellationToken);
        return true;
    }

    private sealed record ProblemDetailsSimples(
        string Type,
        string Title,
        int Status,
        string Detail,
        string Instance,
        string CorrelationId);
}
