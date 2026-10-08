using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using DiarioTreino.Domain.Comum;
using DiarioTreino.Domain.Execucao;
using DiarioTreino.IntegrationTests.Infraestrutura;
using Microsoft.EntityFrameworkCore;

namespace DiarioTreino.IntegrationTests;

[Collection(PostgresCollection.Nome)]
public sealed class FichaExerciciosEndpointTests
{
    private readonly PostgresFixture _postgres;

    public FichaExerciciosEndpointTests(PostgresFixture postgres)
    {
        _postgres = postgres;
    }

    private sealed record PlanoResp(Guid Id, string Nome, List<TreinoResp> Treinos);
    private sealed record TreinoResp(Guid Id, string Nome, string? Descricao, short Ordem);
    private sealed record FichaResp(Guid Id, string Nome, string? Descricao, short Ordem, List<TeResp> Exercicios);
    private sealed record TeResp(Guid Id, Guid ExercicioId, string Nome, string? GrupoMuscular, string Modalidade, short Ordem, short Rodadas);
    private sealed record CriadoResp(Guid Id);

    // Exercício global do seed usado nos testes.
    private static readonly Guid SupinoReto = Guid.Parse("11111111-0000-0000-0000-000000000001");
    private static readonly Guid Agachamento = Guid.Parse("11111111-0000-0000-0000-000000000005");

    private static (ApiFactory api, HttpClient client, string uid) Autenticar(PostgresFixture pg)
    {
        var api = new ApiFactory(pg.ConnectionString);
        var client = api.CreateClient();
        var uid = $"uid-{Guid.NewGuid():n}";
        var token = api.Tokens.Gerar(uid, email: $"{uid}@teste.local", nome: "Atleta");
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
        return (api, client, uid);
    }

    private static async Task<Guid> CriarFicha(HttpClient client)
    {
        var plano = await (await client.PostAsync("/api/v1/planos", null))
            .Content.ReadFromJsonAsync<PlanoResp>();
        var criar = await client.PostAsJsonAsync($"/api/v1/planos/{plano!.Id}/treinos",
            new { nome = "A", descricao = "Peito" });
        return (await criar.Content.ReadFromJsonAsync<CriadoResp>())!.Id;
    }

    private static Task<HttpResponseMessage> AddExercicio(HttpClient client, Guid treinoId, Guid exercicioId) =>
        client.PostAsJsonAsync($"/api/v1/treinos/{treinoId}/exercicios", new { exercicioId });

    [Fact]
    public async Task Adicionar_exercicios_aparecem_no_detalhe_com_ordem()
    {
        var (api, client, _) = Autenticar(_postgres);
        await using var _api = api;
        var treinoId = await CriarFicha(client);

        var r1 = await AddExercicio(client, treinoId, SupinoReto);
        Assert.Equal(HttpStatusCode.Created, r1.StatusCode);
        await AddExercicio(client, treinoId, Agachamento);

        var ficha = await client.GetFromJsonAsync<FichaResp>($"/api/v1/treinos/{treinoId}");
        Assert.Equal(2, ficha!.Exercicios.Count);
        Assert.Equal(new short[] { 1, 2 }, ficha.Exercicios.Select(e => e.Ordem).ToArray());
        Assert.Contains(ficha.Exercicios, e => e.Nome == "Supino reto");
    }

    [Fact]
    public async Task Reordenar_troca_a_ordem_dos_exercicios()
    {
        var (api, client, _) = Autenticar(_postgres);
        await using var _api = api;
        var treinoId = await CriarFicha(client);

        var te1 = (await (await AddExercicio(client, treinoId, SupinoReto)).Content
            .ReadFromJsonAsync<CriadoResp>())!.Id;
        var te2 = (await (await AddExercicio(client, treinoId, Agachamento)).Content
            .ReadFromJsonAsync<CriadoResp>())!.Id;

        // Inverte: te2 primeiro.
        var reord = await client.PutAsJsonAsync($"/api/v1/treinos/{treinoId}/exercicios/ordem",
            new { treinoExercicioIds = new[] { te2, te1 } });
        Assert.Equal(HttpStatusCode.NoContent, reord.StatusCode);

        var ficha = await client.GetFromJsonAsync<FichaResp>($"/api/v1/treinos/{treinoId}");
        Assert.Equal(te2, ficha!.Exercicios[0].Id);
        Assert.Equal(te1, ficha.Exercicios[1].Id);
    }

    [Fact]
    public async Task Remover_exercicio_tira_da_ficha()
    {
        var (api, client, _) = Autenticar(_postgres);
        await using var _api = api;
        var treinoId = await CriarFicha(client);
        var teId = (await (await AddExercicio(client, treinoId, SupinoReto)).Content
            .ReadFromJsonAsync<CriadoResp>())!.Id;

        var del = await client.DeleteAsync($"/api/v1/treinos/{treinoId}/exercicios/{teId}");
        Assert.Equal(HttpStatusCode.NoContent, del.StatusCode);

        var ficha = await client.GetFromJsonAsync<FichaResp>($"/api/v1/treinos/{treinoId}");
        Assert.Empty(ficha!.Exercicios);
    }

    [Fact]
    public async Task Remover_exercicio_nao_apaga_o_historico_de_series()
    {
        var (api, client, uid) = Autenticar(_postgres);
        await using var _api = api;
        var treinoId = await CriarFicha(client);
        var teId = (await (await AddExercicio(client, treinoId, SupinoReto)).Content
            .ReadFromJsonAsync<CriadoResp>())!.Id;

        // Semeia uma sessão com uma série ligada ao treino_exercicio.
        Guid serieId;
        await using (var db = _postgres.CriarContexto())
        {
            var atletaId = await db.Usuarios.Where(u => u.FirebaseUid == uid)
                .Select(u => u.Id).SingleAsync();
            var sessao = new Sessao
            {
                Id = Guid.NewGuid(),
                AtletaId = atletaId,
                TreinoId = treinoId,
                RegistradoPorId = atletaId,
                Data = DateOnly.FromDateTime(DateTime.UtcNow),
            };
            db.Sessoes.Add(sessao);
            var serie = new SerieExecutada
            {
                Id = Guid.NewGuid(),
                SessaoId = sessao.Id,
                ExercicioId = SupinoReto,
                TreinoExercicioId = teId,
                Rodada = 1,
                Ordem = 1,
                Tipo = TipoEtapa.Esforco,
                IntensidadeMetricaId = MetricaCodigos.CargaKg,
                Intensidade = 30,
                VolumeMetricaId = MetricaCodigos.Repeticoes,
                Volume = 10,
            };
            db.SeriesExecutadas.Add(serie);
            await db.SaveChangesAsync();
            serieId = serie.Id;
        }

        // Remove o exercício da ficha.
        var del = await client.DeleteAsync($"/api/v1/treinos/{treinoId}/exercicios/{teId}");
        Assert.Equal(HttpStatusCode.NoContent, del.StatusCode);

        // A série continua; só perdeu o vínculo com o prescrito (SET NULL).
        await using (var db = _postgres.CriarContexto())
        {
            var serie = await db.SeriesExecutadas.SingleAsync(s => s.Id == serieId);
            Assert.Null(serie.TreinoExercicioId);
            Assert.Equal(30m, serie.Intensidade);
        }
    }

    [Fact]
    public async Task Adicionar_exercicio_em_ficha_de_outro_usuario_responde_404()
    {
        var (apiA, clientA, _) = Autenticar(_postgres);
        await using var _apiA = apiA;
        var treinoId = await CriarFicha(clientA);

        var (apiB, clientB, _) = Autenticar(_postgres);
        await using var _apiB = apiB;
        var resposta = await AddExercicio(clientB, treinoId, SupinoReto);

        Assert.Equal(HttpStatusCode.NotFound, resposta.StatusCode);
    }

    [Fact]
    public async Task Adicionar_exercicio_inexistente_responde_404()
    {
        var (api, client, _) = Autenticar(_postgres);
        await using var _api = api;
        var treinoId = await CriarFicha(client);

        var resposta = await AddExercicio(client, treinoId, Guid.NewGuid());

        Assert.Equal(HttpStatusCode.NotFound, resposta.StatusCode);
    }

    [Fact]
    public async Task Sem_token_responde_401()
    {
        await using var api = new ApiFactory(_postgres.ConnectionString);
        var client = api.CreateClient();

        var resposta = await client.GetAsync($"/api/v1/treinos/{Guid.NewGuid()}");

        Assert.Equal(HttpStatusCode.Unauthorized, resposta.StatusCode);
    }
}
