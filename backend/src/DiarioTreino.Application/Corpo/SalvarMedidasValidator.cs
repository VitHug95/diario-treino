using DiarioTreino.Domain.Corpo;
using FluentValidation;
using FluentValidation.Results;

namespace DiarioTreino.Application.Corpo;

public sealed class SalvarMedidasValidator : AbstractValidator<SalvarMedidasEntrada>
{
    public SalvarMedidasValidator()
    {
        // Sem a tolerância de "amanhã" do registro de treino: medida é do que já aconteceu.
        RuleFor(x => x.Data)
            .Must(data => data <= DateOnly.FromDateTime(DateTime.UtcNow))
            .WithMessage("A data da medição não pode ser no futuro.");

        RuleFor(x => x.Valores)
            .NotNull().WithMessage("Informe ao menos uma medida.")
            .Must(v => v is null || v.Count > 0).WithMessage("Informe ao menos uma medida.");

        // Cada erro vai na chave do próprio tipo, para o app mostrar no campo.
        // O valor digitado nunca entra na mensagem (dado de saúde).
        RuleFor(x => x.Valores).Custom((valores, contexto) =>
        {
            if (valores is null)
            {
                return;
            }

            foreach (var (tipo, valor) in valores)
            {
                if (!TipoMedida.EhValido(tipo))
                {
                    contexto.AddFailure(new ValidationFailure("valores", "Tipo de medida inválido."));
                    continue;
                }

                if (valor is null)
                {
                    continue; // remove o tipo do dia
                }

                var (minimo, maximo) = TipoMedida.Faixa(tipo);
                if (valor < minimo || valor > maximo)
                {
                    contexto.AddFailure(new ValidationFailure(
                        tipo,
                        $"O valor deve ficar entre {Formatar(minimo)} e {Formatar(maximo)} {TipoMedida.Unidade(tipo)}."));
                }
                else if (decimal.Round(valor.Value, 1) != valor.Value)
                {
                    contexto.AddFailure(new ValidationFailure(tipo, "Use no máximo uma casa decimal."));
                }
            }
        });
    }

    private static string Formatar(decimal valor) =>
        valor.ToString("0.#", System.Globalization.CultureInfo.GetCultureInfo("pt-BR"));
}
