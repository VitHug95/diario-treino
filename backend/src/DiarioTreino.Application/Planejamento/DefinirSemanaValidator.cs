using FluentValidation;

namespace DiarioTreino.Application.Planejamento;

/// <summary>
/// Formato da semana planejada (PBI-35): dia ISO 1..7, no máximo uma ficha por
/// dia e ficha informada. Se a ficha é deste plano é conferido no serviço.
/// </summary>
public sealed class DefinirSemanaValidator : AbstractValidator<DefinirSemanaRequest>
{
    public DefinirSemanaValidator()
    {
        RuleFor(x => x.Dias)
            .NotNull().WithMessage("Informe os dias da semana (lista vazia limpa a semana).");

        RuleForEach(x => x.Dias).ChildRules(dia =>
        {
            dia.RuleFor(d => d.DiaSemana)
                .InclusiveBetween((short)1, (short)7)
                .WithMessage("O dia da semana vai de 1 (segunda) a 7 (domingo).");
            dia.RuleFor(d => d.TreinoId)
                .NotEmpty().WithMessage("Informe a ficha do dia.");
        });

        RuleFor(x => x.Dias)
            .Must(dias => dias.Select(d => d.DiaSemana).Distinct().Count() == dias.Count)
            .When(x => x.Dias is not null)
            .WithMessage("Cada dia da semana pode ter no máximo uma ficha.");
    }
}
