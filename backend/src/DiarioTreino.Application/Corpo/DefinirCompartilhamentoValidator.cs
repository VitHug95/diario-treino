using FluentValidation;

namespace DiarioTreino.Application.Corpo;

/// <summary>
/// Os dois cadeados vêm sempre (PBI-95): um campo ausente não pode virar
/// "trancar" sem querer.
/// </summary>
public sealed class DefinirCompartilhamentoValidator : AbstractValidator<DefinirCompartilhamentoRequest>
{
    public DefinirCompartilhamentoValidator()
    {
        RuleFor(x => x.DadosCorporais)
            .NotNull().WithMessage("Informe se os dados corporais ficam compartilhados.");
        RuleFor(x => x.Medidas)
            .NotNull().WithMessage("Informe se as medidas ficam compartilhadas.");
    }
}
