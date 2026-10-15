using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using DiarioTreino.IntegrationTests.Infraestrutura;
using Microsoft.EntityFrameworkCore;

namespace DiarioTreino.IntegrationTests;

[Collection(PostgresCollection.Nome)]
public sealed class SessaoEndpointTests
{
    private readonly PostgresFixture _postgres;

    public SessaoEndpointTests(PostgresFixture postgres)
    {
        _postgres = postgres;
    }

    private sealed record PlanoResp(Guid Id, string Nome, List<object> Treinos);
    private sealed record CriadoResp(Guid Id);
    private sealed record RascunhoResp(
        Guid TreinoId, string TreinoNome, DateOnly Data, List<RascunhoExResp> Exercicios);
    private sealed record RascunhoExResp(
        Guid TreinoExercicioId, Guid ExercicioId, string Nome,
        string Modalidade, short Ordem, string? OrigemPreenchimento, List<SerieRascunhoResp> Series);
    private sealed record SerieRascunhoResp(
        short Rodada, short Ordem, string Tipo,
        short IntensidadeMetricaId, string IntensidadeMetricaCodigo, string IntensidadeMetricaNome,
        decimal? Intensidade,
        short VolumeMetricaId, string VolumeMetricaCodigo, string VolumeMetricaNome, decimal? Volume,
        short? DescansoSeg);

    // Exercício global do seed.
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

    [Fact]
    public async Task Rascunho_sem_historico_vem_dos_alvos_da_ficha()
    {
        var (api, client, _) = Autenticar(_postgres);
        await using var _api = api;
        var treinoId = await CriarFicha(client);
        var teId = await AddExercicio(client, treinoId, SupinoReto);
        await DefinirAlvos(client, treinoId, teId);

        var rascunho = await client.GetFromJsonAsync<RascunhoResp>(
            $"/api/v1/treinos/{treinoId}/rascunho-sessao");

        Assert.Equal(treinoId, rascunho!.TreinoId);
        Assert.Equal(DateOnly.FromDateTime(DateTime.UtcNow.Date), rascunho.Data);
        var ex = Assert.Single(rascunho.Exercicios);
        Assert.Equal("Preenchido com os alvos da ficha", ex.OrigemPreenchimento);
        // 3 rodadas × 1 etapa de esforço.
        Assert.Equal(3, ex.Series.Count);
        Assert.All(ex.Series, s => Assert.Equal("ESFORCO", s.Tipo));
        Assert.All(ex.Series, s => Assert.Equal(30m, s.Intensidade));
        Assert.All(ex.Series, s => Assert.Equal(10m, s.Volume));
        Assert.All(ex.Series, s => Assert.Equal((short)90, s.DescansoSeg));
        Assert.Equal(new short[] { 1, 2, 3 }, ex.Series.Select(s => s.Rodada).ToArray());
    }

    [Fact]
    public async Task Rascunho_sem_alvos_e_sem_historico_abre_com_uma_serie_em_branco()
    {
        // PBI-33: antes vinha sem séries e abria tudo como "não realizado",
        // gerando sessão vazia. Agora abre com 1 série em branco das métricas
        // padrão do exercício (Supino reto = CARGA_KG + REPETICOES no seed).
        var (api, client, _) = Autenticar(_postgres);
        await using var _api = api;
        var treinoId = await CriarFicha(client);
        await AddExercicio(client, treinoId, SupinoReto); // sem DefinirAlvos

        var rascunho = await client.GetFromJsonAsync<RascunhoResp>(
            $"/api/v1/treinos/{treinoId}/rascunho-sessao");

        var ex = Assert.Single(rascunho!.Exercicios);
        Assert.Null(ex.OrigemPreenchimento);
        var serie = Assert.Single(ex.Series);
        Assert.Equal("ESFORCO", serie.Tipo);
        Assert.Equal((short)1, serie.Rodada);
        Assert.Equal(CargaKg, serie.IntensidadeMetricaId);
        Assert.Equal(Repeticoes, serie.VolumeMetricaId);
        // Em branco: sem valores preenchidos.
        Assert.Null(serie.Intensidade);
        Assert.Null(serie.Volume);
    }

    [Fact]
    public async Task Rascunho_com_historico_vem_da_ultima_sessao()
    {
        var (api, client, _) = Autenticar(_postgres);
        await using var _api = api;
        var treinoId = await CriarFicha(client);
        var teId = await AddExercicio(client, treinoId, SupinoReto);
        await DefinirAlvos(client, treinoId, teId); // alvos: 3×10 com 30 kg

        // Registra uma sessão com carga maior (35 kg, 8 reps) ontem.
        var ontem = DateOnly.FromDateTime(DateTime.UtcNow.Date).AddDays(-1);
        var criar = await client.PostAsJsonAsync("/api/v1/sessoes", new
        {
            treinoId,
            data = ontem,
            duracaoMin = 50,
            observacao = (string?)null,
            exercicios = new[]
            {
                new
                {
                    exercicioId = SupinoReto,
                    treinoExercicioId = teId,
                    series = new[]
                    {
                        new { rodada = (short)1, ordem = (short)1, tipo = "ESFORCO",
                              intensidadeMetricaId = CargaKg, intensidade = 35m,
                              volumeMetricaId = Repeticoes, volume = 8m, descansoSeg = (short?)90 },
                    },
                },
            },
        });
        Assert.Equal(HttpStatusCode.Created, criar.StatusCode);

        // O rascunho agora preenche com o histórico (35 kg × 8), não os alvos.
        var rascunho = await client.GetFromJsonAsync<RascunhoResp>(
            $"/api/v1/treinos/{treinoId}/rascunho-sessao");
        var ex = Assert.Single(rascunho!.Exercicios);
        Assert.StartsWith("Preenchido com o último treino", ex.OrigemPreenchimento);
        var serie = Assert.Single(ex.Series);
        Assert.Equal(35m, serie.Intensidade);
        Assert.Equal(8m, serie.Volume);
    }

    [Fact]
    public async Task Criar_sessao_grava_series_no_banco()
    {
        var (api, client, uid) = Autenticar(_postgres);
        await using var _api = api;
        var treinoId = await CriarFicha(client);
        var teId = await AddExercicio(client, treinoId, SupinoReto);

        var criar = await client.PostAsJsonAsync("/api/v1/sessoes", new
        {
            treinoId,
            data = DateOnly.FromDateTime(DateTime.UtcNow.Date),
            duracaoMin = 45,
            observacao = "Bom treino",
            exercicios = new[]
            {
                new
                {
                    exercicioId = SupinoReto,
                    treinoExercicioId = teId,
                    series = new[]
                    {
                        new { rodada = (short)1, ordem = (short)1, tipo = "ESFORCO",
                              intensidadeMetricaId = CargaKg, intensidade = 30m,
                              volumeMetricaId = Repeticoes, volume = 10m, descansoSeg = (short?)90 },
                        new { rodada = (short)2, ordem = (short)1, tipo = "ESFORCO",
                              intensidadeMetricaId = CargaKg, intensidade = 32m,
                              volumeMetricaId = Repeticoes, volume = 9m, descansoSeg = (short?)90 },
                    },
                },
            },
        });
        Assert.Equal(HttpStatusCode.Created, criar.StatusCode);
        var sessaoId = (await criar.Content.ReadFromJsonAsync<CriadoResp>())!.Id;

        await using var db = _postgres.CriarContexto();
        var meuId = await db.Usuarios.Where(u => u.FirebaseUid == uid).Select(u => u.Id).SingleAsync();
        var sessao = await db.Sessoes.SingleAsync(s => s.Id == sessaoId);
        Assert.Equal(meuId, sessao.AtletaId);
        Assert.Equal(treinoId, sessao.TreinoId);
        Assert.Equal("Bom treino", sessao.Observacao);
        var series = await db.SeriesExecutadas.Where(s => s.SessaoId == sessaoId).ToListAsync();
        Assert.Equal(2, series.Count);
        Assert.All(series, s => Assert.Equal(teId, s.TreinoExercicioId));
    }

    [Fact]
    public async Task Exercicio_sem_series_nao_vira_serie_no_banco()
    {
        var (api, client, _) = Autenticar(_postgres);
        await using var _api = api;
        var treinoId = await CriarFicha(client);
        var teId = await AddExercicio(client, treinoId, SupinoReto);

        var criar = await client.PostAsJsonAsync("/api/v1/sessoes", new
        {
            treinoId,
            data = DateOnly.FromDateTime(DateTime.UtcNow.Date),
            duracaoMin = (short?)null,
            observacao = (string?)null,
            exercicios = new[]
            {
                new
                {
                    exercicioId = SupinoReto,
                    treinoExercicioId = teId,
                    series = Array.Empty<object>(),
                },
            },
        });
        Assert.Equal(HttpStatusCode.Created, criar.StatusCode);
        var sessaoId = (await criar.Content.ReadFromJsonAsync<CriadoResp>())!.Id;

        await using var db = _postgres.CriarContexto();
        var series = await db.SeriesExecutadas.Where(s => s.SessaoId == sessaoId).ToListAsync();
        Assert.Empty(series);
    }

    [Fact]
    public async Task Data_futura_responde_400()
    {
        var (api, client, _) = Autenticar(_postgres);
        await using var _api = api;
        var treinoId = await CriarFicha(client);
        var teId = await AddExercicio(client, treinoId, SupinoReto);

        var daquiTresDias = DateOnly.FromDateTime(DateTime.UtcNow.Date).AddDays(3);
        var criar = await client.PostAsJsonAsync("/api/v1/sessoes", new
        {
            treinoId,
            data = daquiTresDias,
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
                        new { rodada = (short)1, ordem = (short)1, tipo = "ESFORCO",
                              intensidadeMetricaId = CargaKg, intensidade = 30m,
                              volumeMetricaId = Repeticoes, volume = 10m, descansoSeg = (short?)null },
                    },
                },
            },
        });

        Assert.Equal(HttpStatusCode.BadRequest, criar.StatusCode);
    }

    [Fact]
    public async Task Rascunho_de_ficha_de_outro_usuario_responde_404()
    {
        var (apiA, clientA, _) = Autenticar(_postgres);
        await using var _apiA = apiA;
        var treinoId = await CriarFicha(clientA);

        var (apiB, clientB, _) = Autenticar(_postgres);
        await using var _apiB = apiB;
        var resposta = await clientB.GetAsync($"/api/v1/treinos/{treinoId}/rascunho-sessao");

        Assert.Equal(HttpStatusCode.NotFound, resposta.StatusCode);
    }

    [Fact]
    public async Task Criar_sessao_para_ficha_de_outro_usuario_responde_404()
    {
        var (apiA, clientA, _) = Autenticar(_postgres);
        await using var _apiA = apiA;
        var treinoId = await CriarFicha(clientA);
        var teId = await AddExercicio(clientA, treinoId, SupinoReto);

        var (apiB, clientB, _) = Autenticar(_postgres);
        await using var _apiB = apiB;
        var criar = await clientB.PostAsJsonAsync("/api/v1/sessoes", new
        {
            treinoId,
            data = DateOnly.FromDateTime(DateTime.UtcNow.Date),
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
                        new { rodada = (short)1, ordem = (short)1, tipo = "ESFORCO",
                              intensidadeMetricaId = CargaKg, intensidade = 30m,
                              volumeMetricaId = Repeticoes, volume = 10m, descansoSeg = (short?)null },
                    },
                },
            },
        });

        Assert.Equal(HttpStatusCode.NotFound, criar.StatusCode);
    }

    [Fact]
    public async Task Sem_token_responde_401()
    {
        await using var api = new ApiFactory(_postgres.ConnectionString);
        var client = api.CreateClient();

        var resposta = await client.GetAsync($"/api/v1/treinos/{Guid.NewGuid()}/rascunho-sessao");

        Assert.Equal(HttpStatusCode.Unauthorized, resposta.StatusCode);
    }

    // ---------- Histórico do exercício (TV-4) ----------

    private sealed record HistoricoResp(
        Guid ExercicioId, string Nome, string Modalidade, List<SessaoHistResp> Sessoes);
    private sealed record SessaoHistResp(
        Guid SessaoId, DateOnly Data, string? Observacao, List<SerieHistResp> Series);
    private sealed record SerieHistResp(
        short Rodada, short Ordem, string Tipo,
        short IntensidadeMetricaId, decimal? Intensidade,
        short VolumeMetricaId, decimal Volume, short? DescansoSeg, string Marcador);

    private static Task RegistrarSessaoLivre(
        HttpClient client, Guid exercicioId, DateOnly data, decimal carga, decimal reps,
        string? observacao = null) =>
        client.PostAsJsonAsync("/api/v1/sessoes", new
        {
            treinoId = (Guid?)null,
            data,
            duracaoMin = (short?)null,
            observacao,
            exercicios = new[]
            {
                new
                {
                    exercicioId,
                    treinoExercicioId = (Guid?)null,
                    series = new[]
                    {
                        new { rodada = (short)1, ordem = (short)1, tipo = "ESFORCO",
                              intensidadeMetricaId = CargaKg, intensidade = carga,
                              volumeMetricaId = Repeticoes, volume = reps, descansoSeg = (short?)90 },
                    },
                },
            },
        });

    [Fact]
    public async Task Historico_traz_as_tres_ultimas_em_ordem_com_observacao()
    {
        var (api, client, _) = Autenticar(_postgres);
        await using var _api = api;

        var hoje = DateOnly.FromDateTime(DateTime.UtcNow.Date);
        // 4 sessões; a mais antiga deve ficar de fora com limite=3.
        await RegistrarSessaoLivre(client, SupinoReto, hoje.AddDays(-9), 20, 12);
        await RegistrarSessaoLivre(client, SupinoReto, hoje.AddDays(-6), 25, 10);
        await RegistrarSessaoLivre(client, SupinoReto, hoje.AddDays(-3), 30, 8, observacao: "Pesado");
        await RegistrarSessaoLivre(client, SupinoReto, hoje, 32, 7);

        var hist = await client.GetFromJsonAsync<HistoricoResp>(
            $"/api/v1/exercicios/{SupinoReto}/historico?limite=3");

        Assert.Equal(SupinoReto, hist!.ExercicioId);
        Assert.Equal(3, hist.Sessoes.Count);
        // Ordem decrescente de data: hoje, -3, -6.
        Assert.Equal(hoje, hist.Sessoes[0].Data);
        Assert.Equal(hoje.AddDays(-3), hist.Sessoes[1].Data);
        Assert.Equal(hoje.AddDays(-6), hist.Sessoes[2].Data);
        // A observação chega no ponto certo.
        Assert.Equal("Pesado", hist.Sessoes[1].Observacao);
        Assert.Null(hist.Sessoes[0].Observacao);
        // As séries da sessão vêm junto.
        var serie = Assert.Single(hist.Sessoes[0].Series);
        Assert.Equal(32m, serie.Intensidade);
        Assert.Equal(7m, serie.Volume);
    }

    [Fact]
    public async Task Historico_vazio_quando_nunca_treinou_o_exercicio()
    {
        var (api, client, _) = Autenticar(_postgres);
        await using var _api = api;

        var hist = await client.GetFromJsonAsync<HistoricoResp>(
            $"/api/v1/exercicios/{SupinoReto}/historico");

        Assert.Empty(hist!.Sessoes);
    }

    [Fact]
    public async Task Historico_de_exercicio_proprio_de_outro_usuario_responde_404()
    {
        var (apiA, clientA, _) = Autenticar(_postgres);
        await using var _apiA = apiA;
        var criado = await clientA.PostAsJsonAsync("/api/v1/exercicios", new
        {
            nome = $"Secreto hist {Guid.NewGuid():n}",
            membroId = (short)4,
            modalidade = "FORCA",
            intensidadeMetricaId = 1,
            volumeMetricaId = 10,
        });
        criado.EnsureSuccessStatusCode();
        var exId = (await criado.Content.ReadFromJsonAsync<CriadoResp>())!.Id;

        var (apiB, clientB, _) = Autenticar(_postgres);
        await using var _apiB = apiB;
        var resposta = await clientB.GetAsync($"/api/v1/exercicios/{exId}/historico");

        Assert.Equal(HttpStatusCode.NotFound, resposta.StatusCode);
    }

    [Fact]
    public async Task Historico_sem_token_responde_401()
    {
        await using var api = new ApiFactory(_postgres.ConnectionString);
        var client = api.CreateClient();

        var resposta = await client.GetAsync($"/api/v1/exercicios/{SupinoReto}/historico");

        Assert.Equal(HttpStatusCode.Unauthorized, resposta.StatusCode);
    }

    // ---------- Treino livre (PBI-19) ----------

    private sealed record RascunhoAvulsoResp(
        Guid ExercicioId, string Nome, string Modalidade,
        string? OrigemPreenchimento, List<SerieRascunhoResp> Series);

    [Fact]
    public async Task Ultima_execucao_sem_historico_vem_serie_em_branco()
    {
        var (api, client, _) = Autenticar(_postgres);
        await using var _api = api;

        var rascunho = await client.GetFromJsonAsync<RascunhoAvulsoResp>(
            $"/api/v1/exercicios/{SupinoReto}/ultima-execucao");

        Assert.Equal(SupinoReto, rascunho!.ExercicioId);
        Assert.Null(rascunho.OrigemPreenchimento);
        var serie = Assert.Single(rascunho.Series);
        Assert.Equal(CargaKg, serie.IntensidadeMetricaId);
        Assert.Equal(Repeticoes, serie.VolumeMetricaId);
        Assert.Null(serie.Intensidade);
        Assert.Null(serie.Volume);
    }

    [Fact]
    public async Task Ultima_execucao_com_historico_vem_da_ultima_sessao()
    {
        var (api, client, _) = Autenticar(_postgres);
        await using var _api = api;

        // Registra uma sessão de treino livre (sem ficha) com o exercício.
        var ontem = DateOnly.FromDateTime(DateTime.UtcNow.Date).AddDays(-1);
        var criar = await client.PostAsJsonAsync("/api/v1/sessoes", new
        {
            treinoId = (Guid?)null,
            data = ontem,
            duracaoMin = (short?)null,
            observacao = (string?)null,
            exercicios = new[]
            {
                new
                {
                    exercicioId = SupinoReto,
                    treinoExercicioId = (Guid?)null,
                    series = new[]
                    {
                        new { rodada = (short)1, ordem = (short)1, tipo = "ESFORCO",
                              intensidadeMetricaId = CargaKg, intensidade = 42m,
                              volumeMetricaId = Repeticoes, volume = 6m, descansoSeg = (short?)null },
                    },
                },
            },
        });
        Assert.Equal(HttpStatusCode.Created, criar.StatusCode);

        var rascunho = await client.GetFromJsonAsync<RascunhoAvulsoResp>(
            $"/api/v1/exercicios/{SupinoReto}/ultima-execucao");

        Assert.StartsWith("Preenchido com o último treino", rascunho!.OrigemPreenchimento);
        var serie = Assert.Single(rascunho.Series);
        Assert.Equal(42m, serie.Intensidade);
        Assert.Equal(6m, serie.Volume);
    }

    [Fact]
    public async Task Ultima_execucao_de_exercicio_inexistente_responde_404()
    {
        var (api, client, _) = Autenticar(_postgres);
        await using var _api = api;

        var resposta = await client.GetAsync(
            $"/api/v1/exercicios/{Guid.NewGuid()}/ultima-execucao");

        Assert.Equal(HttpStatusCode.NotFound, resposta.StatusCode);
    }

    [Fact]
    public async Task Ultima_execucao_de_exercicio_proprio_de_outro_usuario_responde_404()
    {
        // Exercício próprio do usuário A não é acessível ao usuário B (404).
        var (apiA, clientA, _) = Autenticar(_postgres);
        await using var _apiA = apiA;
        var criado = await clientA.PostAsJsonAsync("/api/v1/exercicios", new
        {
            nome = $"Rosca secreta {Guid.NewGuid():n}",
            membroId = (short)4,
            modalidade = "FORCA",
            intensidadeMetricaId = 1,
            volumeMetricaId = 10,
        });
        criado.EnsureSuccessStatusCode();
        var exId = (await criado.Content.ReadFromJsonAsync<CriadoResp>())!.Id;

        var (apiB, clientB, _) = Autenticar(_postgres);
        await using var _apiB = apiB;
        var resposta = await clientB.GetAsync($"/api/v1/exercicios/{exId}/ultima-execucao");

        Assert.Equal(HttpStatusCode.NotFound, resposta.StatusCode);
    }

    [Fact]
    public async Task Treino_livre_grava_sessao_sem_ficha()
    {
        var (api, client, uid) = Autenticar(_postgres);
        await using var _api = api;

        var criar = await client.PostAsJsonAsync("/api/v1/sessoes", new
        {
            treinoId = (Guid?)null,
            data = DateOnly.FromDateTime(DateTime.UtcNow.Date),
            duracaoMin = 40,
            observacao = (string?)null,
            exercicios = new[]
            {
                new
                {
                    exercicioId = SupinoReto,
                    treinoExercicioId = (Guid?)null,
                    series = new[]
                    {
                        new { rodada = (short)1, ordem = (short)1, tipo = "ESFORCO",
                              intensidadeMetricaId = CargaKg, intensidade = 30m,
                              volumeMetricaId = Repeticoes, volume = 10m, descansoSeg = (short?)null },
                    },
                },
            },
        });
        Assert.Equal(HttpStatusCode.Created, criar.StatusCode);
        var sessaoId = (await criar.Content.ReadFromJsonAsync<CriadoResp>())!.Id;

        await using var db = _postgres.CriarContexto();
        var meuId = await db.Usuarios.Where(u => u.FirebaseUid == uid).Select(u => u.Id).SingleAsync();
        var sessao = await db.Sessoes.SingleAsync(s => s.Id == sessaoId);
        Assert.Equal(meuId, sessao.AtletaId);
        Assert.Null(sessao.TreinoId); // treino livre
        var serie = await db.SeriesExecutadas.SingleAsync(s => s.SessaoId == sessaoId);
        Assert.Null(serie.TreinoExercicioId); // fora da ficha
    }

    [Fact]
    public async Task Salvar_como_ficha_cria_ficha_com_os_exercicios()
    {
        var (api, client, uid) = Autenticar(_postgres);
        await using var _api = api;

        var resp = await client.PostAsJsonAsync("/api/v1/planos/fichas-de-treino", new
        {
            nome = "Treino de hoje",
            descricao = (string?)null,
            exercicioIds = new[] { SupinoReto },
        });
        Assert.Equal(HttpStatusCode.Created, resp.StatusCode);
        var treinoId = (await resp.Content.ReadFromJsonAsync<CriadoResp>())!.Id;

        // A ficha aparece no plano ativo e tem o exercício.
        await using var db = _postgres.CriarContexto();
        var meuId = await db.Usuarios.Where(u => u.FirebaseUid == uid).Select(u => u.Id).SingleAsync();
        var treino = await db.Treinos.SingleAsync(t => t.Id == treinoId);
        Assert.Equal("Treino de hoje", treino.Nome);
        var itens = await db.TreinoExercicios.Where(te => te.TreinoId == treinoId).ToListAsync();
        var item = Assert.Single(itens);
        Assert.Equal(SupinoReto, item.ExercicioId);
    }

    [Fact]
    public async Task Salvar_como_ficha_sem_exercicios_responde_400()
    {
        var (api, client, _) = Autenticar(_postgres);
        await using var _api = api;

        var resp = await client.PostAsJsonAsync("/api/v1/planos/fichas-de-treino", new
        {
            nome = "Vazia",
            descricao = (string?)null,
            exercicioIds = Array.Empty<Guid>(),
        });

        Assert.Equal(HttpStatusCode.BadRequest, resp.StatusCode);
    }

    [Fact]
    public async Task Salvar_como_ficha_com_exercicio_proprio_de_outro_usuario_responde_404()
    {
        // B tenta criar uma ficha incluindo um exercício próprio de A: 404.
        var (apiA, clientA, _) = Autenticar(_postgres);
        await using var _apiA = apiA;
        var criado = await clientA.PostAsJsonAsync("/api/v1/exercicios", new
        {
            nome = $"Exclusivo A {Guid.NewGuid():n}",
            membroId = (short)1,
            modalidade = "FORCA",
            intensidadeMetricaId = 1,
            volumeMetricaId = 10,
        });
        criado.EnsureSuccessStatusCode();
        var exId = (await criado.Content.ReadFromJsonAsync<CriadoResp>())!.Id;

        var (apiB, clientB, _) = Autenticar(_postgres);
        await using var _apiB = apiB;
        var resp = await clientB.PostAsJsonAsync("/api/v1/planos/fichas-de-treino", new
        {
            nome = "Tentando roubar",
            descricao = (string?)null,
            exercicioIds = new[] { exId },
        });

        Assert.Equal(HttpStatusCode.NotFound, resp.StatusCode);
    }
}
