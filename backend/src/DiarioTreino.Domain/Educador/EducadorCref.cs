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

    /// <summary>Quando a consulta foi feita (só AUTOMATICA).</summary>
    public DateTimeOffset? ConsultadoEm { get; set; }

    /// <summary>Quando o educador enviou número, UF e foto (só DECLARADA).</summary>
    public DateTimeOffset? DeclaradoEm { get; set; }
}

/// <summary>
/// Foto da carteira do CREF enviada na habilitação DECLARADA (PBI-106). Fica
/// numa tabela própria para a leitura do registro não carregar a imagem.
/// Ninguém vê pelo app: o PO confere por script. Some com o registro e com a conta.
/// </summary>
public class FotoCarteiraCref
{
    public Guid UsuarioId { get; set; }
    public byte[] Conteudo { get; set; } = null!;
    public string TipoConteudo { get; set; } = null!;
    public DateTimeOffset EnviadaEm { get; set; }

    public const int TamanhoMaximo = 5 * 1024 * 1024;
    public const string Jpeg = "image/jpeg";
    public const string Png = "image/png";

    /// <summary>
    /// Tipo pelo conteúdo (assinatura do arquivo), não pelo que o navegador diz:
    /// JPEG começa com FF D8 FF, PNG com 89 50 4E 47 0D 0A 1A 0A. Nulo se não for nenhum.
    /// </summary>
    public static string? TipoPelaAssinatura(ReadOnlySpan<byte> inicio)
    {
        if (inicio.Length >= 3 && inicio[0] == 0xFF && inicio[1] == 0xD8 && inicio[2] == 0xFF)
        {
            return Jpeg;
        }
        ReadOnlySpan<byte> png = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
        return inicio.Length >= png.Length && inicio[..png.Length].SequenceEqual(png) ? Png : null;
    }
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

    /// <summary>Número e UF informados com a foto da carteira, sem consulta (PBI-106, 27/11).</summary>
    public const string Declarada = "DECLARADA";
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
