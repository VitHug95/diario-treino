using DiarioTreino.Domain.Corpo;
using FluentValidation;

namespace DiarioTreino.Application.Corpo;

/// <summary>TMB informada (PBI-98): inteiro entre 800 e 5000. A mensagem não repete o valor.</summary>
public sealed class DefinirTmbManualValidator : AbstractValidator<DefinirTmbManualRequest>
{
    public DefinirTmbManualValidator()
    {
        var mensagem = $"Use um valor entre {CalculoTmb.ManualMinimaKcal} e 5.000 kcal.";

        // Regras separadas: um .When no fim de uma cadeia vale para TODAS as regras
        // dela, e desligaria o NotNull junto.
        RuleFor(x => x.Kcal).NotNull().WithMessage(mensagem);

        RuleFor(x => x.Kcal)
            .Must(k => decimal.Truncate(k!.Value) == k.Value)
            .When(x => x.Kcal.HasValue)
            .WithMessage("Use um número inteiro de kcal.");

        RuleFor(x => x.Kcal)
            .Must(k => k!.Value >= CalculoTmb.ManualMinimaKcal && k.Value <= CalculoTmb.ManualMaximaKcal)
            .When(x => x.Kcal.HasValue)
            .WithMessage(mensagem);
    }
}