namespace DiarioTreino.Domain.Catalogo;

/// <summary>
/// Catálogo de exercícios (MER 3.5). Global (<see cref="CriadoPorId"/> nulo) ou
/// próprio do usuário.
/// </summary>
public class Exercicio
{
    public Guid Id { get; set; }
    public string Nome { get; set; } = null!;

    /// <summary>
    /// Texto livre legado (ADR-10 / PBI-31). Mantido na etapa 1 enquanto
    /// <see cref="MembroId"/>/<see cref="MusculoId"/> convivem com ele; removido
    /// na etapa 4, depois que API e front já usam o membro.
    /// </summary>
    public string? GrupoMuscular { get; set; }

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
