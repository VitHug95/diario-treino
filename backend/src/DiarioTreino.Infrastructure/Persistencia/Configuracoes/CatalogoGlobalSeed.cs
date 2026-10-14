using DiarioTreino.Domain.Catalogo;
using DiarioTreino.Domain.Comum;

namespace DiarioTreino.Infrastructure.Persistencia.Configuracoes;

/// <summary>
/// Catálogo global semeado via migration (PBI-03). GUIDs fixos para o seed ser
/// idempotente entre migrations. A "forma de medir" vira o par de métricas
/// padrão (MER 3.5):
/// <list type="bullet">
/// <item>CR = carga × repetições (Força);</item>
/// <item>PR = peso corporal × repetições (Força);</item>
/// <item>PT = peso corporal × tempo (Isometria);</item>
/// <item>ZT = zona × tempo (Cardio).</item>
/// </list>
/// Três GUIDs são preservados do seed original porque os testes de integração
/// dependem deles: 1111…0001 (Supino reto com barra, força carga×reps),
/// 1111…0005 (Agachamento livre, força) e 2222…0001 (Prancha, isometria).
/// </summary>
internal static class CatalogoGlobalSeed
{
    /// <summary>
    /// Mapeia o nome do músculo (valor de grupo_muscular) para o par
    /// (musculoId, membroId). Nulo = sem músculo mapeado (ex.: "Levantamento
    /// terra"). PBI-31: o membro vem do músculo.
    /// </summary>
    private static (short MusculoId, short MembroId)? MusculoDoGrupo(string? grupo) => grupo switch
    {
        "Peitoral" => (MusculoCodigos.Peitoral, MembroCodigos.Peito),
        "Dorsal" => (MusculoCodigos.Dorsal, MembroCodigos.Costas),
        "Trapézio" => (MusculoCodigos.Trapezio, MembroCodigos.Costas),
        "Deltoide" => (MusculoCodigos.Deltoide, MembroCodigos.Ombros),
        "Bíceps" => (MusculoCodigos.Biceps, MembroCodigos.Bracos),
        "Tríceps" => (MusculoCodigos.Triceps, MembroCodigos.Bracos),
        "Antebraço" => (MusculoCodigos.Antebraco, MembroCodigos.Bracos),
        "Quadríceps" => (MusculoCodigos.Quadriceps, MembroCodigos.Pernas),
        "Posteriores de coxa" => (MusculoCodigos.PosterioresDeCoxa, MembroCodigos.Pernas),
        "Glúteos" => (MusculoCodigos.Gluteos, MembroCodigos.Pernas),
        "Panturrilha" => (MusculoCodigos.Panturrilha, MembroCodigos.Pernas),
        "Adutores" => (MusculoCodigos.Adutores, MembroCodigos.Pernas),
        "Abdômen" => (MusculoCodigos.Abdomen, MembroCodigos.Core),
        "Oblíquos" => (MusculoCodigos.Obliquos, MembroCodigos.Core),
        "Lombar" => (MusculoCodigos.Lombar, MembroCodigos.Core),
        _ => null,
    };

    // CR: carga × repetições (Força). Membro/músculo vêm do grupo.
    private static Exercicio Cr(string id, string nome, string? grupo)
    {
        var m = MusculoDoGrupo(grupo);
        return new()
        {
            Id = Guid.Parse(id),
            Nome = nome,
            GrupoMuscular = grupo,
            MembroId = m?.MembroId,
            MusculoId = m?.MusculoId,
            Modalidade = Modalidade.Forca,
            IntensidadeMetricaPadraoId = MetricaCodigos.CargaKg,
            VolumeMetricaPadraoId = MetricaCodigos.Repeticoes,
            CriadoPorId = null,
            Ativo = true,
        };
    }

    // PR: peso corporal × repetições (Força) — ex.: flexão, barra fixa.
    private static Exercicio Pr(string id, string nome, string? grupo)
    {
        var m = MusculoDoGrupo(grupo);
        return new()
        {
            Id = Guid.Parse(id),
            Nome = nome,
            GrupoMuscular = grupo,
            MembroId = m?.MembroId,
            MusculoId = m?.MusculoId,
            Modalidade = Modalidade.Forca,
            IntensidadeMetricaPadraoId = MetricaCodigos.PesoCorporal,
            VolumeMetricaPadraoId = MetricaCodigos.Repeticoes,
            CriadoPorId = null,
            Ativo = true,
        };
    }

    // PT: peso corporal × tempo (Isometria). Com músculo (ex.: core) ou, sem
    // grupo (mobilidade), vai para o membro Mobilidade sem músculo.
    private static Exercicio Pt(string id, string nome, string? grupo)
    {
        var m = MusculoDoGrupo(grupo);
        return new()
        {
            Id = Guid.Parse(id),
            Nome = nome,
            GrupoMuscular = grupo,
            MembroId = m?.MembroId ?? MembroCodigos.Mobilidade,
            MusculoId = m?.MusculoId,
            Modalidade = Modalidade.Isometria,
            IntensidadeMetricaPadraoId = MetricaCodigos.PesoCorporal,
            VolumeMetricaPadraoId = MetricaCodigos.TempoSeg,
            CriadoPorId = null,
            Ativo = true,
        };
    }

    // ZT: zona × tempo (Cardio). Sempre no membro Cardio, sem músculo.
    private static Exercicio Zt(string id, string nome) => new()
    {
        Id = Guid.Parse(id),
        Nome = nome,
        GrupoMuscular = null,
        MembroId = MembroCodigos.Cardio,
        MusculoId = null,
        Modalidade = Modalidade.Cardio,
        IntensidadeMetricaPadraoId = MetricaCodigos.Zona,
        VolumeMetricaPadraoId = MetricaCodigos.TempoSeg,
        CriadoPorId = null,
        Ativo = true,
    };

    // Exercício global aposentado: continua no banco como inativo (ativo=false)
    // para não quebrar fichas/sessões antigas que já o referenciam (FK Restrict
    // em treino_exercicio e serie_executada; regra de dados: nada é apagado
    // fisicamente quando há histórico ligado). Some do catálogo (filtro Ativo).
    private static Exercicio Aposentado(
        string id, string nome, string? grupo, string modalidade,
        short intensidade, short volume) => new()
    {
        Id = Guid.Parse(id),
        Nome = nome,
        GrupoMuscular = grupo,
        Modalidade = modalidade,
        IntensidadeMetricaPadraoId = intensidade,
        VolumeMetricaPadraoId = volume,
        CriadoPorId = null,
        Ativo = false,
    };

    public static readonly Exercicio[] Exercicios =
    [
        // ───────── Genéricos do seed original, aposentados ─────────
        // Substituídos por versões mais específicas (ex.: "Supino inclinado"
        // virou "...com barra" / "...com halteres"). Mantidos inativos.
        Aposentado("11111111-0000-0000-0000-000000000002", "Supino inclinado", "peito", Modalidade.Forca, MetricaCodigos.CargaKg, MetricaCodigos.Repeticoes),
        Aposentado("11111111-0000-0000-0000-000000000003", "Crucifixo", "peito", Modalidade.Forca, MetricaCodigos.CargaKg, MetricaCodigos.Repeticoes),
        Aposentado("11111111-0000-0000-0000-000000000004", "Tríceps corda (antigo)", "tríceps", Modalidade.Forca, MetricaCodigos.CargaKg, MetricaCodigos.Repeticoes),
        Aposentado("11111111-0000-0000-0000-000000000006", "Remada curvada", "costas", Modalidade.Forca, MetricaCodigos.CargaKg, MetricaCodigos.Repeticoes),
        Aposentado("22222222-0000-0000-0000-000000000002", "Agachamento isométrico", "pernas", Modalidade.Isometria, MetricaCodigos.PesoCorporal, MetricaCodigos.TempoSeg),
        Aposentado("33333333-0000-0000-0000-000000000001", "Corrida (antigo)", null, Modalidade.Cardio, MetricaCodigos.Zona, MetricaCodigos.TempoSeg),
        Aposentado("33333333-0000-0000-0000-000000000002", "Bicicleta", null, Modalidade.Cardio, MetricaCodigos.Zona, MetricaCodigos.TempoSeg),

        // ───────── Peito (Peitoral) ─────────
        Cr("11111111-0000-0000-0000-000000000001", "Supino reto com barra", "Peitoral"),
        Cr("11111111-0000-0000-0000-000000000011", "Supino reto com halteres", "Peitoral"),
        Cr("11111111-0000-0000-0000-000000000012", "Supino inclinado com barra", "Peitoral"),
        Cr("11111111-0000-0000-0000-000000000013", "Supino inclinado com halteres", "Peitoral"),
        Cr("11111111-0000-0000-0000-000000000014", "Supino declinado", "Peitoral"),
        Cr("11111111-0000-0000-0000-000000000015", "Supino na máquina", "Peitoral"),
        Cr("11111111-0000-0000-0000-000000000016", "Crucifixo reto com halteres", "Peitoral"),
        Cr("11111111-0000-0000-0000-000000000017", "Crucifixo inclinado", "Peitoral"),
        Cr("11111111-0000-0000-0000-000000000018", "Peck deck", "Peitoral"),
        Cr("11111111-0000-0000-0000-000000000019", "Crossover na polia", "Peitoral"),
        Pr("11111111-0000-0000-0000-00000000001a", "Flexão de braço", "Peitoral"),
        Pr("11111111-0000-0000-0000-00000000001b", "Paralelas para peito", "Peitoral"),

        // ───────── Costas ─────────
        Cr("22220000-0000-0000-0000-000000000001", "Puxada frontal", "Dorsal"),
        Cr("22220000-0000-0000-0000-000000000002", "Puxada supinada", "Dorsal"),
        Pr("22220000-0000-0000-0000-000000000003", "Barra fixa", "Dorsal"),
        Cr("22220000-0000-0000-0000-000000000004", "Remada curvada com barra", "Dorsal"),
        Cr("22220000-0000-0000-0000-000000000005", "Remada unilateral com halter, o serrote", "Dorsal"),
        Cr("22220000-0000-0000-0000-000000000006", "Remada baixa na polia", "Dorsal"),
        Cr("22220000-0000-0000-0000-000000000007", "Remada cavalinho", "Dorsal"),
        Cr("22220000-0000-0000-0000-000000000008", "Remada na máquina", "Dorsal"),
        Cr("22220000-0000-0000-0000-000000000009", "Pulldown com braço estendido", "Dorsal"),
        Cr("22220000-0000-0000-0000-00000000000a", "Encolhimento com halteres", "Trapézio"),
        Cr("22220000-0000-0000-0000-00000000000b", "Encolhimento com barra", "Trapézio"),
        Cr("22220000-0000-0000-0000-00000000000c", "Levantamento terra", null),

        // ───────── Ombros (Deltoide) ─────────
        Cr("33330000-0000-0000-0000-000000000001", "Desenvolvimento com halteres", "Deltoide"),
        Cr("33330000-0000-0000-0000-000000000002", "Desenvolvimento militar com barra", "Deltoide"),
        Cr("33330000-0000-0000-0000-000000000003", "Desenvolvimento na máquina", "Deltoide"),
        Cr("33330000-0000-0000-0000-000000000004", "Elevação lateral com halteres", "Deltoide"),
        Cr("33330000-0000-0000-0000-000000000005", "Elevação lateral na polia", "Deltoide"),
        Cr("33330000-0000-0000-0000-000000000006", "Elevação frontal", "Deltoide"),
        Cr("33330000-0000-0000-0000-000000000007", "Crucifixo invertido", "Deltoide"),
        Cr("33330000-0000-0000-0000-000000000008", "Face pull", "Deltoide"),
        Cr("33330000-0000-0000-0000-000000000009", "Remada alta", "Deltoide"),

        // ───────── Braços ─────────
        Cr("44440000-0000-0000-0000-000000000001", "Rosca direta com barra", "Bíceps"),
        Cr("44440000-0000-0000-0000-000000000002", "Rosca alternada com halteres", "Bíceps"),
        Cr("44440000-0000-0000-0000-000000000003", "Rosca martelo", "Bíceps"),
        Cr("44440000-0000-0000-0000-000000000004", "Rosca scott", "Bíceps"),
        Cr("44440000-0000-0000-0000-000000000005", "Rosca concentrada", "Bíceps"),
        Cr("44440000-0000-0000-0000-000000000006", "Rosca na polia", "Bíceps"),
        Cr("44440000-0000-0000-0000-000000000007", "Tríceps corda", "Tríceps"),
        Cr("44440000-0000-0000-0000-000000000008", "Tríceps pulley com barra", "Tríceps"),
        Cr("44440000-0000-0000-0000-000000000009", "Tríceps testa", "Tríceps"),
        Cr("44440000-0000-0000-0000-00000000000a", "Tríceps francês", "Tríceps"),
        Cr("44440000-0000-0000-0000-00000000000b", "Tríceps coice", "Tríceps"),
        Cr("44440000-0000-0000-0000-00000000000c", "Supino fechado", "Tríceps"),
        Pr("44440000-0000-0000-0000-00000000000d", "Mergulho no banco", "Tríceps"),
        Cr("44440000-0000-0000-0000-00000000000e", "Rosca de punho", "Antebraço"),
        Cr("44440000-0000-0000-0000-00000000000f", "Rosca inversa", "Antebraço"),

        // ───────── Pernas ─────────
        Cr("11111111-0000-0000-0000-000000000005", "Agachamento livre", "Quadríceps"),
        Cr("55550000-0000-0000-0000-000000000002", "Agachamento no smith", "Quadríceps"),
        Cr("55550000-0000-0000-0000-000000000003", "Leg press 45°", "Quadríceps"),
        Cr("55550000-0000-0000-0000-000000000004", "Hack machine", "Quadríceps"),
        Cr("55550000-0000-0000-0000-000000000005", "Cadeira extensora", "Quadríceps"),
        Cr("55550000-0000-0000-0000-000000000006", "Afundo com halteres", "Quadríceps"),
        Cr("55550000-0000-0000-0000-000000000007", "Agachamento búlgaro", "Quadríceps"),
        Pt("55550000-0000-0000-0000-000000000008", "Agachamento isométrico na parede", "Quadríceps"),
        Cr("55550000-0000-0000-0000-000000000009", "Mesa flexora", "Posteriores de coxa"),
        Cr("55550000-0000-0000-0000-00000000000a", "Cadeira flexora", "Posteriores de coxa"),
        Cr("55550000-0000-0000-0000-00000000000b", "Stiff", "Posteriores de coxa"),
        Cr("55550000-0000-0000-0000-00000000000c", "Elevação pélvica", "Glúteos"),
        Cr("55550000-0000-0000-0000-00000000000d", "Glúteo na polia", "Glúteos"),
        Cr("55550000-0000-0000-0000-00000000000e", "Cadeira abdutora", "Glúteos"),
        Cr("55550000-0000-0000-0000-00000000000f", "Cadeira adutora", "Adutores"),
        Cr("55550000-0000-0000-0000-000000000010", "Agachamento sumô", "Adutores"),
        Cr("55550000-0000-0000-0000-000000000011", "Panturrilha em pé", "Panturrilha"),
        Cr("55550000-0000-0000-0000-000000000012", "Panturrilha sentado", "Panturrilha"),

        // ───────── Core ─────────
        Pr("66660000-0000-0000-0000-000000000001", "Abdominal supra", "Abdômen"),
        Pr("66660000-0000-0000-0000-000000000002", "Elevação de pernas", "Abdômen"),
        Cr("66660000-0000-0000-0000-000000000003", "Abdominal na polia", "Abdômen"),
        Pr("66660000-0000-0000-0000-000000000004", "Roda abdominal", "Abdômen"),
        Pt("22222222-0000-0000-0000-000000000001", "Prancha", "Abdômen"),
        Pt("66660000-0000-0000-0000-000000000006", "Prancha lateral", "Oblíquos"),
        Pr("66660000-0000-0000-0000-000000000007", "Rotação russa", "Oblíquos"),
        Pr("66660000-0000-0000-0000-000000000008", "Abdominal bicicleta", "Oblíquos"),
        Pr("66660000-0000-0000-0000-000000000009", "Extensão lombar no banco romano", "Lombar"),
        Pt("66660000-0000-0000-0000-00000000000a", "Superman", "Lombar"),

        // ───────── Cardio (sem músculo) ─────────
        Zt("77770000-0000-0000-0000-000000000001", "Corrida"),
        Zt("77770000-0000-0000-0000-000000000002", "Esteira"),
        Zt("77770000-0000-0000-0000-000000000003", "Bicicleta ergométrica"),
        Zt("77770000-0000-0000-0000-000000000004", "Elíptico"),
        Zt("77770000-0000-0000-0000-000000000005", "Simulador de escada"),
        Zt("77770000-0000-0000-0000-000000000006", "Remo ergômetro"),
        Zt("77770000-0000-0000-0000-000000000007", "Pular corda"),
        Zt("77770000-0000-0000-0000-000000000008", "Caminhada"),

        // ───────── Mobilidade (sem músculo) ─────────
        Pt("88880000-0000-0000-0000-000000000001", "Alongamento de posteriores", null),
        Pt("88880000-0000-0000-0000-000000000002", "Alongamento de quadríceps", null),
        Pt("88880000-0000-0000-0000-000000000003", "Mobilidade de quadril", null),
        Pt("88880000-0000-0000-0000-000000000004", "Mobilidade de ombro", null),
        Pt("88880000-0000-0000-0000-000000000005", "Equilíbrio unipodal", null),
    ];
}
