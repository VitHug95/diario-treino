using DiarioTreino.Domain.Comum;
using FluentValidation;

namespace DiarioTreino.Application.Catalogo;

public sealed class CriarExercicioValidator : AbstractValidator<CriarExercicioRequest>
{
    public CriarExercicioValidator()
    {
        RuleFor(x => x.Nome)
            .NotEmpty().WithMessage("O nome é obrigatório.")
            .MaximumLength(80);

        RuleFor(x => x.GrupoMuscular)
            .MaximumLength(40);

        RuleFor(x => x.Modalidade)
            .NotEmpty()
            .Must(m => Modalidade.Todos.Contains(m.ToUpperInvariant()))
            .WithMessage("Modalidade inválida. Use Força, Isometria ou Cardio.");

        RuleFor(x => x.IntensidadeMetricaId)
            .GreaterThan((short)0).WithMessage("Escolha a métrica de intensidade.");

        RuleFor(x => x.VolumeMetricaId)
            .GreaterThan((short)0).WithMessage("Escolha a métrica de volume.");
    }
}
