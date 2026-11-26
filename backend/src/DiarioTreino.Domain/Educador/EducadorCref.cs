namespace DiarioTreino.Domain.Educador;

/// <summary>
/// Evidência de que o usuário foi habilitado como educador (PBI-106, MER 3.16).
/// Só existe para quem foi habilitado: pela consulta do CREF (AUTOMATICA) ou
/// por script, sem consulta (LEGADO). Nunca guarda CPF nem nome.
/// </summary>
public class EducadorCref
{
    public Guid UsuarioId { get; set; }

    /// <summary>UF do registro. Nula só no LEGADO.</summary>
    public string? Uf { get; set; }

    /// <summary>Número normalizado (só dígitos, sem zeros à esquerda). Nulo só no LEGADO.</summary>
    public string? Numero { get; set; }

    /// <summary>Situação devolvida pelo CREF na consulta. Nula só no LEGADO.</summary>
    public string? Situacao { get; set; }

    /// <summary>Categoria devolvida pelo CREF (guardada, não restringe). Nula só no LEGADO.</summary>
    public string? Categoria { get; set; }

    /// <summary><see cref="OrigemCref.Automatica"/> ou <see cref="OrigemCref.Legado"/>.</summary>
    public string Origem { get; set; } = null!;

    /// <summary>Quando a consulta foi feita. Nulo só no LEGADO.</summary>
    public DateTimeOffset? ConsultadoEm { get; set; }
}

/// <summary>Uma tentativa de verificação, só para o limite de 5 em 24 h. Sem CPF, número ou nome.</summary>
public class TentativaCref
{
    public Guid Id { get; set; }
    public Guid UsuarioId { get; set; }
    public DateTimeOffset Em { get; set; }
    public string Resultado { get; set; } = null!;
}

public static class OrigemCref
{
    public const string Automatica = "AUTOMATICA";
    public const string Legado = "LEGADO";
}

/// <summary>Resultados da verificação (PBI-106).</summary>
public static class ResultadoCref
{
    public const string Habilitado = "HABILITADO";
    public const string Recusado = "RECUSADO";
    public const string NaoEncontrado = "NAO_ENCONTRADO";
    public const string Indisponivel = "INDISPONIVEL";

    public static readonly IReadOnlyList<string> Todos = [Habilitado, Recusado, NaoEncontrado, Indisponivel];
}

/// <summary>Motivos de RECUSADO e de INDISPONIVEL.</summary>
public static class MotivoCref
{
    public const string SituacaoNaoAtiva = "SITUACAO_NAO_ATIVA";
    public const string NumeroNaoConfere = "NUMERO_NAO_CONFERE";
    public const string UfSemConsulta = "UF_SEM_CONSULTA";
}
