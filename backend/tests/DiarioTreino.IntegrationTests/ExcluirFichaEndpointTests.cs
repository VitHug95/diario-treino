using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using DiarioTreino.IntegrationTests.Infraestrutura;
using Microsoft.EntityFrameworkCore;

namespace DiarioTreino.IntegrationTests;

/// <summary>
/// Excluir ficha (PBI-36): sem sessões apaga de verdade (itens e etapas em
/// cascata); com sessões arquiva (ativo=false); ficha de outro usuário → 404.
/// </summary>
[Collection(PostgresCollection.Nome)]
public sealed class ExcluirFichaEndpointTests
{
    private readonly PostgresFixture _postgres;

    public ExcluirFichaEndpointTests(PostgresFixture postgres)
    {
        _postgres = postgres;
    }

    private static readonly Guid SupinoReto =
        Guid.Parse("11111111-0000-0000-0000-000000000001");
    private const short CargaKg = 1;
    private const short Repeticoes = 10;

    private sealed record IdResp(Guid Id);

    private static (ApiFactory api, HttpClient client) Autenticar(PostgresFixture pg)
    {
        var api = new ApiFactory(pg.ConnectionString);
        var client = api.CreateClient();
        var uid = $"uid-{Guid.NewGuid():n}";
        var token = api.Tokens.Gerar(uid, email: $"{uid}@teste.local", nome: "Atleta");
        client.DefaultRequestHeaders.Authorization =
            new AuthenticationHeaderValue("Bearer", token);
        return (api, client);
    }

    private static async Task<Guid> CriarFicha(HttpClient client)
    {
        var plano = await (await client.PostAsync("/api/v1/planos", null))
            .Content.ReadFromJsonAsync<IdResp>();
        var criar = await client.PostAsJsonAsync(
            $"/api/v1/planos/{plano!.Id}/treinos",
            new { nome = "A", descricao = (string?)null });
        return (await criar.Content.ReadFromJsonAsync<IdResp>())!.Id;
    }

    private static async Task<Guid> AddExercicio(HttpClient client, Guid treinoId) =>
        (await (await client.PostAsJsonAsync(
                $"/api/v1/treinos/{treinoId}/exercicios",
                new { exercicioId = SupinoReto }))
            .Content.ReadFromJsonAsync<IdResp>())!.Id;

    private static async Task RegistrarSessao(HttpClient client, Guid treinoId, Guid teId)
    {
        var hoje = DateOnly.FromDateTime(DateTime.UtcNow.Date);
        var resp = await client.PostAsJsonAsync("/api/v1/sessoes", new
        {
            treinoId,
            data = hoje,
            duracaoMin = (short?)null,
            observacao = (string?)null,
            exercicios = new[]
            {
                new
                {
                    exercicioId = SupinoReto,
                    treinoExercicioId = teId,
                    series = new[]
                    {
                        new
                        {
                            rodada = (short)1,
                            ordem = (short)1,
                            tipo = "ESFORCO",
                            intensidadeMetricaId = CargaKg,
                            intensidade = 30m,
                            volumeMetricaId = Repeticoes,
                            volume = 10m,
                            descansoSeg = (short?)90,
                        },
                    },
                },
            },
        });
        resp.EnsureSuccessStatusCode();
    }

    [Fact]
    public async Task Ficha_sem_sessoes_e_apagada_de_verdade_com_itens_em_cascata()
    {
        var (api, client) = Autenticar(_postgres);
        await using var _api = api;

        var treinoId = await CriarFicha(client);
        var teId = await AddExercicio(client, treinoId);
        // Define alvos para criar também uma etapa_prescrita, e provar o cascade.
        await client.PutAsJsonAsync(
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

        var resposta = await client.DeleteAsync($"/api/v1/treinos/{treinoId}");
        Assert.Equal(HttpStatusCode.NoContent, resposta.StatusCode);

        await using var db = _postgres.CriarContexto();
        Assert.False(await db.Treinos.AnyAsync(t => t.Id == treinoId));
        Assert.False(await db.TreinoExercicios.AnyAsync(te => te.Id == teId));
        Assert.False(await db.EtapasPrescritas.AnyAsync(e => e.TreinoExercicioId == teId));
    }

    [Fact]
    public async Task Ficha_com_sessoes_e_arquivada_e_some_do_plano_ativo()
    {
        var (api, client) = Autenticar(_postgres);
        await using var _api = api;

        var treinoId = await CriarFicha(client);
        var teId = await AddExercicio(client, treinoId);
        await RegistrarSessao(client, treinoId, teId);

        var resposta = await client.DeleteAsync($"/api/v1/treinos/{treinoId}");
        Assert.Equal(HttpStatusCode.NoContent, resposta.StatusCode);

        await using var db = _postgres.CriarContexto();
        // A ficha continua no banco, mas inativa.
        var treino = await db.Treinos.SingleAsync(t => t.Id == treinoId);
        Assert.False(treino.Ativo);
        // A sessão (histórico) continua.
        Assert.True(await db.Sessoes.AnyAsync(s => s.TreinoId == treinoId));
        // Não aparece mais no plano ativo (só fichas ativas).
        var plano = await client.GetAsync("/api/v1/planos/ativo");
        if (plano.StatusCode == HttpStatusCode.OK)
        {
            var corpo = await plano.Content.ReadFromJsonAsync<PlanoResp>();
            Assert.DoesNotContain(corpo!.Treinos, t => t.Id == treinoId);
        }
    }

    [Fact]
    public async Task Excluir_ficha_de_outro_usuario_responde_404()
    {
        var (apiA, clientA) = Autenticar(_postgres);
        await using var _apiA = apiA;
        var treinoId = await CriarFicha(clientA);

        var (apiB, clientB) = Autenticar(_postgres);
        await using var _apiB = apiB;
        var resposta = await clientB.DeleteAsync($"/api/v1/treinos/{treinoId}");
        Assert.Equal(HttpStatusCode.NotFound, resposta.StatusCode);

        // A ficha continua intacta para o dono.
        await using var db = _postgres.CriarContexto();
        Assert.True(await db.Treinos.AnyAsync(t => t.Id == treinoId && t.Ativo));
    }

    [Fact]
    public async Task Excluir_ficha_sem_token_responde_401()
    {
        await using var api = new ApiFactory(_postgres.ConnectionString);
        var client = api.CreateClient();

        var resposta = await client.DeleteAsync($"/api/v1/treinos/{Guid.NewGuid()}");

        Assert.Equal(HttpStatusCode.Unauthorized, resposta.StatusCode);
    }

    private sealed record PlanoResp(Guid Id, string Nome, List<TreinoResp> Treinos);
    private sealed record TreinoResp(Guid Id, string Nome, string? Descricao, short Ordem);
}
