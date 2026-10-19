using DiarioTreino.Domain.Comum;
using FluentValidation;

namespace DiarioTreino.Application.Execucao;

public sealed class CriarSessaoValidator : AbstractValidator<CriarSessaoRequest>
{
    public CriarSessaoValidator()
    {
        // A data do treino não pode ser futura além de amanhã (igual ao CHECK
        // ck_sessao_data no banco). Aceita datas passadas (registro dias depois).
        RuleFor(x => x.Data)
            .Must(data => data <= DateOnly.FromDateTime(DateTime.UtcNow.Date).AddDays(1))
            .WithMessage("A data do treino não pode ser no futuro.");

        RuleFor(x => x.DuracaoMin)
            .GreaterThan((short)0).When(x => x.DuracaoMin.HasValue)
            .WithMessage("A duração deve ser maior que zero.");

        RuleFor(x => x.Observacao).MaximumLength(2000);

        RuleForEach(x => x.Exercicios).SetValidator(new ExercicioSessaoValidator());

        // PBI-74: cada exercício aparece uma única vez por sessão (consequência
        // de "uma vez por ficha"). Dois blocos com o mesmo ExercicioId são
        // recusados antes de gravar.
        RuleFor(x => x.Exercicios)
            .Must(ex => ex.Select(e => e.ExercicioId).Distinct().Count() == ex.Count)
            .When(x => x.Exercicios is not null)
            .WithMessage("Este exercício já está no treino.");

        // PBI-72: manter na ficha só faz sentido com ficha; o resto (id na
        // sessão, fora da ficha, com série) é conferido no serviço.
        RuleFor(x => x.ManterNaFicha)
            .Must(ids => ids!.Count <= 50)
            .When(x => x.ManterNaFicha is { Count: > 0 })
            .WithMessage("Exercícios demais para manter na ficha.");
        RuleForEach(x => x.ManterNaFicha)
            .NotEmpty().WithMessage("Exercício inválido para manter na ficha.");
        RuleFor(x => x.TreinoId)
            .NotNull().When(x => x.ManterNaFicha is { Count: > 0 })
            .WithMessage("Treino livre não tem ficha para manter o exercício.");
    }
}

public sealed class ExercicioSessaoValidator : AbstractValidator<ExercicioSessaoRequest>
{
    public ExercicioSessaoValidator()
    {
        RuleFor(x => x.ExercicioId).NotEmpty().WithMessage("Exercício inválido.");
        RuleForEach(x => x.Series).SetValidator(new SerieValidator());
    }
}

public sealed class SerieValidator : AbstractValidator<SerieRequest>
{
    public SerieValidator()
    {
        RuleFor(x => x.Tipo)
            .Must(t => TipoEtapa.Todos.Contains(t))
            .WithMessage("Tipo de série inválido.");

        RuleFor(x => x.Rodada).GreaterThan((short)0);
        RuleFor(x => x.Ordem).GreaterThan((short)0);

        RuleFor(x => x.IntensidadeMetricaId)
            .GreaterThan((short)0).WithMessage("Métrica de intensidade inválida.");

        RuleFor(x => x.VolumeMetricaId)
            .GreaterThan((short)0).WithMessage("Métrica de volume inválida.");

        RuleFor(x => x.Intensidade)
            .GreaterThanOrEqualTo(0).When(x => x.Intensidade.HasValue)
            .WithMessage("A intensidade não pode ser negativa.");

        RuleFor(x => x.Volume)
            .GreaterThanOrEqualTo(0).WithMessage("O volume não pode ser negativo.");

        RuleFor(x => x.DescansoSeg)
            .GreaterThanOrEqualTo((short)0).When(x => x.DescansoSeg.HasValue);

        // Tag da série (TV-1): nula vale VALIDA; se vier, tem de estar na lista.
        RuleFor(x => x.Marcador)
            .Must(TagSerie.EhValido).When(x => x.Marcador is not null)
            .WithMessage("Tag de série inválida.");
    }
}
