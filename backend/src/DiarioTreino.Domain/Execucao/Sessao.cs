namespace DiarioTreino.Domain.Execucao;

/// <summary>
/// Um treino realizado em uma data (MER 3.10). A modalidade (musculação, cardio)
/// é derivada dos exercícios das séries, sem coluna própria.
/// </summary>
public class Sessao
{
    public Guid Id { get; set; }
    public Guid AtletaId { get; set; }

    /// <summary>Nulo = sessão montada na hora (sem ficha).</summary>
    public Guid? TreinoId { get; set; }
    public Guid RegistradoPorId { get; set; }

    /// <summary>Data em que o treino aconteceu, não a do lançamento.</summary>
    public DateOnly Data { get; set; }
    public short? DuracaoMin { get; set; }

    /// <summary>Pode conter dado de saúde: não vai para log.</summary>
    public string? Observacao { get; set; }
    public DateTimeOffset CriadoEm { get; set; }
    public DateTimeOffset AtualizadoEm { get; set; }

    public ICollection<SerieExecutada> Series { get; set; } = [];
}
