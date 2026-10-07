using FluentValidation;

namespace DiarioTreino.Application.Planejamento;

public sealed class SalvarTreinoValidator : AbstractValidator<SalvarTreinoRequest>
{
    public SalvarTreinoValidator()
    {
        RuleFor(x => x.Nome)
            .NotEmpty().WithMessage("O nome da ficha é obrigatório.")
            .MaximumLength(40);

        RuleFor(x => x.Descricao)
            .MaximumLength(80);
    }
}
