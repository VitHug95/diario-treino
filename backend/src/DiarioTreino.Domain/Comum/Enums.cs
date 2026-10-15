namespace DiarioTreino.Domain.Comum;

/// <summary>
/// Valores de enum guardados como texto no banco (MER: varchar + CHECK).
/// Centralizados para a migration aplicar os mesmos CHECKs e o código evitar
/// strings mágicas.
/// </summary>
public static class Papeis
{
    public const string Atleta = "ATLETA";
    public const string Educador = "EDUCADOR";

    public static readonly IReadOnlyList<string> Todos = [Atleta, Educador];
}

public static class StatusVinculo
{
    public const string Pendente = "PENDENTE";
    public const string Ativo = "ATIVO";
    public const string Encerrado = "ENCERRADO";

    public static readonly IReadOnlyList<string> Todos = [Pendente, Ativo, Encerrado];
}

public static class EixoMetrica
{
    public const string Intensidade = "INTENSIDADE";
    public const string Volume = "VOLUME";

    public static readonly IReadOnlyList<string> Todos = [Intensidade, Volume];
}

public static class Modalidade
{
    public const string Forca = "FORCA";
    public const string Isometria = "ISOMETRIA";
    public const string Cardio = "CARDIO";

    public static readonly IReadOnlyList<string> Todos = [Forca, Isometria, Cardio];
}

public static class TipoEtapa
{
    public const string Esforco = "ESFORCO";
    public const string Recuperacao = "RECUPERACAO";

    public static readonly IReadOnlyList<string> Todos = [Esforco, Recuperacao];
}

/// <summary>
/// Marcador (tag) de uma série — "como" a série foi feita (TV-1). É só
/// identificação: NÃO entra em cálculo (gráfico PBI-20 segue por <c>Tipo</c>).
/// Lista fixa aprovada pelo PO (15/10); tag nova só por migration. <c>Valida</c>
/// é o padrão: rodada sem linha / série sem marcador valem <c>VALIDA</c>.
/// Fonte única do enum: o CHECK da migration e a validação derivam de <see cref="Todos"/>.
/// </summary>
public static class TagSerie
{
    public const string Valida = "VALIDA";
    public const string Aquecimento = "AQUECIMENTO";
    public const string Preparatoria = "PREPARATORIA";
    public const string TopSet = "TOP_SET";
    public const string BackOff = "BACK_OFF";
    public const string Falha = "FALHA";
    public const string DropSet = "DROP_SET";
    public const string RestPause = "REST_PAUSE";
    public const string Negativa = "NEGATIVA";
    public const string Parciais = "PARCIAIS";

    public static readonly IReadOnlyList<string> Todos =
    [
        Valida, Aquecimento, Preparatoria, TopSet, BackOff,
        Falha, DropSet, RestPause, Negativa, Parciais,
    ];

    /// <summary>True quando o código pertence à lista fixa.</summary>
    public static bool EhValido(string? codigo) => codigo is not null && Todos.Contains(codigo);
}

/// <summary>Códigos e ids das métricas de referência (MER 3.4).</summary>
public static class MetricaCodigos
{
    public const short CargaKg = 1;
    public const short PesoCorporal = 2;
    public const short Zona = 3;
    public const short Repeticoes = 10;
    public const short TempoSeg = 11;
    public const short DistanciaM = 12;
}

/// <summary>Ids dos membros de referência (MER 3.4.1 / ADR-10 / PBI-31).</summary>
public static class MembroCodigos
{
    public const short Peito = 1;
    public const short Costas = 2;
    public const short Ombros = 3;
    public const short Bracos = 4;
    public const short Pernas = 5;
    public const short Core = 6;
    public const short Cardio = 7;
    public const short Mobilidade = 8;
}

/// <summary>Ids dos músculos de referência (MER 3.4.2 / PBI-31). Agrupados por
/// membro; os nomes são idênticos aos valores de grupo_muscular do catálogo
/// para a conversão casar por nome.</summary>
public static class MusculoCodigos
{
    public const short Peitoral = 1;
    public const short Dorsal = 2;
    public const short Trapezio = 3;
    public const short Deltoide = 4;
    public const short Biceps = 5;
    public const short Triceps = 6;
    public const short Antebraco = 7;
    public const short Quadriceps = 8;
    public const short PosterioresDeCoxa = 9;
    public const short Gluteos = 10;
    public const short Panturrilha = 11;
    public const short Adutores = 12;
    public const short Abdomen = 13;
    public const short Obliquos = 14;
    public const short Lombar = 15;
}
