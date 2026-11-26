using DiarioTreino.Domain.Educador;
using FluentValidation;

namespace DiarioTreino.Application.Educador;

/// <summary>
/// Formato da verificação (PBI-106). Nenhuma mensagem repete o valor digitado, e
/// o CPF inválido é recusado aqui, sem consultar nada.
/// </summary>
public sealed class VerificarCrefValidator : AbstractValidator<VerificarCrefRequest>
{
    public VerificarCrefValidator()
    {
        RuleFor(r => r.Uf)
            .Must(RegistroCref.UfValida)
            .WithMessage("Escolha a UF do seu CREF.");

        RuleFor(r => r.Numero)
            .Must(n => n is not null && n.Trim().Length is >= 1 and <= 12 && n.Trim().All(char.IsAsciiDigit)
                && RegistroCref.Normalizar(n) != "0")
            .WithMessage("Informe o número do CREF, só com números.");

        RuleFor(r => r.Cpf)
            .Must(Cpf.EhValido)
            .WithMessage("Confira o CPF.");
    }
}
