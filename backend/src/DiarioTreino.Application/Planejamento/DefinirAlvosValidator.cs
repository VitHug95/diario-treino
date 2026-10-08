using FluentValidation;

namespace DiarioTreino.Application.Planejamento;

public sealed class DefinirAlvosValidator : AbstractValidator<DefinirAlvosRequest>
{
    public DefinirAlvosValidator()
    {
        RuleFor(x => x.Series)
            .InclusiveBetween((short)1, (short)12)
            .WithMessage("As séries devem ficar entre 1 e 12.");

        RuleFor(x => x.IntensidadeMetricaId)
            .GreaterThan((short)0).WithMessage("Escolha a métrica de intensidade.");

        RuleFor(x => x.VolumeMetricaId)
            .GreaterThan((short)0).WithMessage("Escolha a métrica de volume.");

        RuleFor(x => x.IntensidadeAlvo)
            .GreaterThanOrEqualTo(0).When(x => x.IntensidadeAlvo.HasValue)
            .WithMessage("O alvo de intensidade não pode ser negativo.");

        RuleFor(x => x.VolumeAlvo)
            .GreaterThanOrEqualTo(0).When(x => x.VolumeAlvo.HasValue)
            .WithMessage("O alvo de volume não pode ser negativo.");

        RuleFor(x => x.DescansoSeg)
            .GreaterThanOrEqualTo((short)0).When(x => x.DescansoSeg.HasValue);

        RuleFor(x => x.Instrucao).MaximumLength(200);
    }
}
