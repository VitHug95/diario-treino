using DiarioTreino.Application.Acesso;
using DiarioTreino.Application.Catalogo;
using DiarioTreino.Application.Corpo;
using DiarioTreino.Application.Execucao;
using DiarioTreino.Application.Identidade;
using DiarioTreino.Application.Planejamento;
using DiarioTreino.Application.Progresso;
using DiarioTreino.Application.Relatorios;
using DiarioTreino.Infrastructure.Persistencia;
using DiarioTreino.Infrastructure.Relatorios;
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
        services.AddScoped<IRepositorioConsentimento, RepositorioConsentimento>();
        services.AddScoped<IRepositorioVinculo, RepositorioVinculo>();
        services.AddScoped<IRepositorioExercicio, RepositorioExercicio>();
        services.AddScoped<IRepositorioMetrica, RepositorioMetrica>();
        services.AddScoped<IRepositorioMembro, RepositorioMembro>();
        services.AddScoped<IRepositorioPlano, RepositorioPlano>();
        services.AddScoped<IRepositorioSessao, RepositorioSessao>();
        services.AddScoped<IRepositorioProgresso, RepositorioProgresso>();
        services.AddScoped<IRepositorioMedida, RepositorioMedida>();

        // Geração de PDF do progresso (PBI-89). A licença Community do QuestPDF
        // é configurada pelo próprio gerador (cctor), então ele é autossuficiente.
        services.AddSingleton<IGeradorRelatorioPdf, GeradorRelatorioPdfQuestPdf>();

        return services;
    }
}
