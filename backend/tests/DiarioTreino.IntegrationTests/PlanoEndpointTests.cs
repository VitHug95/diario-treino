using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using DiarioTreino.IntegrationTests.Infraestrutura;
using Microsoft.EntityFrameworkCore;

namespace DiarioTreino.IntegrationTests;

[Collection(PostgresCollection.Nome)]
public sealed class PlanoEndpointTests
{
    private readonly PostgresFixture _postgres;

    public PlanoEndpointTests(PostgresFixture postgres)
    {
        _postgres = postgres;
    }

    private sealed record PlanoAtivoResposta(Guid Id, string Nome, List<TreinoResumoResposta> Treinos);
    private sealed record TreinoResumoResposta(Guid Id, string Nome, string? Descricao, short Ordem);
    private sealed record CriadoResposta(Guid Id);

    private static (ApiFactory api, HttpClient client, string uid) Autenticar(PostgresFixture pg)
    {
        var api = new ApiFactory(pg.ConnectionString);
        var client = api.CreateClient();
        var uid = $"uid-{Guid.NewGuid():n}";
        var token = api.Tokens.Gerar(uid, email: $"{uid}@teste.local", nome: "Atleta");
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
        return (api, client, uid);
    }

    private static async Task<Guid> CriarPlano(HttpClient client)
    {
        var resp = await client.PostAsync("/api/v1/planos", content: null);
        resp.EnsureSuccessStatusCode();
        var plano = await resp.Content.ReadFromJsonAsync<PlanoAtivoResposta>();
        return plano!.Id;
    }

    private static Task<HttpResponseMessage> AdicionarFicha(
        HttpClient client, Guid planoId, string nome, string? descricao) =>
        client.PostAsJsonAsync($"/api/v1/planos/{planoId}/treinos",
            new { nome, descricao });

    [Fact]
    public async Task Sem_plano_o_ativo_responde_204()
    {
        var (api, client, _) = Autenticar(_postgres);
        await using var _api = api;

        var resposta = await client.GetAsync("/api/v1/planos/ativo");

        Assert.Equal(HttpStatusCode.NoContent, resposta.StatusCode);
    }

    [Fact]
    public async Task Primeira_ficha_cria_plano_ativo_com_autor_igual_atleta()
    {
        var (api, client, uid) = Autenticar(_postgres);
        await using var _api = api;

        var planoId = await CriarPlano(client);
        var criar = await AdicionarFicha(client, planoId, "A", "Peito e tríceps");
        Assert.Equal(HttpStatusCode.Created, criar.StatusCode);

        var ativo = await client.GetFromJsonAsync<PlanoAtivoResposta>("/api/v1/planos/ativo");
        Assert.NotNull(ativo);
        Assert.Single(ativo!.Treinos);
        Assert.Equal("A", ativo.Treinos[0].Nome);

        // No MVP autor e atleta são a mesma pessoa.
        await using var db = _postgres.CriarContexto();
        var meuId = await db.Usuarios.Where(u => u.FirebaseUid == uid).Select(u => u.Id).SingleAsync();
        var plano = await db.PlanosTreino.SingleAsync(p => p.Id == planoId);
        Assert.Equal(meuId, plano.AutorId);
        Assert.Equal(meuId, plano.AtletaId);
    }

    [Fact]
    public async Task Ordem_das_fichas_e_incremental()
    {
        var (api, client, _) = Autenticar(_postgres);
        await using var _api = api;

        var planoId = await CriarPlano(client);
        await AdicionarFicha(client, planoId, "A", null);
        await AdicionarFicha(client, planoId, "B", null);
        await AdicionarFicha(client, planoId, "C", null);

        var ativo = await client.GetFromJsonAsync<PlanoAtivoResposta>("/api/v1/planos/ativo");
        Assert.Equal(3, ativo!.Treinos.Count);
        Assert.Equal(new short[] { 1, 2, 3 }, ativo.Treinos.Select(t => t.Ordem).ToArray());
    }

    [Fact]
    public async Task Renomear_ficha_atualiza_nome_e_descricao()
    {
        var (api, client, _) = Autenticar(_postgres);
        await using var _api = api;

        var planoId = await CriarPlano(client);
        var criar = await AdicionarFicha(client, planoId, "A", "Peito");
        var treinoId = (await criar.Content.ReadFromJsonAsync<CriadoResposta>())!.Id;

        var editar = await client.PutAsJsonAsync($"/api/v1/treinos/{treinoId}",
            new { nome = "A", descricao = "Peito e tríceps" });
        Assert.Equal(HttpStatusCode.NoContent, editar.StatusCode);

        var ativo = await client.GetFromJsonAsync<PlanoAtivoResposta>("/api/v1/planos/ativo");
        Assert.Equal("Peito e tríceps", ativo!.Treinos.Single().Descricao);
    }

    [Fact]
    public async Task Arquivar_ficha_some_do_plano_mas_nao_e_apagada()
    {
        var (api, client, _) = Autenticar(_postgres);
        await using var _api = api;

        var planoId = await CriarPlano(client);
        var criar = await AdicionarFicha(client, planoId, "A", null);
        var treinoId = (await criar.Content.ReadFromJsonAsync<CriadoResposta>())!.Id;

        var arquivar = await client.DeleteAsync($"/api/v1/treinos/{treinoId}");
        Assert.Equal(HttpStatusCode.NoContent, arquivar.StatusCode);

        // Sumiu do plano ativo...
        var ativo = await client.GetAsync("/api/v1/planos/ativo");
        if (ativo.StatusCode == HttpStatusCode.OK)
        {
            var plano = await ativo.Content.ReadFromJsonAsync<PlanoAtivoResposta>();
            Assert.DoesNotContain(plano!.Treinos, t => t.Id == treinoId);
        }

        // ...mas continua no banco (ativo = false).
        await using var db = _postgres.CriarContexto();
        var treino = await db.Treinos.SingleAsync(t => t.Id == treinoId);
        Assert.False(treino.Ativo);
    }

    [Fact]
    public async Task Editar_ficha_de_outro_usuario_responde_404()
    {
        // Usuário A cria uma ficha.
        var (apiA, clientA, _) = Autenticar(_postgres);
        await using var _apiA = apiA;
        var planoId = await CriarPlano(clientA);
        var criar = await AdicionarFicha(clientA, planoId, "A", null);
        var treinoId = (await criar.Content.ReadFromJsonAsync<CriadoResposta>())!.Id;

        // Usuário B tenta editar a ficha de A.
        var (apiB, clientB, _) = Autenticar(_postgres);
        await using var _apiB = apiB;
        var resposta = await clientB.PutAsJsonAsync($"/api/v1/treinos/{treinoId}",
            new { nome = "X", descricao = (string?)null });

        Assert.Equal(HttpStatusCode.NotFound, resposta.StatusCode);
    }

    [Fact]
    public async Task Arquivar_ficha_de_outro_usuario_responde_404()
    {
        var (apiA, clientA, _) = Autenticar(_postgres);
        await using var _apiA = apiA;
        var planoId = await CriarPlano(clientA);
        var criar = await AdicionarFicha(clientA, planoId, "A", null);
        var treinoId = (await criar.Content.ReadFromJsonAsync<CriadoResposta>())!.Id;

        var (apiB, clientB, _) = Autenticar(_postgres);
        await using var _apiB = apiB;
        var resposta = await clientB.DeleteAsync($"/api/v1/treinos/{treinoId}");

        Assert.Equal(HttpStatusCode.NotFound, resposta.StatusCode);
    }

    [Fact]
    public async Task Sem_token_responde_401()
    {
        await using var api = new ApiFactory(_postgres.ConnectionString);
        var client = api.CreateClient();

        var resposta = await client.GetAsync("/api/v1/planos/ativo");

        Assert.Equal(HttpStatusCode.Unauthorized, resposta.StatusCode);
    }
}
