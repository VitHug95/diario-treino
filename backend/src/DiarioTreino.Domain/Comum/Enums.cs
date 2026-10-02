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
