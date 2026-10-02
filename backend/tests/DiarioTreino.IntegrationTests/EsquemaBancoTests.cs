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

        var exercicios = await db.Exercicios.Where(e => e.CriadoPorId == null).ToListAsync();

        Assert.Equal(10, exercicios.Count);
        Assert.Contains(exercicios, e => e.Nome == "Supino reto" && e.Modalidade == Modalidade.Forca);
        Assert.Contains(exercicios, e => e.Nome == "Prancha" && e.Modalidade == Modalidade.Isometria);
        Assert.Contains(exercicios, e => e.Nome == "Corrida" && e.Modalidade == Modalidade.Cardio);
    }

    [Fact]
    public async Task Indice_unico_impede_nome_de_exercicio_repetido_no_mesmo_catalogo()
    {
        await using var db = _postgres.CriarContexto();

        // "Supino reto" já existe no catálogo global (criado_por_id nulo).
        db.Exercicios.Add(new Exercicio
        {
            Id = Guid.NewGuid(),
            Nome = "supino reto", // case-insensitive pelo índice lower(nome)
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
