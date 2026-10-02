using DiarioTreino.Domain.Catalogo;
using DiarioTreino.Domain.Comum;

namespace DiarioTreino.Infrastructure.Persistencia.Configuracoes;

/// <summary>
/// Catálogo global semeado via migration (PBI-03). GUIDs fixos para o seed ser
/// idempotente entre migrations. Padrões de métrica conforme MER 3.5:
/// força = carga × repetições; isometria = peso corporal × tempo;
/// cardio = zona × tempo.
/// </summary>
internal static class CatalogoGlobalSeed
{
    private static Exercicio Forca(string id, string nome, string grupo) => new()
    {
        Id = Guid.Parse(id),
        Nome = nome,
        GrupoMuscular = grupo,
        Modalidade = Modalidade.Forca,
        IntensidadeMetricaPadraoId = MetricaCodigos.CargaKg,
        VolumeMetricaPadraoId = MetricaCodigos.Repeticoes,
        CriadoPorId = null,
        Ativo = true,
    };

    private static Exercicio Isometria(string id, string nome, string grupo) => new()
    {
        Id = Guid.Parse(id),
        Nome = nome,
        GrupoMuscular = grupo,
        Modalidade = Modalidade.Isometria,
        IntensidadeMetricaPadraoId = MetricaCodigos.PesoCorporal,
        VolumeMetricaPadraoId = MetricaCodigos.TempoSeg,
        CriadoPorId = null,
        Ativo = true,
    };

    private static Exercicio Cardio(string id, string nome) => new()
    {
        Id = Guid.Parse(id),
        Nome = nome,
        GrupoMuscular = null,
        Modalidade = Modalidade.Cardio,
        IntensidadeMetricaPadraoId = MetricaCodigos.Zona,
        VolumeMetricaPadraoId = MetricaCodigos.TempoSeg,
        CriadoPorId = null,
        Ativo = true,
    };

    public static readonly Exercicio[] Exercicios =
    [
        Forca("11111111-0000-0000-0000-000000000001", "Supino reto", "peito"),
        Forca("11111111-0000-0000-0000-000000000002", "Supino inclinado", "peito"),
        Forca("11111111-0000-0000-0000-000000000003", "Crucifixo", "peito"),
        Forca("11111111-0000-0000-0000-000000000004", "Tríceps corda", "tríceps"),
        Forca("11111111-0000-0000-0000-000000000005", "Agachamento livre", "pernas"),
        Forca("11111111-0000-0000-0000-000000000006", "Remada curvada", "costas"),
        Isometria("22222222-0000-0000-0000-000000000001", "Prancha", "core"),
        Isometria("22222222-0000-0000-0000-000000000002", "Agachamento isométrico", "pernas"),
        Cardio("33333333-0000-0000-0000-000000000001", "Corrida"),
        Cardio("33333333-0000-0000-0000-000000000002", "Bicicleta"),
    ];
}
