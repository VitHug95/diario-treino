using DiarioTreino.Application.Acesso;
using DiarioTreino.Application.Catalogo;
using DiarioTreino.Application.Execucao;
using DiarioTreino.Application.Identidade;
using DiarioTreino.Application.Planejamento;
using FluentValidation;
using Microsoft.Extensions.DependencyInjection;

namespace DiarioTreino.Application;

public static class DependencyInjection
{
    public static IServiceCollection AddApplication(this IServiceCollection services)
    {
        services.AddScoped<ServicoPerfil>();
        services.AddScoped<IControleAcesso, ControleAcesso>();
        services.AddScoped<ServicoCatalogo>();
        services.AddScoped<ServicoPlanejamento>();
        services.AddScoped<ServicoSessao>();

        services.AddScoped<IValidator<CriarExercicioRequest>, CriarExercicioValidator>();
        services.AddScoped<IValidator<SalvarTreinoRequest>, SalvarTreinoValidator>();
        services.AddScoped<IValidator<DefinirAlvosRequest>, DefinirAlvosValidator>();
        services.AddScoped<IValidator<CriarSessaoRequest>, CriarSessaoValidator>();

        return services;
    }
}
