namespace DiarioTreino.Domain.Catalogo;

/// <summary>
/// Catálogo de exercícios (MER 3.5). Global (<see cref="CriadoPorId"/> nulo) ou
/// próprio do usuário.
/// </summary>
public class Exercicio
{
    public Guid Id { get; set; }
    public string Nome { get; set; } = null!;

    /// <summary>Membro (região) do exercício. Nulo = ainda não classificado.</summary>
    public short? MembroId { get; set; }

    /// <summary>Músculo opcional, dentro do membro. Nulo = sem detalhe.</summary>
    public short? MusculoId { get; set; }

    public string Modalidade { get; set; } = null!;
    public short IntensidadeMetricaPadraoId { get; set; }
    public short VolumeMetricaPadraoId { get; set; }

    /// <summary>Nulo = catálogo global.</summary>
    public Guid? CriadoPorId { get; set; }
    public bool Ativo { get; set; } = true;

    public Metrica? IntensidadeMetricaPadrao { get; set; }
    public Metrica? VolumeMetricaPadrao { get; set; }
    public Membro? Membro { get; set; }
    public Musculo? Musculo { get; set; }
}
