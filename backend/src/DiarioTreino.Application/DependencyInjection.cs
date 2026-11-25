using DiarioTreino.Application.Acesso;
using DiarioTreino.Application.Catalogo;
using DiarioTreino.Application.Corpo;
using DiarioTreino.Application.Execucao;
using DiarioTreino.Application.Identidade;
using DiarioTreino.Application.Planejamento;
using DiarioTreino.Application.Progresso;
using DiarioTreino.Application.Relatorios;
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
        services.AddScoped<ServicoRelatorio>();
        services.AddScoped<ServicoMedidas>();
        services.AddScoped<ServicoPerfilCorporal>();
        services.AddScoped<ServicoCompartilhamentoCorporal>();
        services.AddScoped<IValidator<DefinirCompartilhamentoRequest>, DefinirCompartilhamentoValidator>();

        services.AddScoped<IValidator<CriarExercicioRequest>, CriarExercicioValidator>();
        services.AddScoped<IValidator<SalvarTreinoRequest>, SalvarTreinoValidator>();
        services.AddScoped<IValidator<SalvarPlanoRequest>, SalvarPlanoValidator>();
        services.AddScoped<IValidator<DefinirSemanaRequest>, DefinirSemanaValidator>();
        services.AddScoped<IValidator<CriarFichaDeTreinoRequest>, CriarFichaDeTreinoValidator>();
        services.AddScoped<IValidator<DefinirAlvosRequest>, DefinirAlvosValidator>();
        services.AddScoped<IValidator<CriarBlocoRequest>, CriarBlocoValidator>();
        services.AddScoped<IValidator<DescansoBlocoRequest>, DescansoBlocoValidator>();
        services.AddScoped<IValidator<MembrosBlocoRequest>, MembrosBlocoValidator>();
        services.AddScoped<IValidator<CriarSessaoRequest>, CriarSessaoValidator>();
        services.AddScoped<IValidator<ConvidarAlunoRequest>, ConvidarAlunoValidator>();
        services.AddScoped<IValidator<SalvarMedidasEntrada>, SalvarMedidasValidator>();
        services.AddScoped<IValidator<SalvarPerfilCorporalRequest>, SalvarPerfilCorporalValidator>();
        services.AddScoped<IValidator<DefinirTmbManualRequest>, DefinirTmbManualValidator>();

        return services;
    }
}
