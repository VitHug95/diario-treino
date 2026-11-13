using Microsoft.Net.Http.Headers;

namespace DiarioTreino.Api.Middleware;

/// <summary>
/// Nenhuma resposta da API vai para cache (PBI-100). As rotas devolvem dado
/// pessoal e de saúde do usuário logado, que muda a cada gravação: guardar a
/// resposta no navegador ou num proxy arriscaria mostrar a ficha de antes do
/// salvar e deixaria dado de saúde no disco. Vale para toda resposta (inclusive
/// erro), por isso entra no <c>OnStarting</c>.
/// </summary>
public sealed class SemCacheMiddleware
{
    private readonly RequestDelegate _next;

    public SemCacheMiddleware(RequestDelegate next)
    {
        _next = next;
    }

    public Task InvokeAsync(HttpContext context)
    {
        context.Response.OnStarting(() =>
        {
            var headers = context.Response.Headers;
            headers[HeaderNames.CacheControl] = "no-store";
            // Para caches HTTP/1.0 antigos que ignoram o Cache-Control.
            headers[HeaderNames.Pragma] = "no-cache";
            return Task.CompletedTask;
        });
        return _next(context);
    }
}