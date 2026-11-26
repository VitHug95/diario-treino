using DiarioTreino.Application.Educador;
using Microsoft.AspNetCore.Diagnostics;

namespace DiarioTreino.Api.Middleware;

/// <summary>
/// Erros da habilitação do educador pelo CREF (PBI-106):
/// <see cref="EducadorNaoHabilitadoException"/> vira 403
/// <c>educador-nao-habilitado</c> (o app abre a tela do CREF) e
/// <see cref="LimiteTentativasCrefException"/> vira 429. Nenhum dos dois leva
/// dado da requisição na mensagem.
/// </summary>
public sealed class EducadorCrefHandler : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(
        HttpContext httpContext,
        Exception exception,
        CancellationToken cancellationToken)
    {
        var (status, type, title) = exception switch
        {
            EducadorNaoHabilitadoException =>
                (StatusCodes.Status403Forbidden, "educador-nao-habilitado", "Registro no CREF não confirmado"),
            LimiteTentativasCrefException =>
                (StatusCodes.Status429TooManyRequests, "limite-tentativas-cref", "Limite de tentativas"),
            _ => (0, string.Empty, string.Empty),
        };
        if (status == 0)
        {
            return false;
        }

        httpContext.Response.StatusCode = status;
        await httpContext.Response.WriteAsJsonAsync(
            new ProblemDetailsSimples(
                type, title, status, exception.Message, httpContext.Request.Path, httpContext.TraceIdentifier),
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
