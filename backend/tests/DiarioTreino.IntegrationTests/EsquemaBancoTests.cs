using DiarioTreino.Domain.Catalogo;
using DiarioTreino.Domain.Comum;
using DiarioTreino.IntegrationTests.Infraestrutura;
using Microsoft.EntityFrameworkCore;

namespace DiarioTreino.IntegrationTests;

[Collection(PostgresCollection.Nome)]
public sealed class EsquemaBancoTests
{
    private readonly PostgresFixture _postgres;

    public EsquemaBancoTests(PostgresFixture postgres)
    {
        _postgres = postgres;
    }

    [Fact]
    public async Task Migration_aplica_do_zero_e_semeia_as_seis_metricas()
    {
        await using var db = _postgres.CriarContexto();

        var metricas = await db.Metricas.OrderBy(m => m.Id).ToListAsync();

        Assert.Equal(6, metricas.Count);
        Assert.Contains(metricas, m => m.Codigo == "CARGA_KG" && m.Eixo == EixoMetrica.Intensidade);
        Assert.Contains(metricas, m => m.Codigo == "DISTANCIA_M" && m.Eixo == EixoMetrica.Volume);
    }

    [Fact]
    public async Task Semeia_catalogo_global_com_os_exercicios_do_prototipo()
    {
        await using var db = _postgres.CriarContexto();

        var globais = await db.Exercicios.Where(e => e.CriadoPorId == null).ToListAsync();
        var ativos = globais.Where(e => e.Ativo).ToList();

        // Carga de catálogo (14/10): 89 exercícios ativos no catálogo + 7
        // genéricos antigos aposentados (ativo=false) que ficam no banco por
        // causa das FKs Restrict, mas somem do catálogo.
        Assert.Equal(89, ativos.Count);
        Assert.Equal(7, globais.Count(e => !e.Ativo));

        // Representantes de cada modalidade/forma de medir.
        Assert.Contains(ativos, e => e.Nome == "Supino reto com barra" && e.Modalidade == Modalidade.Forca);
        Assert.Contains(ativos, e => e.Nome == "Flexão de braço" && e.Modalidade == Modalidade.Forca && e.IntensidadeMetricaPadraoId == MetricaCodigos.PesoCorporal);
        Assert.Contains(ativos, e => e.Nome == "Prancha" && e.Modalidade == Modalidade.Isometria);
        Assert.Contains(ativos, e => e.Nome == "Corrida" && e.Modalidade == Modalidade.Cardio);

        // Os aposentados não aparecem no catálogo (ficam inativos).
        Assert.DoesNotContain(ativos, e => e.Nome == "Supino inclinado");
    }

    [Fact]
    public async Task Semeia_membros_e_musculos_e_classifica_o_catalogo_global()
    {
        await using var db = _postgres.CriarContexto();

        // 8 membros (MER 3.4.1) e 15 músculos (MER 3.4.2).
        var membros = await db.Membros.OrderBy(m => m.Ordem).ToListAsync();
        Assert.Equal(8, membros.Count);
        Assert.Equal(
            new[] { "PEITO", "COSTAS", "OMBROS", "BRACOS", "PERNAS", "CORE", "CARDIO", "MOBILIDADE" },
            membros.Select(m => m.Codigo).ToArray());
        Assert.Equal(15, await db.Musculos.CountAsync());

        // Exercícios do catálogo ativos ficaram classificados por membro.
        var ativos = await db.Exercicios
            .Where(e => e.CriadoPorId == null && e.Ativo).ToListAsync();

        // Supino reto com barra → Peito/Peitoral.
        var supino = ativos.Single(e => e.Nome == "Supino reto com barra");
        Assert.Equal(MembroCodigos.Peito, supino.MembroId);
        Assert.Equal(MusculoCodigos.Peitoral, supino.MusculoId);

        // Corrida (cardio) → membro Cardio, sem músculo.
        var corrida = ativos.Single(e => e.Nome == "Corrida");
        Assert.Equal(MembroCodigos.Cardio, corrida.MembroId);
        Assert.Null(corrida.MusculoId);

        // Mobilidade sem grupo → membro Mobilidade, sem músculo.
        var mobilidade = ativos.Single(e => e.Nome == "Mobilidade de quadril");
        Assert.Equal(MembroCodigos.Mobilidade, mobilidade.MembroId);
        Assert.Null(mobilidade.MusculoId);

        // "Levantamento terra" (força sem grupo) fica sem membro (não casou).
        var terra = ativos.Single(e => e.Nome == "Levantamento terra");
        Assert.Null(terra.MembroId);
        Assert.Null(terra.MusculoId);

        // Todo exercício classificado respeita a FK composta: o músculo
        // pertence ao membro.
        foreach (var e in ativos.Where(x => x.MusculoId != null))
        {
            var mus = await db.Musculos.SingleAsync(m => m.Id == e.MusculoId);
            Assert.Equal(e.MembroId, mus.MembroId);
        }
    }

    [Fact]
    public async Task Indice_unico_impede_nome_de_exercicio_repetido_no_mesmo_catalogo()
    {
        await using var db = _postgres.CriarContexto();

        // "Supino reto com barra" já existe no catálogo global (criado_por_id nulo).
        db.Exercicios.Add(new Exercicio
        {
            Id = Guid.NewGuid(),
            Nome = "supino reto com barra", // case-insensitive pelo índice lower(nome)
            GrupoMuscular = "peito",
            Modalidade = Modalidade.Forca,
            IntensidadeMetricaPadraoId = MetricaCodigos.CargaKg,
            VolumeMetricaPadraoId = MetricaCodigos.Repeticoes,
            CriadoPorId = null,
        });

        await Assert.ThrowsAsync<DbUpdateException>(() => db.SaveChangesAsync());
    }

    [Fact]
    public async Task Check_de_data_futura_rejeita_sessao_alem_de_amanha()
    {
        await using var db = _postgres.CriarContexto();

        var atletaId = await SemearUsuarioAsync(db);

        db.Sessoes.Add(new Domain.Execucao.Sessao
        {
            Id = Guid.NewGuid(),
            AtletaId = atletaId,
            RegistradoPorId = atletaId,
            Data = DateOnly.FromDateTime(DateTime.UtcNow.AddDays(5).Date),
        });

        await Assert.ThrowsAsync<DbUpdateException>(() => db.SaveChangesAsync());
    }

    private static async Task<Guid> SemearUsuarioAsync(Infrastructure.Persistencia.DiarioTreinoDbContext db)
    {
        var id = Guid.NewGuid();
        db.Usuarios.Add(new Domain.Identidade.Usuario
        {
            Id = id,
            FirebaseUid = $"uid-{id:n}",
            Nome = "Atleta Teste",
            Email = $"{id:n}@teste.local",
        });
        await db.SaveChangesAsync();
        return id;
    }
}
