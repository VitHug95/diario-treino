using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using DiarioTreino.IntegrationTests.Infraestrutura;
using Microsoft.EntityFrameworkCore;

namespace DiarioTreino.IntegrationTests;

/// <summary>Ver, editar e excluir sessão (PBI-18).</summary>
[Collection(PostgresCollection.Nome)]
public sealed class SessaoCrudEndpointTests
{
    private readonly PostgresFixture _postgres;

    public SessaoCrudEndpointTests(PostgresFixture postgres)
    {
        _postgres = postgres;
    }

    private sealed record PlanoResp(Guid Id, string Nome, List<object> Treinos);
    private sealed record CriadoResp(Guid Id);
    private sealed record SessaoDetalheResp(
        Guid Id, Guid? TreinoId, string? TreinoNome, DateOnly Data, short? DuracaoMin,
        string? Observacao, List<ExDetalheResp> Exercicios);
    private sealed record ExDetalheResp(
        Guid ExercicioId, Guid? TreinoExercicioId, string Nome, string? GrupoMuscular,
        string Modalidade, short Ordem, bool NaoRealizado, bool ForaDaFicha,
        string? Plano, List<SerieDetalheResp> Series);
    private sealed record SerieDetalheResp(
        short Rodada, short Ordem, string Tipo,
        short IntensidadeMetricaId, string IntensidadeMetricaCodigo, string IntensidadeMetricaNome,
        decimal? Intensidade,
        short VolumeMetricaId, string VolumeMetricaCodigo, string VolumeMetricaNome, decimal Volume,
        short? DescansoSeg);

    // Exercícios globais do seed.
    private static readonly Guid SupinoReto = Guid.Parse("11111111-0000-0000-0000-000000000001");
    private static readonly Guid Agachamento = Guid.Parse("11111111-0000-0000-0000-000000000005");

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

    private static async Task<Guid> CriarFicha(HttpClient client)
    {
        var plano = await (await client.PostAsync("/api/v1/planos", null))
            .Content.ReadFromJsonAsync<PlanoResp>();
        var criar = await client.PostAsJsonAsync($"/api/v1/planos/{plano!.Id}/treinos",
            new { nome = "A", descricao = "Peito" });
        return (await criar.Content.ReadFromJsonAsync<CriadoResp>())!.Id;
    }

    private static async Task<Guid> AddExercicio(HttpClient client, Guid treinoId, Guid exercicioId)
    {
        var resp = await client.PostAsJsonAsync(
            $"/api/v1/treinos/{treinoId}/exercicios", new { exercicioId });
        return (await resp.Content.ReadFromJsonAsync<CriadoResp>())!.Id;
    }

    private static Task DefinirAlvos(HttpClient client, Guid treinoId, Guid teId) =>
        client.PutAsJsonAsync(
            $"/api/v1/treinos/{treinoId}/exercicios/{teId}/alvos",
            new
            {
                series = 3,
                intensidadeMetricaId = CargaKg,
                intensidadeAlvo = 30,
                volumeMetricaId = Repeticoes,
                volumeAlvo = 10,
                descansoSeg = 90,
                instrucao = (string?)null,
            });

    private static object SerieCorpo(short rodada, decimal carga, decimal reps) => new
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
        HttpClient client, Guid treinoId, Guid teSupino, object[] seriesSupino)
    {
        var criar = await client.PostAsJsonAsync("/api/v1/sessoes", new
        {
            treinoId,
            data = DateOnly.FromDateTime(DateTime.UtcNow.Date),
            duracaoMin = 45,
            observacao = "Primeiro treino",
            exercicios = new[]
            {
                new { exercicioId = SupinoReto, treinoExercicioId = teSupino, series = seriesSupino },
            },
        });
        criar.EnsureSuccessStatusCode();
        return (await criar.Content.ReadFromJsonAsync<CriadoResp>())!.Id;
    }

    [Fact]
    public async Task Detalhe_mostra_series_plano_e_nao_realizado()
    {
        var (api, client, _) = Autenticar(_postgres);
        await using var _api = api;
        var treinoId = await CriarFicha(client);
        var teSupino = await AddExercicio(client, treinoId, SupinoReto);
        await DefinirAlvos(client, treinoId, teSupino);
        // Agachamento está na ficha mas não vai ser feito nesta sessão.
        await AddExercicio(client, treinoId, Agachamento);

        var sessaoId = await CriarSessao(client, treinoId, teSupino,
            new[] { SerieCorpo(1, 30, 10), SerieCorpo(2, 32, 8) });

        var detalhe = await client.GetFromJsonAsync<SessaoDetalheResp>($"/api/v1/sessoes/{sessaoId}");

        Assert.Equal(treinoId, detalhe!.TreinoId);
        Assert.Equal("A", detalhe.TreinoNome);
        Assert.Equal("Primeiro treino", detalhe.Observacao);

        var supino = detalhe.Exercicios.Single(e => e.ExercicioId == SupinoReto);
        Assert.False(supino.NaoRealizado);
        Assert.Equal(2, supino.Series.Count);
        Assert.Equal("3 × 10 com 30 Carga", supino.Plano);

        var agachamento = detalhe.Exercicios.Single(e => e.ExercicioId == Agachamento);
        Assert.True(agachamento.NaoRealizado);
        Assert.Empty(agachamento.Series);
    }

    [Fact]
    public async Task Editar_troca_dados_e_series()
    {
        var (api, client, _) = Autenticar(_postgres);
        await using var _api = api;
        var treinoId = await CriarFicha(client);
        var teSupino = await AddExercicio(client, treinoId, SupinoReto);
        var sessaoId = await CriarSessao(client, treinoId, teSupino, new[] { SerieCorpo(1, 30, 10) });

        var novaData = DateOnly.FromDateTime(DateTime.UtcNow.Date).AddDays(-2);
        var put = await client.PutAsJsonAsync($"/api/v1/sessoes/{sessaoId}", new
        {
            treinoId,
            data = novaData,
            duracaoMin = 60,
            observacao = "Editado",
            exercicios = new[]
            {
                new
                {
                    exercicioId = SupinoReto,
                    treinoExercicioId = teSupino,
                    series = new[] { SerieCorpo(1, 40, 6), SerieCorpo(2, 40, 6), SerieCorpo(3, 38, 6) },
                },
            },
        });
        Assert.Equal(HttpStatusCode.NoContent, put.StatusCode);

        var detalhe = await client.GetFromJsonAsync<SessaoDetalheResp>($"/api/v1/sessoes/{sessaoId}");
        Assert.Equal(novaData, detalhe!.Data);
        Assert.Equal((short)60, detalhe.DuracaoMin);
        Assert.Equal("Editado", detalhe.Observacao);
        var supino = detalhe.Exercicios.Single(e => e.ExercicioId == SupinoReto);
        Assert.Equal(3, supino.Series.Count);
        Assert.All(supino.Series, s => Assert.Equal(6m, s.Volume));

        // Confere no banco que não sobraram séries antigas.
        await using var db = _postgres.CriarContexto();
        var total = await db.SeriesExecutadas.CountAsync(s => s.SessaoId == sessaoId);
        Assert.Equal(3, total);
    }

    [Fact]
    public async Task Excluir_remove_a_sessao_e_as_series()
    {
        var (api, client, _) = Autenticar(_postgres);
        await using var _api = api;
        var treinoId = await CriarFicha(client);
        var teSupino = await AddExercicio(client, treinoId, SupinoReto);
        var sessaoId = await CriarSessao(client, treinoId, teSupino, new[] { SerieCorpo(1, 30, 10) });

        var del = await client.DeleteAsync($"/api/v1/sessoes/{sessaoId}");
        Assert.Equal(HttpStatusCode.NoContent, del.StatusCode);

        var get = await client.GetAsync($"/api/v1/sessoes/{sessaoId}");
        Assert.Equal(HttpStatusCode.NotFound, get.StatusCode);

        await using var db = _postgres.CriarContexto();
        Assert.False(await db.Sessoes.AnyAsync(s => s.Id == sessaoId));
        Assert.False(await db.SeriesExecutadas.AnyAsync(s => s.SessaoId == sessaoId));
    }

    [Fact]
    public async Task Ver_sessao_de_outro_usuario_responde_404()
    {
        var (apiA, clientA, _) = Autenticar(_postgres);
        await using var _apiA = apiA;
        var treinoId = await CriarFicha(clientA);
        var teSupino = await AddExercicio(clientA, treinoId, SupinoReto);
        var sessaoId = await CriarSessao(clientA, treinoId, teSupino, new[] { SerieCorpo(1, 30, 10) });

        var (apiB, clientB, _) = Autenticar(_postgres);
        await using var _apiB = apiB;
        var resposta = await clientB.GetAsync($"/api/v1/sessoes/{sessaoId}");

        Assert.Equal(HttpStatusCode.NotFound, resposta.StatusCode);
    }

    [Fact]
    public async Task Excluir_sessao_de_outro_usuario_responde_404()
    {
        var (apiA, clientA, _) = Autenticar(_postgres);
        await using var _apiA = apiA;
        var treinoId = await CriarFicha(clientA);
        var teSupino = await AddExercicio(clientA, treinoId, SupinoReto);
        var sessaoId = await CriarSessao(clientA, treinoId, teSupino, new[] { SerieCorpo(1, 30, 10) });

        var (apiB, clientB, _) = Autenticar(_postgres);
        await using var _apiB = apiB;
        var resposta = await clientB.DeleteAsync($"/api/v1/sessoes/{sessaoId}");
        Assert.Equal(HttpStatusCode.NotFound, resposta.StatusCode);

        // A sessão continua intacta para o dono.
        var aindaExiste = await clientA.GetAsync($"/api/v1/sessoes/{sessaoId}");
        Assert.Equal(HttpStatusCode.OK, aindaExiste.StatusCode);
    }

    [Fact]
    public async Task Ver_sessao_inexistente_responde_404()
    {
        var (api, client, _) = Autenticar(_postgres);
        await using var _api = api;

        var resposta = await client.GetAsync($"/api/v1/sessoes/{Guid.NewGuid()}");

        Assert.Equal(HttpStatusCode.NotFound, resposta.StatusCode);
    }

    [Fact]
    public async Task Sem_token_responde_401()
    {
        await using var api = new ApiFactory(_postgres.ConnectionString);
        var client = api.CreateClient();

        var resposta = await client.GetAsync($"/api/v1/sessoes/{Guid.NewGuid()}");

        Assert.Equal(HttpStatusCode.Unauthorized, resposta.StatusCode);
    }
}
