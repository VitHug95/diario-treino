using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using DiarioTreino.IntegrationTests.Infraestrutura;
using Microsoft.EntityFrameworkCore;

namespace DiarioTreino.IntegrationTests;

/// <summary>
/// PBI-102: treino com bloco conjugado. O rascunho traz o bloco; a sessão grava
/// uma série por exercício, ligada ao exercício certo, com o número do bloco e a
/// posição nele, e o descanso só na última série de cada rodada.
/// </summary>
[Collection(PostgresCollection.Nome)]
public sealed class SessaoBlocoEndpointTests
{
    private readonly PostgresFixture _postgres;

    public SessaoBlocoEndpointTests(PostgresFixture postgres)
    {
        _postgres = postgres;
    }

    private sealed record PlanoResp(Guid Id);
    private sealed record CriadoResp(Guid Id);
    private sealed record SerieRascunhoResp(short Rodada, short? DescansoSeg);
    private sealed record ExRascunhoResp(Guid TreinoExercicioId, Guid ExercicioId, Guid? BlocoId, List<SerieRascunhoResp> Series);
    private sealed record BlocoResp(Guid Id, short? DescansoSeg, List<Guid> TreinoExercicioIds, short Rodadas);
    private sealed record RascunhoResp(Guid TreinoId, List<ExRascunhoResp> Exercicios, List<BlocoResp> Blocos);
    private sealed record SerieDetResp(short Rodada, short? DescansoSeg, short? Bloco, short? PosicaoNoBloco);
    private sealed record ExDetResp(Guid ExercicioId, Guid? TreinoExercicioId, List<SerieDetResp> Series);
    private sealed record SessaoDetResp(Guid Id, List<ExDetResp> Exercicios);

    private const short CargaKg = 1;
    private const short Repeticoes = 10;

    private static (ApiFactory Api, HttpClient Client) Autenticar(PostgresFixture pg)
    {
        var api = new ApiFactory(pg.ConnectionString);
        var client = api.CreateClient();
        var uid = $"uid-{Guid.NewGuid():n}";
        var token = api.Tokens.Gerar(uid, email: $"{uid}@teste.local", nome: "Atleta");
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
        return (api, client);
    }

    private async Task<List<Guid>> ExerciciosDoSeed(int quantos)
    {
        await using var db = _postgres.CriarContexto();
        return await db.Exercicios
            .Where(e => e.CriadoPorId == null && e.Ativo)
            .OrderBy(e => e.Id)
            .Select(e => e.Id)
            .Take(quantos)
            .ToListAsync();
    }

    /// <summary>Ficha com adução (3) + agachamento (3) num bloco de 30 s e um avulso.</summary>
    private async Task<(Guid TreinoId, List<Guid> Tes, List<Guid> Exs, Guid BlocoId)> MontarItem2(HttpClient c)
    {
        var plano = await (await c.PostAsync("/api/v1/planos", null)).Content.ReadFromJsonAsync<PlanoResp>();
        var ficha = await (await c.PostAsJsonAsync($"/api/v1/planos/{plano!.Id}/treinos",
            new { nome = "Mobilidade", descricao = (string?)null })).Content.ReadFromJsonAsync<CriadoResp>();
        var exs = await ExerciciosDoSeed(3);
        var tes = new List<Guid>();
        foreach (var exercicioId in exs)
        {
            var r = await c.PostAsJsonAsync($"/api/v1/treinos/{ficha!.Id}/exercicios", new { exercicioId });
            tes.Add((await r.Content.ReadFromJsonAsync<CriadoResp>())!.Id);
        }
        foreach (var te in tes)
        {
            (await c.PutAsJsonAsync($"/api/v1/treinos/{ficha!.Id}/exercicios/{te}/alvos", new
            {
                series = 3,
                intensidadeMetricaId = CargaKg,
                intensidadeAlvo = 20,
                volumeMetricaId = Repeticoes,
                volumeAlvo = 15,
                descansoSeg = 60,
            })).EnsureSuccessStatusCode();
        }
        var bloco = await c.PostAsJsonAsync($"/api/v1/treinos/{ficha!.Id}/blocos",
            new { treinoExercicioIds = new[] { tes[0], tes[1] }, descansoSeg = 30 });
        var blocoId = (await bloco.Content.ReadFromJsonAsync<CriadoResp>())!.Id;
        return (ficha.Id, tes, exs, blocoId);
    }

    private static object Serie(short rodada, short? descanso, short? bloco, short? posicao) => new
    {
        rodada,
        ordem = (short)1,
        tipo = "ESFORCO",
        intensidadeMetricaId = CargaKg,
        intensidade = 20m,
        volumeMetricaId = Repeticoes,
        volume = 15m,
        descansoSeg = descanso,
        bloco,
        posicaoNoBloco = posicao,
    };

    [Fact]
    public async Task Rascunho_traz_o_bloco_e_o_bloco_de_cada_exercicio()
    {
        var (api, c) = Autenticar(_postgres);
        await using var _a = api;
        var (treinoId, tes, _, blocoId) = await MontarItem2(c);

        var r = await c.GetFromJsonAsync<RascunhoResp>($"/api/v1/treinos/{treinoId}/rascunho-sessao");

        var bloco = Assert.Single(r!.Blocos);
        Assert.Equal(blocoId, bloco.Id);
        Assert.Equal((short)30, bloco.DescansoSeg);
        Assert.Equal((short)3, bloco.Rodadas);
        Assert.Equal(new[] { tes[0], tes[1] }, bloco.TreinoExercicioIds);
        Assert.Equal(blocoId, r.Exercicios.Single(e => e.TreinoExercicioId == tes[0]).BlocoId);
        Assert.Null(r.Exercicios.Single(e => e.TreinoExercicioId == tes[2]).BlocoId);
    }

    [Fact]
    public async Task Rascunho_de_ficha_sem_bloco_traz_lista_vazia()
    {
        var (api, c) = Autenticar(_postgres);
        await using var _a = api;
        var (treinoId, _, _, blocoId) = await MontarItem2(c);
        (await c.DeleteAsync($"/api/v1/treinos/{treinoId}/blocos/{blocoId}")).EnsureSuccessStatusCode();

        var r = await c.GetFromJsonAsync<RascunhoResp>($"/api/v1/treinos/{treinoId}/rascunho-sessao");

        Assert.Empty(r!.Blocos);
        Assert.All(r.Exercicios, e => Assert.Null(e.BlocoId));
    }

    [Fact]
    public async Task Sessao_com_bloco_grava_uma_serie_por_exercicio_e_o_descanso_so_na_ultima_da_rodada()
    {
        var (api, c) = Autenticar(_postgres);
        await using var _a = api;
        var (treinoId, tes, exs, _) = await MontarItem2(c);
        var hoje = DateOnly.FromDateTime(DateTime.UtcNow.Date);

        var criar = await c.PostAsJsonAsync("/api/v1/sessoes", new
        {
            treinoId,
            data = hoje,
            exercicios = new object[]
            {
                // Adução: primeira do bloco, sem descanso.
                new
                {
                    exercicioId = exs[0],
                    treinoExercicioId = tes[0],
                    series = new[] { Serie(1, null, 1, 1), Serie(2, null, 1, 1), Serie(3, null, 1, 1) },
                },
                // Agachamento: fecha cada rodada com o descanso do bloco.
                new
                {
                    exercicioId = exs[1],
                    treinoExercicioId = tes[1],
                    series = new[] { Serie(1, 30, 1, 2), Serie(2, 30, 1, 2), Serie(3, 30, 1, 2) },
                },
                // Avulso, como sempre.
                new
                {
                    exercicioId = exs[2],
                    treinoExercicioId = tes[2],
                    series = new[] { Serie(1, 60, null, null) },
                },
            },
        });
        Assert.Equal(HttpStatusCode.Created, criar.StatusCode);
        var sessaoId = (await criar.Content.ReadFromJsonAsync<CriadoResp>())!.Id;

        var det = await c.GetFromJsonAsync<SessaoDetResp>($"/api/v1/sessoes/{sessaoId}");
        var aducao = det!.Exercicios.Single(e => e.ExercicioId == exs[0]);
        var agacha = det.Exercicios.Single(e => e.ExercicioId == exs[1]);
        var avulso = det.Exercicios.Single(e => e.ExercicioId == exs[2]);

        // Ligadas ao exercício certo da ficha.
        Assert.Equal(tes[0], aducao.TreinoExercicioId);
        Assert.Equal(tes[1], agacha.TreinoExercicioId);
        Assert.Equal(3, aducao.Series.Count);
        Assert.Equal(3, agacha.Series.Count);

        Assert.All(aducao.Series, s =>
        {
            Assert.Null(s.DescansoSeg);
            Assert.Equal((short)1, s.Bloco);
            Assert.Equal((short)1, s.PosicaoNoBloco);
        });
        Assert.All(agacha.Series, s =>
        {
            Assert.Equal((short)30, s.DescansoSeg);
            Assert.Equal((short)2, s.PosicaoNoBloco);
        });
        Assert.All(avulso.Series, s =>
        {
            Assert.Null(s.Bloco);
            Assert.Null(s.PosicaoNoBloco);
        });

        // No banco também.
        await using var db = _postgres.CriarContexto();
        var noBanco = await db.SeriesExecutadas.Where(s => s.SessaoId == sessaoId).ToListAsync();
        Assert.Equal(7, noBanco.Count);
        Assert.Equal(6, noBanco.Count(s => s.Bloco == 1));
    }

    [Fact]
    public async Task Editar_a_sessao_mantem_o_bloco_das_series()
    {
        var (api, c) = Autenticar(_postgres);
        await using var _a = api;
        var (treinoId, tes, exs, _) = await MontarItem2(c);
        var hoje = DateOnly.FromDateTime(DateTime.UtcNow.Date);
        object Corpo(short? descanso) => new
        {
            treinoId,
            data = hoje,
            exercicios = new object[]
            {
                new { exercicioId = exs[0], treinoExercicioId = tes[0], series = new[] { Serie(1, null, 1, 1) } },
                new { exercicioId = exs[1], treinoExercicioId = tes[1], series = new[] { Serie(1, descanso, 1, 2) } },
            },
        };
        var criar = await c.PostAsJsonAsync("/api/v1/sessoes", Corpo(30));
        var sessaoId = (await criar.Content.ReadFromJsonAsync<CriadoResp>())!.Id;

        var editar = await c.PutAsJsonAsync($"/api/v1/sessoes/{sessaoId}", Corpo(45));
        Assert.Equal(HttpStatusCode.NoContent, editar.StatusCode);

        var det = await c.GetFromJsonAsync<SessaoDetResp>($"/api/v1/sessoes/{sessaoId}");
        var agacha = det!.Exercicios.Single(e => e.ExercicioId == exs[1]).Series.Single();
        Assert.Equal((short)45, agacha.DescansoSeg);
        Assert.Equal((short)1, agacha.Bloco);
        Assert.Equal((short)2, agacha.PosicaoNoBloco);
    }

    [Theory]
    [InlineData((short)1, null)]
    [InlineData(null, (short)1)]
    [InlineData((short)0, (short)1)]
    [InlineData((short)1, (short)5)]
    public async Task Bloco_incompleto_ou_fora_da_faixa_responde_400(short? bloco, short? posicao)
    {
        var (api, c) = Autenticar(_postgres);
        await using var _a = api;
        var exs = await ExerciciosDoSeed(1);

        var r = await c.PostAsJsonAsync("/api/v1/sessoes", new
        {
            treinoId = (Guid?)null,
            data = DateOnly.FromDateTime(DateTime.UtcNow.Date),
            exercicios = new object[]
            {
                new { exercicioId = exs[0], treinoExercicioId = (Guid?)null, series = new[] { Serie(1, null, bloco, posicao) } },
            },
        });
        Assert.Equal(HttpStatusCode.BadRequest, r.StatusCode);
    }
}
