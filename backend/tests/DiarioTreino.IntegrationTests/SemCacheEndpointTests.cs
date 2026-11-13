using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using DiarioTreino.IntegrationTests.Infraestrutura;

namespace DiarioTreino.IntegrationTests;

/// <summary>
/// PBI-100: a ficha não pode mostrar o valor de antes do salvar. Garante (1) que
/// a leitura logo depois do PUT dos alvos já traz o valor novo, várias vezes
/// seguidas, e (2) que nenhuma resposta da API vai para cache (Cache-Control:
/// no-store), inclusive as de erro, para navegador nenhum servir a ficha velha.
/// </summary>
[Collection(PostgresCollection.Nome)]
public sealed class SemCacheEndpointTests
{
    private readonly PostgresFixture _postgres;

    public SemCacheEndpointTests(PostgresFixture postgres)
    {
        _postgres = postgres;
    }

    private sealed record PlanoResp(Guid Id);
    private sealed record CriadoResp(Guid Id);
    private sealed record TeResp(Guid Id, short Rodadas, short? DescansoSeg, string? Instrucao);
    private sealed record FichaResp(Guid Id, List<TeResp> Exercicios);

    private static readonly Guid SupinoReto = Guid.Parse("11111111-0000-0000-0000-000000000001");

    private static (ApiFactory Api, HttpClient Client) Autenticar(PostgresFixture pg)
    {
        var api = new ApiFactory(pg.ConnectionString);
        var client = api.CreateClient();
        var uid = $"uid-{Guid.NewGuid():n}";
        var token = api.Tokens.Gerar(uid, email: $"{uid}@teste.local", nome: "Atleta");
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
        return (api, client);
    }

    private static async Task<(Guid PlanoId, Guid TreinoId, Guid TeId)> MontarFicha(HttpClient client)
    {
        var plano = await (await client.PostAsync("/api/v1/planos", null))
            .Content.ReadFromJsonAsync<PlanoResp>();
        var ficha = await (await client.PostAsJsonAsync($"/api/v1/planos/{plano!.Id}/treinos",
            new { nome = "A", descricao = (string?)null })).Content.ReadFromJsonAsync<CriadoResp>();
        var te = await (await client.PostAsJsonAsync($"/api/v1/treinos/{ficha!.Id}/exercicios",
            new { exercicioId = SupinoReto })).Content.ReadFromJsonAsync<CriadoResp>();
        return (plano.Id, ficha.Id, te!.Id);
    }

    private static Task<HttpResponseMessage> DefinirSeries(
        HttpClient c, Guid treinoId, Guid teId, int series, int? descanso = null, string? instrucao = null) =>
        c.PutAsJsonAsync($"/api/v1/treinos/{treinoId}/exercicios/{teId}/alvos", new
        {
            series,
            intensidadeMetricaId = 1,
            volumeMetricaId = 10,
            descansoSeg = descanso,
            instrucao,
        });

    private static void AssertSemCache(HttpResponseMessage resposta)
    {
        Assert.True(resposta.Headers.CacheControl?.NoStore, $"{resposta.RequestMessage?.RequestUri}: sem no-store");
        Assert.Contains("no-cache", resposta.Headers.Pragma.Select(p => p.Name));
    }

    [Fact]
    public async Task Leitura_logo_depois_do_put_dos_alvos_ja_traz_o_valor_novo()
    {
        var (api, client) = Autenticar(_postgres);
        await using var _a = api;
        var (_, treinoId, teId) = await MontarFicha(client);

        var antes = await client.GetFromJsonAsync<FichaResp>($"/api/v1/treinos/{treinoId}");
        Assert.Equal((short)1, antes!.Exercicios.Single().Rodadas); // nasce com 1

        // Várias gravações seguidas, cada uma lida na hora: nunca o valor anterior.
        foreach (var (series, descanso, instrucao) in new[] { (4, 90, "devagar"), (2, 60, "rápido"), (5, 120, "pausa") })
        {
            Assert.Equal(HttpStatusCode.NoContent,
                (await DefinirSeries(client, treinoId, teId, series, descanso, instrucao)).StatusCode);
            var ficha = await client.GetFromJsonAsync<FichaResp>($"/api/v1/treinos/{treinoId}");
            var te = ficha!.Exercicios.Single();
            Assert.Equal((short)series, te.Rodadas);
            Assert.Equal((short)descanso, te.DescansoSeg);
            Assert.Equal(instrucao, te.Instrucao);
        }
    }

    [Fact]
    public async Task Leituras_autenticadas_respondem_sem_cache()
    {
        var (api, client) = Autenticar(_postgres);
        await using var _a = api;
        var (planoId, treinoId, teId) = await MontarFicha(client);
        await DefinirSeries(client, treinoId, teId, 4);

        foreach (var rota in new[]
        {
            $"/api/v1/treinos/{treinoId}",
            $"/api/v1/planos/{planoId}",
            "/api/v1/planos",
            "/api/v1/planos/ativo",
            "/api/v1/me",
            "/api/v1/me/medidas",
            "/api/v1/sessoes",
        })
        {
            var resposta = await client.GetAsync(rota);
            Assert.True(resposta.IsSuccessStatusCode, $"{rota}: {(int)resposta.StatusCode}");
            AssertSemCache(resposta);
        }
    }

    [Fact]
    public async Task Gravacao_e_erros_tambem_respondem_sem_cache()
    {
        var (api, client) = Autenticar(_postgres);
        await using var _a = api;
        var (_, treinoId, teId) = await MontarFicha(client);

        AssertSemCache(await DefinirSeries(client, treinoId, teId, 4)); // 204
        AssertSemCache(await client.GetAsync($"/api/v1/treinos/{Guid.NewGuid()}")); // 404
        AssertSemCache(await DefinirSeries(client, treinoId, teId, 99)); // 400

        var anonimo = api.CreateClient();
        var semToken = await anonimo.GetAsync($"/api/v1/treinos/{treinoId}");
        Assert.Equal(HttpStatusCode.Unauthorized, semToken.StatusCode);
        AssertSemCache(semToken); // 401
    }
}