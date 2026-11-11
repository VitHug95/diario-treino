using DiarioTreino.Domain.Corpo;
using FluentValidation;
using FluentValidation.Results;

namespace DiarioTreino.Application.Corpo;

public sealed class SalvarPerfilCorporalValidator : AbstractValidator<SalvarPerfilCorporalRequest>
{
    public const int AlturaMinimaCm = 100;
    public const int AlturaMaximaCm = 250;
    public const int IdadeMinimaAnos = 10;
    public const int IdadeMaximaAnos = 100;

    public SalvarPerfilCorporalValidator()
    {
        // As mensagens nunca repetem o valor digitado (dado de saúde).
        RuleFor(x => x.Sexo)
            .Must(SexoBiologico.EhValido).When(x => x.Sexo is not null)
            .WithMessage("Sexo deve ser M ou F.");

        RuleFor(x => x.AlturaCm)
            .InclusiveBetween((short)AlturaMinimaCm, (short)AlturaMaximaCm)
            .When(x => x.AlturaCm.HasValue)
            .WithMessage($"A altura deve ficar entre {AlturaMinimaCm} e {AlturaMaximaCm} cm.");

        RuleFor(x => x.DataNascimento)
            .Custom((nascimento, contexto) =>
            {
                if (nascimento is null)
                {
                    return;
                }

                var hoje = DateOnly.FromDateTime(DateTime.UtcNow);
                if (nascimento.Value >= hoje)
                {
                    contexto.AddFailure(new ValidationFailure(nameof(SalvarPerfilCorporalRequest.DataNascimento), "A data de nascimento deve estar no passado."));
                    return;
                }

                var idade = CalculoTmb.IdadeEm(nascimento.Value, hoje);
                if (idade < IdadeMinimaAnos || idade > IdadeMaximaAnos)
                {
                    contexto.AddFailure(new ValidationFailure(
                        nameof(SalvarPerfilCorporalRequest.DataNascimento),
                        $"A idade deve ficar entre {IdadeMinimaAnos} e {IdadeMaximaAnos} anos."));
                }
            });

        var (pesoMinimo, pesoMaximo) = TipoMedida.Faixa(TipoMedida.Peso);
        RuleFor(x => x.PesoKg)
            .InclusiveBetween(pesoMinimo, pesoMaximo).When(x => x.PesoKg.HasValue)
            .WithMessage($"O peso deve ficar entre {pesoMinimo:0} e {pesoMaximo:0} kg.");
        RuleFor(x => x.PesoKg)
            .Must(p => decimal.Round(p!.Value, 1) == p.Value)
            .When(x => x.PesoKg.HasValue)
            .WithMessage("Use no máximo uma casa decimal no peso.");

        // O dia do peso segue a regra das medidas: não pode ser futuro.
        RuleFor(x => x.DataPeso)
            .Must(d => d!.Value <= DateOnly.FromDateTime(DateTime.UtcNow))
            .When(x => x.DataPeso.HasValue)
            .WithMessage("A data do peso não pode ser no futuro.");
    }
}
