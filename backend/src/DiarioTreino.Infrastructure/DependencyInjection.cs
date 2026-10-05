using DiarioTreino.Application.Acesso;
using DiarioTreino.Application.Identidade;
using DiarioTreino.Infrastructure.Persistencia;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace DiarioTreino.Infrastructure;

public static class DependencyInjection
{
    /// <summary>
    /// Registra a infraestrutura de persistência. A string de conexão vem da
    /// configuração (<c>ConnectionStrings:DiarioTreino</c>), nunca do código.
    /// </summary>
    public static IServiceCollection AddInfrastructure(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        var connectionString = configuration.GetConnectionString("DiarioTreino");

        services.AddDbContext<DiarioTreinoDbContext>(options =>
            options.UseNpgsql(connectionString, npgsql => npgsql.MigrationsAssembly(
                typeof(DiarioTreinoDbContext).Assembly.GetName().Name)));

        services.AddScoped<IRepositorioUsuario, RepositorioUsuario>();
        services.AddScoped<IRepositorioVinculo, RepositorioVinculo>();

        return services;
    }
}
