using FluentValidation;

namespace DiarioTreino.Application.Planejamento;

/// <summary>
/// Validação do "Salvar também como ficha" (PBI-19). Nome segue a mesma regra
/// de uma ficha normal; a lista de exercícios não pode vir vazia.
/// </summary>
public sealed class CriarFichaDeTreinoValidator : AbstractValidator<CriarFichaDeTreinoRequest>
{
    public CriarFichaDeTreinoValidator()
    {
        RuleFor(x => x.Nome)
            .NotEmpty().WithMessage("O nome da ficha é obrigatório.")
            .MaximumLength(40);

        RuleFor(x => x.Descricao)
            .MaximumLength(80);

        RuleFor(x => x.ExercicioIds)
            .NotEmpty().WithMessage("Inclua ao menos um exercício na ficha.");
    }
}
