using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using DiarioTreino.IntegrationTests.Infraestrutura;

namespace DiarioTreino.IntegrationTests;

/// <summary>Evolução por exercício (PBI-20, GET /progresso/exercicios/{id}).</summary>
[Collection(PostgresCollection.Nome)]
public sealed class ProgressoEndpointTests
{
    private readonly PostgresFixture _postgres;

    public ProgressoEndpointTests(PostgresFixture postgres)
    {
        _postgres = postgres;
    }

    private sealed record PlanoResp(Guid Id, string Nome, List<object> Treinos);
    private sealed record CriadoResp(Guid Id);
    private sealed record ProgressoResp(
        Guid ExercicioId, string Nome, string Modalidade, string? Metrica,
        List<PontoResp> Pontos, ResumoResp Resumo);
    private sealed record PontoResp(
        DateOnly Data, decimal Valor, decimal? Repeticoes, Guid SessaoId, string? Observacao);
    private sealed record ResumoResp(int Sessoes, decimal? Variacao, int SessoesComObservacao);

    // Seed: supino (força, carga×reps) e prancha (isometria, peso corporal×tempo).
    private static readonly Guid SupinoReto = Guid.Parse("11111111-0000-0000-0000-000000000001");
    private static readonly Guid Prancha = Guid.Parse("22222222-0000-0000-0000-000000000001");
    private const short CargaKg = 1;
    private const short PesoCorporal = 2;
    private const short Repeticoes = 10;
    private const short TempoSeg = 11;

    private static (ApiFactory api, HttpClient client, string uid) Autenticar(PostgresFixture pg)
    {
        var api = new ApiFactory(pg.ConnectionString);
        var client = api.CreateClient();
        var uid = $"uid-{Guid.NewGuid():n}";
        var token = api.Tokens.Gerar(uid, email: $"{uid}@teste.local", nome: "Atleta");
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
        return (api, client, uid);
    }

    private static async Task<Guid> CriarFichaComExercicio(HttpClient client, Guid exercicioId)
    {
        var plano = await (await client.PostAsync("/api/v1/planos", null))
            .Content.ReadFromJsonAsync<PlanoResp>();
        var criar = await client.PostAsJsonAsync($"/api/v1/planos/{plano!.Id}/treinos",
            new { nome = "A", descricao = (string?)null });
        var treinoId = (await criar.Content.ReadFromJsonAsync<CriadoResp>())!.Id;
        var teResp = await client.PostAsJsonAsync(
            $"/api/v1/treinos/{treinoId}/exercicios", new { exercicioId });
        var teId = (await teResp.Content.ReadFromJsonAsync<CriadoResp>())!.Id;
        return teId;
    }

    private static object SerieForca(short rodada, decimal carga, decimal reps) => new
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

    private static object SerieIsometria(short rodada, decimal tempo) => new
    {
        rodada,
        ordem = (short)1,
        tipo = "ESFORCO",
        intensidadeMetricaId = PesoCorporal,
        intensidade = (decimal?)null,
        volumeMetricaId = TempoSeg,
        volume = tempo,
        descansoSeg = (short?)60,
    };

    private static async Task CriarSessao(
        HttpClient client, Guid exercicioId, Guid teId, DateOnly data,
        object[] series, string? observacao = null)
    {
        var resp = await client.PostAsJsonAsync("/api/v1/sessoes", new
        {
            treinoId = (Guid?)null,
            data,
            duracaoMin = (short?)null,
            observacao,
            exercicios = new[]
            {
                new { exercicioId, treinoExercicioId = teId, series },
            },
        });
        resp.EnsureSuccessStatusCode();
    }

    [Fact]
    public async Task Forca_usa_maior_carga_por_sessao_com_as_reps_daquela_carga()
    {
        var (api, client, _) = Autenticar(_postgres);
        await using var _api = api;
        var teSupino = await CriarFichaComExercicio(client, SupinoReto);

        var hoje = DateOnly.FromDateTime(DateTime.UtcNow.Date);
        // Sessão antiga: duas séries, a de maior carga é 30 kg × 10.
        await CriarSessao(client, SupinoReto, teSupino, hoje.AddDays(-7),
            [SerieForca(1, 20, 12), SerieForca(2, 30, 10)]);
        // Sessão recente: a de maior carga é 35 kg × 8 (reps menor, carga maior).
        await CriarSessao(client, SupinoReto, teSupino, hoje,
            [SerieForca(1, 35, 8), SerieForca(2, 30, 11)]);

        var prog = await client.GetFromJsonAsync<ProgressoResp>(
            $"/api/v1/progresso/exercicios/{SupinoReto}");

        Assert.Equal("FORCA", prog!.Modalidade);
        Assert.Equal("CARGA", prog.Metrica);
        Assert.Equal(2, prog.Pontos.Count);
        // Ordem crescente de data.
        Assert.Equal(30m, prog.Pontos[0].Valor);
        Assert.Equal(10m, prog.Pontos[0].Repeticoes);
        // O ponto recente pega a série de MAIOR carga (35), com as reps DELA (8),
        // não a maior reps da sessão (11).
        Assert.Equal(35m, prog.Pontos[1].Valor);
        Assert.Equal(8m, prog.Pontos[1].Repeticoes);
        // Resumo: 2 sessões, variação 35 - 30 = 5.
        Assert.Equal(2, prog.Resumo.Sessoes);
        Assert.Equal(5m, prog.Resumo.Variacao);
    }

    [Fact]
    public async Task Isometria_usa_maior_tempo_por_sessao()
    {
        var (api, client, _) = Autenticar(_postgres);
        await using var _api = api;
        var tePrancha = await CriarFichaComExercicio(client, Prancha);

        var hoje = DateOnly.FromDateTime(DateTime.UtcNow.Date);
        await CriarSessao(client, Prancha, tePrancha, hoje.AddDays(-2),
            [SerieIsometria(1, 30), SerieIsometria(2, 45)], observacao: "Difícil");

        var prog = await client.GetFromJsonAsync<ProgressoResp>(
            $"/api/v1/progresso/exercicios/{Prancha}");

        Assert.Equal("ISOMETRIA", prog!.Modalidade);
        Assert.Equal("TEMPO", prog.Metrica);
        var ponto = Assert.Single(prog.Pontos);
        Assert.Equal(45m, ponto.Valor); // maior tempo
        Assert.Null(ponto.Repeticoes);
        Assert.Equal(1, prog.Resumo.SessoesComObservacao);
        // PBI-21: o ponto carrega o texto da observação e o id da sessão.
        Assert.Equal("Difícil", ponto.Observacao);
        Assert.NotEqual(Guid.Empty, ponto.SessaoId);
    }

    [Fact]
    public async Task Ponto_traz_sessaoId_e_observacao_quando_houver()
    {
        var (api, client, _) = Autenticar(_postgres);
        await using var _api = api;
        var teSupino = await CriarFichaComExercicio(client, SupinoReto);

        var hoje = DateOnly.FromDateTime(DateTime.UtcNow.Date);
        // Mais antiga sem observação; mais recente com observação.
        await CriarSessao(client, SupinoReto, teSupino, hoje.AddDays(-3),
            [SerieForca(1, 40, 8)]);
        await CriarSessao(client, SupinoReto, teSupino, hoje,
            [SerieForca(1, 45, 6)], observacao: "Ombro incomodando");

        var prog = await client.GetFromJsonAsync<ProgressoResp>(
            $"/api/v1/progresso/exercicios/{SupinoReto}");

        Assert.Equal(2, prog!.Pontos.Count);
        // Ordem crescente de data: [0] sem obs, [1] com obs.
        Assert.Null(prog.Pontos[0].Observacao);
        Assert.NotEqual(Guid.Empty, prog.Pontos[0].SessaoId);
        Assert.Equal("Ombro incomodando", prog.Pontos[1].Observacao);
        Assert.NotEqual(Guid.Empty, prog.Pontos[1].SessaoId);
        // Cada ponto tem o id da sua própria sessão (não repete).
        Assert.NotEqual(prog.Pontos[0].SessaoId, prog.Pontos[1].SessaoId);
    }

    [Fact]
    public async Task Filtra_pelo_periodo()
    {
        var (api, client, _) = Autenticar(_postgres);
        await using var _api = api;
        var teSupino = await CriarFichaComExercicio(client, SupinoReto);

        var hoje = DateOnly.FromDateTime(DateTime.UtcNow.Date);
        await CriarSessao(client, SupinoReto, teSupino, hoje, [SerieForca(1, 40, 5)]);
        await CriarSessao(client, SupinoReto, teSupino, hoje.AddDays(-20), [SerieForca(1, 30, 10)]);

        var de = hoje.AddDays(-10);
        var prog = await client.GetFromJsonAsync<ProgressoResp>(
            $"/api/v1/progresso/exercicios/{SupinoReto}?de={de:yyyy-MM-dd}");

        var ponto = Assert.Single(prog!.Pontos);
        Assert.Equal(40m, ponto.Valor);
    }

    [Fact]
    public async Task Nao_considera_sessoes_de_outro_usuario()
    {
        var (apiA, clientA, _) = Autenticar(_postgres);
        await using var _apiA = apiA;
        var teSupino = await CriarFichaComExercicio(clientA, SupinoReto);
        var hoje = DateOnly.FromDateTime(DateTime.UtcNow.Date);
        await CriarSessao(clientA, SupinoReto, teSupino, hoje, [SerieForca(1, 50, 5)]);

        // Usuário B pede o progresso do mesmo exercício (global): só vê o dele (vazio).
        var (apiB, clientB, _) = Autenticar(_postgres);
        await using var _apiB = apiB;
        var prog = await clientB.GetFromJsonAsync<ProgressoResp>(
            $"/api/v1/progresso/exercicios/{SupinoReto}");

        Assert.Empty(prog!.Pontos);
        Assert.Equal(0, prog.Resumo.Sessoes);
    }

    [Fact]
    public async Task Exercicio_inexistente_responde_404()
    {
        var (api, client, _) = Autenticar(_postgres);
        await using var _api = api;

        var resposta = await client.GetAsync($"/api/v1/progresso/exercicios/{Guid.NewGuid()}");

        Assert.Equal(HttpStatusCode.NotFound, resposta.StatusCode);
    }

    [Fact]
    public async Task Sem_token_responde_401()
    {
        await using var api = new ApiFactory(_postgres.ConnectionString);
        var client = api.CreateClient();

        var resposta = await client.GetAsync($"/api/v1/progresso/exercicios/{SupinoReto}");

        Assert.Equal(HttpStatusCode.Unauthorized, resposta.StatusCode);
    }

    // ---- Lista de exercícios com histórico (seletor do gráfico) ----

    private sealed record ExercicioHistResp(Guid Id, string Nome, string Modalidade);

    [Fact]
    public async Task Lista_so_os_exercicios_que_o_atleta_treinou()
    {
        var (api, client, _) = Autenticar(_postgres);
        await using var _api = api;
        var teSupino = await CriarFichaComExercicio(client, SupinoReto);
        var hoje = DateOnly.FromDateTime(DateTime.UtcNow.Date);
        await CriarSessao(client, SupinoReto, teSupino, hoje, [SerieForca(1, 30, 10)]);

        var lista = await client.GetFromJsonAsync<List<ExercicioHistResp>>(
            "/api/v1/progresso/exercicios");

        // Só o supino (o único treinado), não o catálogo inteiro.
        var ex = Assert.Single(lista!);
        Assert.Equal(SupinoReto, ex.Id);
        Assert.Equal("FORCA", ex.Modalidade);
    }

    [Fact]
    public async Task Lista_vazia_quando_o_atleta_nao_treinou_nada()
    {
        var (api, client, _) = Autenticar(_postgres);
        await using var _api = api;

        var lista = await client.GetFromJsonAsync<List<ExercicioHistResp>>(
            "/api/v1/progresso/exercicios");

        Assert.Empty(lista!);
    }

    [Fact]
    public async Task Lista_nao_inclui_exercicios_de_outro_usuario()
    {
        var (apiA, clientA, _) = Autenticar(_postgres);
        await using var _apiA = apiA;
        var teSupino = await CriarFichaComExercicio(clientA, SupinoReto);
        var hoje = DateOnly.FromDateTime(DateTime.UtcNow.Date);
        await CriarSessao(clientA, SupinoReto, teSupino, hoje, [SerieForca(1, 30, 10)]);

        var (apiB, clientB, _) = Autenticar(_postgres);
        await using var _apiB = apiB;
        var listaB = await clientB.GetFromJsonAsync<List<ExercicioHistResp>>(
            "/api/v1/progresso/exercicios");

        Assert.Empty(listaB!);
    }

    [Fact]
    public async Task Lista_sem_token_responde_401()
    {
        await using var api = new ApiFactory(_postgres.ConnectionString);
        var client = api.CreateClient();

        var resposta = await client.GetAsync("/api/v1/progresso/exercicios");

        Assert.Equal(HttpStatusCode.Unauthorized, resposta.StatusCode);
    }
}
