using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using DiarioTreino.IntegrationTests.Infraestrutura;

namespace DiarioTreino.IntegrationTests;

/// <summary>Listar sessões do período (PBI-22, GET /sessoes).</summary>
[Collection(PostgresCollection.Nome)]
public sealed class SessaoListaEndpointTests
{
    private readonly PostgresFixture _postgres;

    public SessaoListaEndpointTests(PostgresFixture postgres)
    {
        _postgres = postgres;
    }

    private sealed record PlanoResp(Guid Id, string Nome, List<object> Treinos);
    private sealed record CriadoResp(Guid Id);
    private sealed record SessaoResumoResp(
        Guid Id,
        DateOnly Data,
        Guid? TreinoId,
        string? TreinoNome,
        int QuantidadeExercicios,
        short? DuracaoMin,
        bool TemObservacao);

    // Exercícios globais do seed.
    private static readonly Guid SupinoReto = Guid.Parse("11111111-0000-0000-0000-000000000001");
    private const short CargaKg = 1;
    private const short Repeticoes = 10;

    private static (ApiFactory api, HttpClient client, string uid) Autenticar(PostgresFixture pg)
    {
        var api = new ApiFactory(pg.ConnectionString);
        var client = api.CreateClient();
        var uid = $"uid-{Guid.NewGuid():n}";
        var token = api.Tokens.Gerar(uid, email: $"{uid}@teste.local", nome: "Atleta");
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
        return (api, client, uid);
    }

    private static async Task<Guid> CriarFicha(HttpClient client, string nome)
    {
        var plano = await (await client.PostAsync("/api/v1/planos", null))
            .Content.ReadFromJsonAsync<PlanoResp>();
        var criar = await client.PostAsJsonAsync($"/api/v1/planos/{plano!.Id}/treinos",
            new { nome, descricao = (string?)null });
        return (await criar.Content.ReadFromJsonAsync<CriadoResp>())!.Id;
    }

    private static async Task<Guid> AddExercicio(HttpClient client, Guid treinoId, Guid exercicioId)
    {
        var resp = await client.PostAsJsonAsync(
            $"/api/v1/treinos/{treinoId}/exercicios", new { exercicioId });
        return (await resp.Content.ReadFromJsonAsync<CriadoResp>())!.Id;
    }

    private static object Serie(short rodada, decimal carga, decimal reps) => new
    {
        rodada,
        ordem = (short)1,
        tipo = "ESFORCO",
        intensidadeMetricaId = CargaKg,
        intensidade = carga,
        volumeMetricaId = Repeticoes,
        volume = reps,
        descansoSeg = (short?)90,
    };

    private static async Task<Guid> CriarSessao(
        HttpClient client, Guid? treinoId, Guid teSupino, DateOnly data,
        string? observacao, int duracaoMin)
    {
        var criar = await client.PostAsJsonAsync("/api/v1/sessoes", new
        {
            treinoId,
            data,
            duracaoMin,
            observacao,
            exercicios = new[]
            {
                new { exercicioId = SupinoReto, treinoExercicioId = teSupino, series = new[] { Serie(1, 30, 10) } },
            },
        });
        criar.EnsureSuccessStatusCode();
        return (await criar.Content.ReadFromJsonAsync<CriadoResp>())!.Id;
    }

    [Fact]
    public async Task Lista_sessoes_mais_recente_primeiro_com_resumo()
    {
        var (api, client, _) = Autenticar(_postgres);
        await using var _api = api;

        var treinoId = await CriarFicha(client, "A");
        var teSupino = await AddExercicio(client, treinoId, SupinoReto);

        var hoje = DateOnly.FromDateTime(DateTime.UtcNow.Date);
        var antiga = await CriarSessao(client, treinoId, teSupino, hoje.AddDays(-3), observacao: null, duracaoMin: 40);
        var recente = await CriarSessao(client, treinoId, teSupino, hoje, observacao: "Dormi mal", duracaoMin: 50);

        var lista = await client.GetFromJsonAsync<List<SessaoResumoResp>>("/api/v1/sessoes");

        Assert.NotNull(lista);
        Assert.Equal(2, lista!.Count);
        // Mais recente primeiro.
        Assert.Equal(recente, lista[0].Id);
        Assert.Equal(antiga, lista[1].Id);
        // Resumo do item mais recente.
        Assert.Equal("A", lista[0].TreinoNome);
        Assert.Equal(1, lista[0].QuantidadeExercicios);
        Assert.Equal((short)50, lista[0].DuracaoMin);
        Assert.True(lista[0].TemObservacao);
        // A antiga não tem observação.
        Assert.False(lista[1].TemObservacao);
    }

    [Fact]
    public async Task Filtra_pelo_periodo_de_e_ate()
    {
        var (api, client, _) = Autenticar(_postgres);
        await using var _api = api;

        var treinoId = await CriarFicha(client, "A");
        var teSupino = await AddExercicio(client, treinoId, SupinoReto);

        var hoje = DateOnly.FromDateTime(DateTime.UtcNow.Date);
        await CriarSessao(client, treinoId, teSupino, hoje, observacao: null, duracaoMin: 30);
        var antiga = await CriarSessao(client, treinoId, teSupino, hoje.AddDays(-10), observacao: null, duracaoMin: 30);

        // Janela que exclui a sessão de hoje e inclui a de 10 dias atrás.
        var de = hoje.AddDays(-15);
        var ate = hoje.AddDays(-5);
        var lista = await client.GetFromJsonAsync<List<SessaoResumoResp>>(
            $"/api/v1/sessoes?de={de:yyyy-MM-dd}&ate={ate:yyyy-MM-dd}");

        Assert.NotNull(lista);
        Assert.Single(lista!);
        Assert.Equal(antiga, lista![0].Id);
    }

    [Fact]
    public async Task Nao_lista_sessoes_de_outro_usuario()
    {
        var (apiA, clientA, _) = Autenticar(_postgres);
        await using var _apiA = apiA;
        var treinoId = await CriarFicha(clientA, "A");
        var teSupino = await AddExercicio(clientA, treinoId, SupinoReto);
        var hoje = DateOnly.FromDateTime(DateTime.UtcNow.Date);
        var sessaoDeA = await CriarSessao(clientA, treinoId, teSupino, hoje, observacao: null, duracaoMin: 30);

        var (apiB, clientB, _) = Autenticar(_postgres);
        await using var _apiB = apiB;
        var listaB = await clientB.GetFromJsonAsync<List<SessaoResumoResp>>("/api/v1/sessoes");

        Assert.NotNull(listaB);
        Assert.Empty(listaB!);
        Assert.DoesNotContain(listaB!, s => s.Id == sessaoDeA);
    }

    [Fact]
    public async Task Sem_token_responde_401()
    {
        await using var api = new ApiFactory(_postgres.ConnectionString);
        var client = api.CreateClient();

        var resposta = await client.GetAsync("/api/v1/sessoes");

        Assert.Equal(HttpStatusCode.Unauthorized, resposta.StatusCode);
    }
}
