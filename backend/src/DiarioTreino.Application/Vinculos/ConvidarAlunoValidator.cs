using FluentValidation;

namespace DiarioTreino.Application.Vinculos;

public sealed class ConvidarAlunoValidator : AbstractValidator<ConvidarAlunoRequest>
{
    public ConvidarAlunoValidator()
    {
        RuleFor(x => x.Email)
            .NotEmpty().WithMessage("O e-mail do aluno é obrigatório.")
            .EmailAddress().WithMessage("Informe um e-mail válido.")
            .MaximumLength(254);
    }
}
