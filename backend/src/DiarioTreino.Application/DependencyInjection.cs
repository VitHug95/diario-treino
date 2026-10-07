using DiarioTreino.Application.Acesso;
using DiarioTreino.Application.Catalogo;
using DiarioTreino.Application.Identidade;
using Microsoft.Extensions.DependencyInjection;

namespace DiarioTreino.Application;

public static class DependencyInjection
{
    public static IServiceCollection AddApplication(this IServiceCollection services)
    {
        services.AddScoped<ServicoPerfil>();
        services.AddScoped<IControleAcesso, ControleAcesso>();
        services.AddScoped<ServicoCatalogo>();
        return services;
    }
}
