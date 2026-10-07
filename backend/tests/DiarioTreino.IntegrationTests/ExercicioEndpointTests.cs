using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using DiarioTreino.Domain.Catalogo;
using DiarioTreino.Domain.Comum;
using DiarioTreino.IntegrationTests.Infraestrutura;
using Microsoft.EntityFrameworkCore;

namespace DiarioTreino.IntegrationTests;

[Collection(PostgresCollection.Nome)]
public sealed class ExercicioEndpointTests
{
    private readonly PostgresFixture _postgres;

    public ExercicioEndpointTests(PostgresFixture postgres)
    {
        _postgres = postgres;
    }

    private sealed record ExercicioResumoResposta(
        Guid Id,
        string Nome,
        string? GrupoMuscular,
        string Modalidade,
        string IntensidadeMetricaCodigo,
        string IntensidadeMetricaNome,
        string VolumeMetricaCodigo,
        string VolumeMetricaNome,
        bool Proprio);

    private static (ApiFactory api, HttpClient client, string uid) Autenticar(
        PostgresFixture postgres)
    {
        var api = new ApiFactory(postgres.ConnectionString);
        var client = api.CreateClient();
        var uid = $"uid-{Guid.NewGuid():n}";
        // E-mail único por usuário de teste: evita colisão com a constraint
        // única de e-mail, já que todos os testes compartilham o mesmo banco.
        var token = api.Tokens.Gerar(uid, email: $"{uid}@teste.local", nome: "Atleta");
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
        return (api, client, uid);
    }

    [Fact]
    public async Task Lista_o_catalogo_global()
    {
        var (api, client, _) = Autenticar(_postgres);
        await using var _api = api;

        var resposta = await client.GetAsync("/api/v1/exercicios");
        resposta.EnsureSuccessStatusCode();
        var itens = await resposta.Content.ReadFromJsonAsync<List<ExercicioResumoResposta>>();

        Assert.NotNull(itens);
        // Pelo menos os 10 exercícios do seed global.
        Assert.True(itens!.Count >= 10);
        Assert.Contains(itens, e => e.Nome == "Supino reto" && !e.Proprio);
        // A forma de medir vem preenchida.
        var supino = itens.First(e => e.Nome == "Supino reto");
        Assert.Equal("CARGA_KG", supino.IntensidadeMetricaCodigo);
        Assert.Equal("REPETICOES", supino.VolumeMetricaCodigo);
    }

    [Fact]
    public async Task Filtra_por_modalidade()
    {
        var (api, client, _) = Autenticar(_postgres);
        await using var _api = api;

        var resposta = await client.GetAsync("/api/v1/exercicios?modalidade=CARDIO");
        resposta.EnsureSuccessStatusCode();
        var itens = await resposta.Content.ReadFromJsonAsync<List<ExercicioResumoResposta>>();

        Assert.NotNull(itens);
        Assert.NotEmpty(itens!);
        Assert.All(itens!, e => Assert.Equal(Modalidade.Cardio, e.Modalidade));
    }

    [Fact]
    public async Task Busca_ignora_caixa_e_acento()
    {
        var (api, client, _) = Autenticar(_postgres);
        await using var _api = api;

        // "triceps" (sem acento, minúsculo) deve achar "Tríceps corda".
        var resposta = await client.GetAsync("/api/v1/exercicios?busca=triceps");
        resposta.EnsureSuccessStatusCode();
        var itens = await resposta.Content.ReadFromJsonAsync<List<ExercicioResumoResposta>>();

        Assert.NotNull(itens);
        Assert.Contains(itens!, e => e.Nome == "Tríceps corda");
    }

    [Fact]
    public async Task Exercicio_proprio_vem_marcado_e_de_outro_usuario_nao_aparece()
    {
        var (api, client, uid) = Autenticar(_postgres);
        await using var _api = api;

        // Provisiona o usuário logado (primeira chamada ao /me via /exercicios).
        await client.GetAsync("/api/v1/exercicios");

        // Descobre o id do usuário logado e insere um exercício próprio + um de outro usuário.
        await using (var db = _postgres.CriarContexto())
        {
            var meuId = await db.Usuarios.Where(u => u.FirebaseUid == uid)
                .Select(u => u.Id).SingleAsync();

            var outro = new Domain.Identidade.Usuario
            {
                Id = Guid.NewGuid(),
                FirebaseUid = $"outro-{Guid.NewGuid():n}",
                Nome = "Outro",
                Email = $"outro-{Guid.NewGuid():n}@teste.local",
                Papeis = [],
            };
            db.Usuarios.Add(outro);

            db.Exercicios.Add(NovoExercicio("Rosca direta minha", meuId));
            db.Exercicios.Add(NovoExercicio("Exercicio do outro", outro.Id));
            await db.SaveChangesAsync();
        }

        var resposta = await client.GetAsync("/api/v1/exercicios");
        resposta.EnsureSuccessStatusCode();
        var itens = await resposta.Content.ReadFromJsonAsync<List<ExercicioResumoResposta>>();

        Assert.NotNull(itens);
        Assert.Contains(itens!, e => e.Nome == "Rosca direta minha" && e.Proprio);
        Assert.DoesNotContain(itens!, e => e.Nome == "Exercicio do outro");
    }

    [Fact]
    public async Task Modalidade_invalida_responde_400()
    {
        var (api, client, _) = Autenticar(_postgres);
        await using var _api = api;

        var resposta = await client.GetAsync("/api/v1/exercicios?modalidade=XPTO");

        Assert.Equal(HttpStatusCode.BadRequest, resposta.StatusCode);
    }

    [Fact]
    public async Task Sem_token_responde_401()
    {
        await using var api = new ApiFactory(_postgres.ConnectionString);
        var client = api.CreateClient();

        var resposta = await client.GetAsync("/api/v1/exercicios");

        Assert.Equal(HttpStatusCode.Unauthorized, resposta.StatusCode);
    }

    // ---- PBI-11: GET /metricas e POST /exercicios ----

    [Fact]
    public async Task Metricas_lista_as_seis_de_referencia()
    {
        var (api, client, _) = Autenticar(_postgres);
        await using var _api = api;

        var resposta = await client.GetAsync("/api/v1/metricas");
        resposta.EnsureSuccessStatusCode();
        var metricas = await resposta.Content.ReadFromJsonAsync<List<MetricaResposta>>();

        Assert.NotNull(metricas);
        Assert.Equal(6, metricas!.Count);
        Assert.Contains(metricas, m => m.Codigo == "CARGA_KG" && m.Eixo == "INTENSIDADE");
        Assert.Contains(metricas, m => m.Codigo == "TEMPO_SEG" && m.Eixo == "VOLUME");
    }

    [Fact]
    public async Task Criar_exercicio_proprio_e_ele_aparece_na_busca_marcado()
    {
        var (api, client, _) = Autenticar(_postgres);
        await using var _api = api;

        var nome = $"Rosca {Guid.NewGuid():n}";
        var criar = await client.PostAsJsonAsync("/api/v1/exercicios", new
        {
            nome,
            grupoMuscular = "braço",
            modalidade = "FORCA",
            intensidadeMetricaId = (short)1,  // CARGA_KG
            volumeMetricaId = (short)10,      // REPETICOES
        });

        Assert.Equal(HttpStatusCode.Created, criar.StatusCode);

        var busca = await client.GetAsync($"/api/v1/exercicios?busca={nome}");
        busca.EnsureSuccessStatusCode();
        var itens = await busca.Content.ReadFromJsonAsync<List<ExercicioResumoResposta>>();
        Assert.Contains(itens!, e => e.Nome == nome && e.Proprio);
    }

    [Fact]
    public async Task Criar_com_nome_repetido_no_proprio_catalogo_responde_409()
    {
        var (api, client, _) = Autenticar(_postgres);
        await using var _api = api;

        var nome = $"Repetido {Guid.NewGuid():n}";
        object corpo = new
        {
            nome,
            grupoMuscular = "braço",
            modalidade = "FORCA",
            intensidadeMetricaId = (short)1,
            volumeMetricaId = (short)10,
        };

        var primeira = await client.PostAsJsonAsync("/api/v1/exercicios", corpo);
        Assert.Equal(HttpStatusCode.Created, primeira.StatusCode);

        var segunda = await client.PostAsJsonAsync("/api/v1/exercicios", corpo);
        Assert.Equal(HttpStatusCode.Conflict, segunda.StatusCode);
    }

    [Fact]
    public async Task Criar_com_metrica_de_eixo_errado_responde_400()
    {
        var (api, client, _) = Autenticar(_postgres);
        await using var _api = api;

        // Intensidade recebendo uma métrica de VOLUME (REPETICOES = 10).
        var resposta = await client.PostAsJsonAsync("/api/v1/exercicios", new
        {
            nome = $"Invalido {Guid.NewGuid():n}",
            modalidade = "FORCA",
            intensidadeMetricaId = (short)10,
            volumeMetricaId = (short)10,
        });

        Assert.Equal(HttpStatusCode.BadRequest, resposta.StatusCode);
    }

    [Fact]
    public async Task Criar_sem_nome_responde_400_validacao()
    {
        var (api, client, _) = Autenticar(_postgres);
        await using var _api = api;

        var resposta = await client.PostAsJsonAsync("/api/v1/exercicios", new
        {
            nome = "",
            modalidade = "FORCA",
            intensidadeMetricaId = (short)1,
            volumeMetricaId = (short)10,
        });

        Assert.Equal(HttpStatusCode.BadRequest, resposta.StatusCode);
    }

    private sealed record MetricaResposta(short Id, string Codigo, string Nome, string Unidade, string Eixo);

    private static Exercicio NovoExercicio(string nome, Guid donoId) => new()
    {
        Id = Guid.NewGuid(),
        Nome = nome,
        GrupoMuscular = "braço",
        Modalidade = Modalidade.Forca,
        IntensidadeMetricaPadraoId = MetricaCodigos.CargaKg,
        VolumeMetricaPadraoId = MetricaCodigos.Repeticoes,
        CriadoPorId = donoId,
    };
}
