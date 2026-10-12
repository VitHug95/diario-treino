using DiarioTreino.Infrastructure.Persistencia;
using Microsoft.EntityFrameworkCore;

namespace DiarioTreino.Api.Infraestrutura;

/// <summary>
/// Aplica as migrations pendentes ao subir a API. Em produção, deixa o banco
/// (Neon) pronto sem passo manual de deploy. Controlado por
/// <c>Banco:AplicarMigracoesNoStartup</c> (padrão: só em produção).
/// </summary>
public static class MigracoesStartup
{
    public static async Task AplicarMigracoesSeConfiguradoAsync(this WebApplication app)
    {
        var configurado = app.Configuration.GetValue<bool?>("Banco:AplicarMigracoesNoStartup");
        var aplicar = configurado ?? app.Environment.IsProduction();
        if (!aplicar)
        {
            return;
        }

        using var scope = app.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<DiarioTreinoDbContext>();
        var logger = app.Services.GetRequiredService<ILoggerFactory>()
            .CreateLogger("MigracoesStartup");

        logger.LogInformation("Aplicando migrations pendentes no banco...");
        await db.Database.MigrateAsync();
        logger.LogInformation("Migrations aplicadas.");
    }
}
