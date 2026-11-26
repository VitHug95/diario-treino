using DiarioTreino.Domain.Educador;

namespace DiarioTreino.Application.Educador;

/// <summary>
/// Consulta pública do CREF (PBI-106). **Só** busca Profissional por CPF: não
/// há busca por nome nem por Pessoa Jurídica (regra da PBI-105). Quem
/// implementa não guarda nem loga o CPF, o HTML ou o nome devolvido.
/// </summary>
public interface IConsultaCref
{
    public Task<ResultadoConsultaCref> ConsultarPorCpfAsync(string uf, string cpf, CancellationToken ct);
}

/// <summary>Resposta da consulta, sem o nome da pessoa.</summary>
public abstract record ResultadoConsultaCref
{
    private ResultadoConsultaCref() { }

    /// <summary>Registros devolvidos para o CPF naquela UF (pode haver mais de um).</summary>
    public sealed record Encontrado(IReadOnlyList<RegistroEncontrado> Registros) : ResultadoConsultaCref;

    public sealed record NaoEncontrado : ResultadoConsultaCref;

    /// <summary>Erro, tempo esgotado ou página inesperada. Nunca vira recusa.</summary>
    public sealed record Indisponivel : ResultadoConsultaCref;
}

public sealed record RegistroEncontrado(string Numero, string Situacao, string Categoria);

/// <summary>Resultado da verificação, já decidido.</summary>
public sealed record DecisaoCref(string Resultado, string? Motivo, string? Situacao, RegistroEncontrado? Registro)
{
    /// <summary>
    /// Tabela de decisão da PBI-106: o registro com o número informado (sem
    /// prefixo e sem zeros à esquerda) e situação exatamente ATIVO habilita. A
    /// categoria não restringe (decisão do PO, 26/11).
    /// </summary>
    public static DecisaoCref Decidir(string numeroInformado, ResultadoConsultaCref consulta)
    {
        switch (consulta)
        {
            case ResultadoConsultaCref.Indisponivel:
                return new(ResultadoCref.Indisponivel, null, null, null);
            case ResultadoConsultaCref.Encontrado { Registros.Count: > 0 } encontrado:
                var mesmo = encontrado.Registros.FirstOrDefault(r => RegistroCref.MesmoNumero(r.Numero, numeroInformado));
                if (mesmo is null)
                {
                    return new(ResultadoCref.Recusado, MotivoCref.NumeroNaoConfere, null, null);
                }
                var situacao = mesmo.Situacao.Trim();
                return string.Equals(situacao, RegistroCref.SituacaoAtiva, StringComparison.OrdinalIgnoreCase)
                    ? new(ResultadoCref.Habilitado, null, situacao.ToUpperInvariant(), mesmo)
                    : new(ResultadoCref.Recusado, MotivoCref.SituacaoNaoAtiva, situacao, mesmo);
            default:
                return new(ResultadoCref.NaoEncontrado, null, null, null);
        }
    }
}

/// <summary>
/// Chave da PBI-106 (<c>Educador:ExigirCref</c>). Desligada, tudo funciona como
/// antes (a rota antiga ativa o modo educador e não há trava). Fica desligada em
/// produção até o leitor do site real do CREF existir: ligada sem ele, ninguém
/// novo conseguiria se habilitar.
/// </summary>
public sealed record ConfiguracaoEducador(bool ExigirCref);
