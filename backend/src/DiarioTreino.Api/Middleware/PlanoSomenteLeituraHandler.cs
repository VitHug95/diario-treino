using DiarioTreino.Application.Acesso;
using Microsoft.AspNetCore.Diagnostics;

namespace DiarioTreino.Api.Middleware;

/// <summary>
/// Traduz <see cref="PlanoSomenteLeituraException"/> em 403 Problem Details
/// (<c>plano-somente-leitura</c>). O atleta não edita plano montado pelo
/// professor (PBI-44, MAS 11.3). Vem sempre DEPOIS do controle de acesso, que
/// já responde 404 para recurso de outro usuário.
/// </summary>
public sealed class PlanoSomenteLeituraHandler : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(
        HttpContext httpContext,
        Exception exception,
        CancellationToken cancellationToken)
    {
        if (exception is not PlanoSomenteLeituraException)
        {
            return false;
        }

        httpContext.Response.StatusCode = StatusCodes.Status403Forbidden;
        await httpContext.Response.WriteAsJsonAsync(
            new ProblemDetailsSimples(
                "plano-somente-leitura",
                "Plano somente leitura",
                StatusCodes.Status403Forbidden,
                "Este plano foi montado pelo seu professor. Copie o plano para editar.",
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
