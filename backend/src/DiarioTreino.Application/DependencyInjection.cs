using DiarioTreino.Application.Acesso;
using DiarioTreino.Application.Catalogo;
using DiarioTreino.Application.Execucao;
using DiarioTreino.Application.Identidade;
using DiarioTreino.Application.Planejamento;
using DiarioTreino.Application.Progresso;
using DiarioTreino.Application.Vinculos;
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
        services.AddScoped<ServicoProgresso>();
        services.AddScoped<ServicoVinculo>();

        services.AddScoped<IValidator<CriarExercicioRequest>, CriarExercicioValidator>();
        services.AddScoped<IValidator<SalvarTreinoRequest>, SalvarTreinoValidator>();
        services.AddScoped<IValidator<SalvarPlanoRequest>, SalvarPlanoValidator>();
        services.AddScoped<IValidator<CriarFichaDeTreinoRequest>, CriarFichaDeTreinoValidator>();
        services.AddScoped<IValidator<DefinirAlvosRequest>, DefinirAlvosValidator>();
        services.AddScoped<IValidator<CriarSessaoRequest>, CriarSessaoValidator>();
        services.AddScoped<IValidator<ConvidarAlunoRequest>, ConvidarAlunoValidator>();

        return services;
    }
}
