using DiarioTreino.Domain.Educador;
using FluentValidation;

namespace DiarioTreino.Application.Educador;

/// <summary>
/// Formato da verificação (PBI-106). Nenhuma mensagem repete o valor digitado, e
/// o CPF inválido é recusado aqui, sem consultar nada.
/// </summary>
/// <summary>
/// Formato do envio declarado (PBI-106, 27/11): UF, número e a permissão. A foto é
/// conferida no serviço (tipo pelo conteúdo e tamanho).
/// </summary>
public sealed class DeclararCrefValidator : AbstractValidator<DeclararCrefRequest>
{
    public DeclararCrefValidator()
    {
        RuleFor(r => r.PermiteUso)
            .Equal(true)
            .WithMessage("Sem a sua permissão, o registro não é guardado e o modo educador não é habilitado.");

        RuleFor(r => r.Uf)
            .Must(RegistroCref.UfValida)
            .WithMessage("Escolha a UF do seu CREF.");

        RuleFor(r => r.Numero)
            .Must(NumeroValido)
            .WithMessage("Informe o número do CREF, só com números.");
    }

    internal static bool NumeroValido(string? n) =>
        n is not null && n.Trim().Length is >= 1 and <= 12 && n.Trim().All(char.IsAsciiDigit)
        && RegistroCref.Normalizar(n) != "0";
}

public sealed class VerificarCrefValidator : AbstractValidator<VerificarCrefRequest>
{
    public VerificarCrefValidator()
    {
        RuleFor(r => r.PermiteConsulta)
            .Equal(true)
            .WithMessage("Sem a sua permissão, o CREF não é consultado e o modo educador não é habilitado.");

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
