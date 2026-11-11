using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using DiarioTreino.IntegrationTests.Infraestrutura;

namespace DiarioTreino.IntegrationTests;

/// <summary>
/// PBI-94: GET /me/medidas/{tipo}/evolucao. Pontos em ordem de data, período com
/// limites inclusive, só do tipo pedido e só do dono; sem registro é lista vazia
/// (não erro); tipo inválido e período invertido são 400.
/// </summary>
[Collection(PostgresCollection.Nome)]
public sealed class MedidaEvolucaoEndpointTests
{
    private readonly PostgresFixture _postgres;

    public MedidaEvolucaoEndpointTests(PostgresFixture postgres)
    {
        _postgres = postgres;
    }

    private sealed record Conta(ApiFactory Api, HttpClient Client);
    private sealed record PontoResposta(string Data, decimal Valor);
    private sealed record EvolucaoResposta(
        string Tipo,
        string Unidade,
        List<PontoResposta> Pontos,
        PontoResposta? Primeira,
        PontoResposta? Ultima,
        decimal? Variacao);

    private static Conta NovoUsuario(PostgresFixture pg)
    {
        var api = new ApiFactory(pg.ConnectionString);
        var client = api.CreateClient();
        var uid = $"uid-{Guid.NewGuid():n}";
        var token = api.Tokens.Gerar(uid, email: $"{uid}@teste.local", nome: "Pessoa");
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
        return new Conta(api, client);
    }

    private static string Dia(int diasAtras = 0) =>
        DateOnly.FromDateTime(DateTime.UtcNow).AddDays(-diasAtras).ToString("yyyy-MM-dd");

    // Dicionário: as chaves dos tipos (CINTURA) não podem ir em camelCase.
    private static Task<HttpResponseMessage> Salvar(HttpClient c, string data, string tipo, double valor) =>
        c.PutAsJsonAsync($"/api/v1/me/medidas/{data}", new
        {
            valores = new Dictionary<string, double?> { [tipo] = valor },
        });

    private static async Task<EvolucaoResposta> Evolucao(HttpClient c, string tipo, string? query = null)
    {
        var resposta = await c.GetAsync($"/api/v1/me/medidas/{tipo}/evolucao{query}");
        resposta.EnsureSuccessStatusCode();
        return (await resposta.Content.ReadFromJsonAsync<EvolucaoResposta>())!;
    }

    [Fact]
    public async Task Devolve_os_pontos_em_ordem_de_data_com_primeira_ultima_e_variacao()
    {
        var a = NovoUsuario(_postgres);
        await using var _a = a.Api;
        // Gravados fora de ordem: a resposta vem sempre por data.
        await Salvar(a.Client, Dia(), "CINTURA", 84.0);
        await Salvar(a.Client, Dia(90), "CINTURA", 87.0);
        await Salvar(a.Client, Dia(30), "CINTURA", 85.5);

        var e = await Evolucao(a.Client, "CINTURA");

        Assert.Equal("CINTURA", e.Tipo);
        Assert.Equal("cm", e.Unidade);
        Assert.Equal([Dia(90), Dia(30), Dia()], e.Pontos.Select(p => p.Data));
        Assert.Equal([87.0m, 85.5m, 84.0m], e.Pontos.Select(p => p.Valor));
        Assert.Equal(Dia(90), e.Primeira!.Data);
        Assert.Equal(84.0m, e.Ultima!.Valor);
        Assert.Equal(-3.0m, e.Variacao);
    }

    [Fact]
    public async Task O_peso_usa_a_mesma_rota_em_kg()
    {
        var a = NovoUsuario(_postgres);
        await using var _a = a.Api;
        await Salvar(a.Client, Dia(10), "PESO", 80.0);
        await Salvar(a.Client, Dia(), "PESO", 78.5);

        var e = await Evolucao(a.Client, "PESO");

        Assert.Equal("kg", e.Unidade);
        Assert.Equal(-1.5m, e.Variacao);
    }

    [Fact]
    public async Task So_devolve_o_tipo_pedido()
    {
        var a = NovoUsuario(_postgres);
        await using var _a = a.Api;
        await Salvar(a.Client, Dia(), "CINTURA", 84.0);
        await Salvar(a.Client, Dia(), "PEITO", 100.0);

        var e = await Evolucao(a.Client, "PEITO");

        Assert.Equal(100.0m, Assert.Single(e.Pontos).Valor);
    }

    [Fact]
    public async Task O_periodo_tem_limites_inclusive()
    {
        var a = NovoUsuario(_postgres);
        await using var _a = a.Api;
        await Salvar(a.Client, Dia(60), "CINTURA", 90.0);
        await Salvar(a.Client, Dia(30), "CINTURA", 88.0);
        await Salvar(a.Client, Dia(10), "CINTURA", 86.0);
        await Salvar(a.Client, Dia(), "CINTURA", 84.0);

        var e = await Evolucao(a.Client, "CINTURA", $"?de={Dia(30)}&ate={Dia(10)}");
        Assert.Equal([88.0m, 86.0m], e.Pontos.Select(p => p.Valor));
        Assert.Equal(-2.0m, e.Variacao);

        // Só "de": do dia até hoje. Só "ate": tudo até o dia.
        Assert.Equal(2, (await Evolucao(a.Client, "CINTURA", $"?de={Dia(10)}")).Pontos.Count);
        Assert.Equal(2, (await Evolucao(a.Client, "CINTURA", $"?ate={Dia(30)}")).Pontos.Count);
    }

    [Fact]
    public async Task Um_registro_tem_primeira_igual_a_ultima_e_sem_variacao()
    {
        var a = NovoUsuario(_postgres);
        await using var _a = a.Api;
        await Salvar(a.Client, Dia(), "CINTURA", 84.0);

        var e = await Evolucao(a.Client, "CINTURA");

        Assert.Single(e.Pontos);
        Assert.Equal(e.Primeira, e.Ultima);
        Assert.Null(e.Variacao);
    }

    [Fact]
    public async Task Sem_registro_no_periodo_a_lista_e_vazia_e_nao_e_erro()
    {
        var a = NovoUsuario(_postgres);
        await using var _a = a.Api;
        await Salvar(a.Client, Dia(60), "CINTURA", 90.0);

        var semNada = await Evolucao(a.Client, "OMBROS");
        Assert.Empty(semNada.Pontos);
        Assert.Null(semNada.Primeira);
        Assert.Null(semNada.Ultima);
        Assert.Null(semNada.Variacao);

        var foraDoPeriodo = await Evolucao(a.Client, "CINTURA", $"?de={Dia(10)}");
        Assert.Empty(foraDoPeriodo.Pontos);
    }

    [Fact]
    public async Task Tipo_invalido_e_periodo_invertido_respondem_400()
    {
        var a = NovoUsuario(_postgres);
        await using var _a = a.Api;

        Assert.Equal(HttpStatusCode.BadRequest,
            (await a.Client.GetAsync("/api/v1/me/medidas/COTOVELO/evolucao")).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest,
            (await a.Client.GetAsync($"/api/v1/me/medidas/PESO/evolucao?de={Dia()}&ate={Dia(5)}")).StatusCode);
    }

    [Fact]
    public async Task Sem_token_responde_401()
    {
        var api = new ApiFactory(_postgres.ConnectionString);
        await using var _a = api;
        var client = api.CreateClient();

        Assert.Equal(HttpStatusCode.Unauthorized,
            (await client.GetAsync("/api/v1/me/medidas/PESO/evolucao")).StatusCode);
    }

    [Fact]
    public async Task Outro_usuario_nao_ve_a_evolucao_do_dono()
    {
        var a = NovoUsuario(_postgres);
        var b = NovoUsuario(_postgres);
        await using var _a = a.Api;
        await using var _b = b.Api;
        await Salvar(a.Client, Dia(10), "CINTURA", 90.0);
        await Salvar(a.Client, Dia(), "CINTURA", 84.0);

        // B só alcança o que é dele: a série de A não aparece.
        Assert.Empty((await Evolucao(b.Client, "CINTURA")).Pontos);

        await Salvar(b.Client, Dia(), "CINTURA", 70.0);
        var deB = await Evolucao(b.Client, "CINTURA");
        Assert.Equal(70.0m, Assert.Single(deB.Pontos).Valor);
        Assert.Equal(2, (await Evolucao(a.Client, "CINTURA")).Pontos.Count);
    }
}