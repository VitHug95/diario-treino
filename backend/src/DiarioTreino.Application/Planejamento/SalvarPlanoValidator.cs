using FluentValidation;

namespace DiarioTreino.Application.Planejamento;

public sealed class SalvarPlanoValidator : AbstractValidator<SalvarPlanoRequest>
{
    public SalvarPlanoValidator()
    {
        RuleFor(x => x.Nome)
            .NotEmpty().WithMessage("O nome do plano é obrigatório.")
            .MaximumLength(80);
    }
}
