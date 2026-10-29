using DiarioTreino.Application.Comum;
using Microsoft.AspNetCore.Diagnostics;

namespace DiarioTreino.Api.Middleware;

/// <summary>
/// Traduz <see cref="AcaoNaoPermitidaException"/> em 403 Problem Details. Usado
/// quando o usuário não tem permissão para a ação (ex.: convidar aluno sem o
/// papel EDUCADOR). Diferente do 404 do controle de acesso, que vale para
/// recurso de outro atleta.
/// </summary>
public sealed class AcaoNaoPermitidaHandler : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(
        HttpContext httpContext,
        Exception exception,
        CancellationToken cancellationToken)
    {
        if (exception is not AcaoNaoPermitidaException naoPermitida)
        {
            return false;
        }

        httpContext.Response.StatusCode = StatusCodes.Status403Forbidden;
        await httpContext.Response.WriteAsJsonAsync(
            new ProblemDetailsSimples(
                "acao-nao-permitida",
                "Ação não permitida",
                StatusCodes.Status403Forbidden,
                naoPermitida.Message,
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
