using DiarioTreino.Domain.Planejamento;
using FluentValidation;

namespace DiarioTreino.Application.Planejamento;

/// <summary>Juntar exercícios num bloco (PBI-101): 2 a 4, sem repetir, descanso 0 a 600 s.</summary>
public sealed class CriarBlocoValidator : AbstractValidator<CriarBlocoRequest>
{
    public CriarBlocoValidator()
    {
        RuleFor(x => x.TreinoExercicioIds)
            .NotNull().WithMessage("Informe os exercícios do bloco.");

        RuleFor(x => x.TreinoExercicioIds)
            .Must(ids => ids.Count >= RegrasBloco.MinimoMembros && ids.Count <= RegrasBloco.MaximoMembros)
            .WithMessage($"Um bloco tem de {RegrasBloco.MinimoMembros} a {RegrasBloco.MaximoMembros} exercícios.")
            .When(x => x.TreinoExercicioIds is not null);

        RuleFor(x => x.TreinoExercicioIds)
            .Must(ids => ids.Distinct().Count() == ids.Count)
            .WithMessage("O mesmo exercício não pode entrar duas vezes no bloco.")
            .When(x => x.TreinoExercicioIds is not null);

        RuleFor(x => x.DescansoSeg)
            .InclusiveBetween((short)0, RegrasBloco.DescansoMaximoSeg)
            .WithMessage($"O descanso vai de 0 a {RegrasBloco.DescansoMaximoSeg} segundos.")
            .When(x => x.DescansoSeg.HasValue);
    }
}

/// <summary>Descanso do bloco (PBI-101): nulo ou 0 a 600 s.</summary>
public sealed class DescansoBlocoValidator : AbstractValidator<DescansoBlocoRequest>
{
    public DescansoBlocoValidator()
    {
        RuleFor(x => x.DescansoSeg)
            .InclusiveBetween((short)0, RegrasBloco.DescansoMaximoSeg)
            .WithMessage($"O descanso vai de 0 a {RegrasBloco.DescansoMaximoSeg} segundos.")
            .When(x => x.DescansoSeg.HasValue);
    }
}

/// <summary>Membros do bloco (PBI-101): até 4, sem repetir. Menos de 2 desfaz o bloco.</summary>
public sealed class MembrosBlocoValidator : AbstractValidator<MembrosBlocoRequest>
{
    public MembrosBlocoValidator()
    {
        RuleFor(x => x.TreinoExercicioIds)
            .NotNull().WithMessage("Informe os exercícios do bloco.");

        RuleFor(x => x.TreinoExercicioIds)
            .Must(ids => ids.Count <= RegrasBloco.MaximoMembros)
            .WithMessage($"Um bloco tem no máximo {RegrasBloco.MaximoMembros} exercícios.")
            .When(x => x.TreinoExercicioIds is not null);

        RuleFor(x => x.TreinoExercicioIds)
            .Must(ids => ids.Distinct().Count() == ids.Count)
            .WithMessage("O mesmo exercício não pode entrar duas vezes no bloco.")
            .When(x => x.TreinoExercicioIds is not null);
    }
}
