using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using DiarioTreino.Domain.Comum;
using DiarioTreino.Domain.Planejamento;
using DiarioTreino.IntegrationTests.Infraestrutura;
using Microsoft.EntityFrameworkCore;

namespace DiarioTreino.IntegrationTests;

/// <summary>
/// PBI-72: "Manter na ficha?" ao salvar a sessão. POST /sessoes com
/// <c>manterNaFicha</c> grava a sessão e acrescenta o exercício no fim da ficha
/// na mesma transação. Pedido inconsistente responde 400 sem gravar nada; ficha
/// de outro usuário, 404; ficha de plano do professor, 403.
/// </summary>
[Collection(PostgresCollection.Nome)]
public sealed class ManterNaFichaEndpointTests
{
    private readonly PostgresFixture _postgres;

    public ManterNaFichaEndpointTests(PostgresFixture postgres)
    {
        _postgres = postgres;
    }

    private sealed record PlanoResp(Guid Id, string Nome, List<object> Treinos);
    private sealed record CriadoResp(Guid Id);
    private sealed record FichaResp(Guid Id, string Nome, List<object> Exercicios, bool SomenteLeitura);

    // Seed: supino e agachamento (carga × reps); prancha (peso corporal × tempo).
    private static readonly Guid SupinoReto = Guid.Parse("11111111-0000-0000-0000-000000000001");
    private static readonly Guid Agachamento = Guid.Parse("11111111-0000-0000-0000-000000000005");
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

    /// <summary>Ficha "B" com o supino (dentro da ficha).</summary>
    private static async Task<(Guid TreinoId, Guid TeSupino)> CriarFicha(HttpClient client)
    {
        var plano = await (await client.PostAsync("/api/v1/planos", null))
            .Content.ReadFromJsonAsync<PlanoResp>();
        var criar = await client.PostAsJsonAsync($"/api/v1/planos/{plano!.Id}/treinos",
            new { nome = "B", descricao = "Costas" });
        var treinoId = (await criar.Content.ReadFromJsonAsync<CriadoResp>())!.Id;
        var te = await client.PostAsJsonAsync(
            $"/api/v1/treinos/{treinoId}/exercicios", new { exercicioId = SupinoReto });
        return (treinoId, (await te.Content.ReadFromJsonAsync<CriadoResp>())!.Id);
    }

    private static object Serie(short rodada, decimal carga, decimal reps, short? descanso = 60) => new
    {
        rodada, ordem = (short)1, tipo = "ESFORCO",
        intensidadeMetricaId = CargaKg, intensidade = (decimal?)carga,
        volumeMetricaId = Repeticoes, volume = reps, descansoSeg = descanso,
    };

    /// <summary>Sessão com o supino da ficha e o agachamento fora da ficha.</summary>
    private static object Sessao(Guid? treinoId, Guid teSupino, Guid[]? manterNaFicha,
        object[]? seriesAgachamento = null) => new
    {
        treinoId,
        data = DateOnly.FromDateTime(DateTime.UtcNow.Date),
        duracaoMin = (short?)40,
        observacao = (string?)null,
        exercicios = new object[]
        {
            new { exercicioId = SupinoReto, treinoExercicioId = (Guid?)teSupino,
                  series = new[] { Serie(1, 30, 10) } },
            new { exercicioId = Agachamento, treinoExercicioId = (Guid?)null,
                  series = seriesAgachamento ?? new[] { Serie(1, 18, 12), Serie(2, 20, 10, 90) } },
        },
        manterNaFicha,
    };

    private async Task<int> SessoesDoTreino(Guid treinoId)
    {
        await using var db = _postgres.CriarContexto();
        return await db.Sessoes.CountAsync(s => s.TreinoId == treinoId);
    }

    [Fact]
    public async Task Manter_grava_a_sessao_e_poe_o_exercicio_no_fim_da_ficha()
    {
        var (api, client, _) = Autenticar(_postgres);
        await using var _api = api;
        var (treinoId, teSupino) = await CriarFicha(client);

        var resp = await client.PostAsJsonAsync("/api/v1/sessoes",
            Sessao(treinoId, teSupino, [Agachamento]));
        Assert.Equal(HttpStatusCode.Created, resp.StatusCode);
        var sessaoId = (await resp.Content.ReadFromJsonAsync<CriadoResp>())!.Id;

        await using var db = _postgres.CriarContexto();
        var itens = await db.TreinoExercicios
            .Where(te => te.TreinoId == treinoId)
            .Include(te => te.Etapas)
            .OrderBy(te => te.Ordem)
            .ToListAsync();
        Assert.Equal(2, itens.Count);
        var novo = itens[1];
        Assert.Equal(Agachamento, novo.ExercicioId);
        Assert.True(novo.Ordem > itens[0].Ordem); // no fim
        Assert.Equal((short)2, novo.Rodadas);     // 2 séries salvas
        Assert.Equal((short)90, novo.DescansoAlvoSeg);
        var etapa = Assert.Single(novo.Etapas);
        Assert.Equal(TipoEtapa.Esforco, etapa.Tipo);
        Assert.Equal(CargaKg, etapa.IntensidadeMetricaId);
        Assert.Equal(20m, etapa.IntensidadeAlvo); // alvo da última série
        Assert.Equal(Repeticoes, etapa.VolumeMetricaId);
        Assert.Equal(10m, etapa.VolumeAlvo);

        // A sessão é gravada como sempre, e o histórico continua "fora da ficha".
        var series = await db.SeriesExecutadas.Where(s => s.SessaoId == sessaoId).ToListAsync();
        Assert.Equal(3, series.Count);
        Assert.All(series.Where(s => s.ExercicioId == Agachamento),
            s => Assert.Null(s.TreinoExercicioId));
    }

    [Fact]
    public async Task Manter_isometria_usa_o_tempo_da_ultima_serie()
    {
        var (api, client, _) = Autenticar(_postgres);
        await using var _api = api;
        var (treinoId, teSupino) = await CriarFicha(client);

        var resp = await client.PostAsJsonAsync("/api/v1/sessoes", new
        {
            treinoId,
            data = DateOnly.FromDateTime(DateTime.UtcNow.Date),
            duracaoMin = (short?)null,
            observacao = (string?)null,
            exercicios = new object[]
            {
                new { exercicioId = Prancha, treinoExercicioId = (Guid?)null,
                      series = new[]
                      {
                          new { rodada = (short)1, ordem = (short)1, tipo = "ESFORCO",
                                intensidadeMetricaId = PesoCorporal, intensidade = (decimal?)null,
                                volumeMetricaId = TempoSeg, volume = 45m, descansoSeg = (short?)null },
                      } },
            },
            manterNaFicha = new[] { Prancha },
        });
        Assert.Equal(HttpStatusCode.Created, resp.StatusCode);

        await using var db = _postgres.CriarContexto();
        var novo = await db.TreinoExercicios.Include(te => te.Etapas)
            .SingleAsync(te => te.TreinoId == treinoId && te.ExercicioId == Prancha);
        var etapa = Assert.Single(novo.Etapas);
        Assert.Equal(PesoCorporal, etapa.IntensidadeMetricaId);
        Assert.Null(etapa.IntensidadeAlvo);
        Assert.Equal(TempoSeg, etapa.VolumeMetricaId);
        Assert.Equal(45m, etapa.VolumeAlvo);
        Assert.Equal((short)1, novo.Rodadas);
    }

    [Fact]
    public async Task So_neste_treino_nao_muda_a_ficha()
    {
        var (api, client, _) = Autenticar(_postgres);
        await using var _api = api;
        var (treinoId, teSupino) = await CriarFicha(client);

        var resp = await client.PostAsJsonAsync("/api/v1/sessoes",
            Sessao(treinoId, teSupino, manterNaFicha: []));
        Assert.Equal(HttpStatusCode.Created, resp.StatusCode);

        await using var db = _postgres.CriarContexto();
        Assert.Equal(1, await db.TreinoExercicios.CountAsync(te => te.TreinoId == treinoId));
    }

    [Fact]
    public async Task Id_que_nao_e_da_sessao_responde_400_e_nao_grava_nada()
    {
        var (api, client, _) = Autenticar(_postgres);
        await using var _api = api;
        var (treinoId, teSupino) = await CriarFicha(client);

        var resp = await client.PostAsJsonAsync("/api/v1/sessoes",
            Sessao(treinoId, teSupino, [Prancha]));

        Assert.Equal(HttpStatusCode.BadRequest, resp.StatusCode);
        Assert.Equal(0, await SessoesDoTreino(treinoId));
        await using var db = _postgres.CriarContexto();
        Assert.Equal(1, await db.TreinoExercicios.CountAsync(te => te.TreinoId == treinoId));
    }

    [Fact]
    public async Task Exercicio_da_ficha_ou_sem_series_responde_400()
    {
        var (api, client, _) = Autenticar(_postgres);
        await using var _api = api;
        var (treinoId, teSupino) = await CriarFicha(client);

        // O supino já está na ficha (tem treinoExercicioId).
        var daFicha = await client.PostAsJsonAsync("/api/v1/sessoes",
            Sessao(treinoId, teSupino, [SupinoReto]));
        Assert.Equal(HttpStatusCode.BadRequest, daFicha.StatusCode);

        // Agachamento fora da ficha, mas sem série marcada: não é salvo.
        var semSerie = await client.PostAsJsonAsync("/api/v1/sessoes",
            Sessao(treinoId, teSupino, [Agachamento], seriesAgachamento: []));
        Assert.Equal(HttpStatusCode.BadRequest, semSerie.StatusCode);

        Assert.Equal(0, await SessoesDoTreino(treinoId));
    }

    [Fact]
    public async Task Treino_livre_com_manter_responde_400()
    {
        var (api, client, _) = Autenticar(_postgres);
        await using var _api = api;

        var resp = await client.PostAsJsonAsync("/api/v1/sessoes", new
        {
            treinoId = (Guid?)null,
            data = DateOnly.FromDateTime(DateTime.UtcNow.Date),
            duracaoMin = (short?)null,
            observacao = (string?)null,
            exercicios = new object[]
            {
                new { exercicioId = Agachamento, treinoExercicioId = (Guid?)null,
                      series = new[] { Serie(1, 20, 10) } },
            },
            manterNaFicha = new[] { Agachamento },
        });

        Assert.Equal(HttpStatusCode.BadRequest, resp.StatusCode);
    }

    [Fact]
    public async Task Ficha_de_outro_usuario_responde_404()
    {
        var (apiA, clientA, _) = Autenticar(_postgres);
        await using var _apiA = apiA;
        var (treinoId, teSupino) = await CriarFicha(clientA);

        var (apiB, clientB, _) = Autenticar(_postgres);
        await using var _apiB = apiB;
        var resp = await clientB.PostAsJsonAsync("/api/v1/sessoes",
            Sessao(treinoId, teSupino, [Agachamento]));

        Assert.Equal(HttpStatusCode.NotFound, resp.StatusCode);
        await using var db = _postgres.CriarContexto();
        Assert.Equal(1, await db.TreinoExercicios.CountAsync(te => te.TreinoId == treinoId));
    }

    [Fact]
    public async Task Ficha_do_professor_responde_403_e_nao_grava_nada()
    {
        var (api, client, uid) = Autenticar(_postgres);
        await using var _api = api;
        // Provisiona o atleta (o usuário nasce na primeira chamada autenticada).
        (await client.GetAsync("/api/v1/me")).EnsureSuccessStatusCode();
        var treinoId = await InserirFichaDoProfessor(uid);

        var resp = await client.PostAsJsonAsync("/api/v1/sessoes", new
        {
            treinoId,
            data = DateOnly.FromDateTime(DateTime.UtcNow.Date),
            duracaoMin = (short?)null,
            observacao = (string?)null,
            exercicios = new object[]
            {
                new { exercicioId = Agachamento, treinoExercicioId = (Guid?)null,
                      series = new[] { Serie(1, 20, 10) } },
            },
            manterNaFicha = new[] { Agachamento },
        });

        Assert.Equal(HttpStatusCode.Forbidden, resp.StatusCode);
        Assert.Equal(0, await SessoesDoTreino(treinoId));

        // A ficha do professor diz que é só leitura (o app não pergunta).
        var ficha = await client.GetFromJsonAsync<FichaResp>($"/api/v1/treinos/{treinoId}");
        Assert.True(ficha!.SomenteLeitura);
    }

    [Fact]
    public async Task Ficha_propria_nao_e_somente_leitura()
    {
        var (api, client, _) = Autenticar(_postgres);
        await using var _api = api;
        var (treinoId, _) = await CriarFicha(client);

        var ficha = await client.GetFromJsonAsync<FichaResp>($"/api/v1/treinos/{treinoId}");
        Assert.False(ficha!.SomenteLeitura);
    }

    [Fact]
    public async Task Editar_sessao_com_manter_responde_400()
    {
        var (api, client, _) = Autenticar(_postgres);
        await using var _api = api;
        var (treinoId, teSupino) = await CriarFicha(client);
        var criar = await client.PostAsJsonAsync("/api/v1/sessoes",
            Sessao(treinoId, teSupino, manterNaFicha: null));
        var sessaoId = (await criar.Content.ReadFromJsonAsync<CriadoResp>())!.Id;

        var editar = await client.PutAsJsonAsync($"/api/v1/sessoes/{sessaoId}",
            Sessao(treinoId, teSupino, [Agachamento]));

        Assert.Equal(HttpStatusCode.BadRequest, editar.StatusCode);
        await using var db = _postgres.CriarContexto();
        Assert.Equal(1, await db.TreinoExercicios.CountAsync(te => te.TreinoId == treinoId));
    }

    private async Task<Guid> InserirFichaDoProfessor(string uidAtleta)
    {
        await using var db = _postgres.CriarContexto();
        var atletaId = await db.Usuarios.Where(u => u.FirebaseUid == uidAtleta)
            .Select(u => u.Id).SingleAsync();
        var professor = new DiarioTreino.Domain.Identidade.Usuario
        {
            Id = Guid.NewGuid(),
            FirebaseUid = $"prof-{Guid.NewGuid():n}",
            Nome = "Prof. Rafael",
            Email = $"prof-{Guid.NewGuid():n}@teste.local",
            Ativo = true,
            CriadoEm = DateTimeOffset.UtcNow,
        };
        db.Usuarios.Add(professor);
        var plano = new PlanoTreino
        {
            Id = Guid.NewGuid(),
            AutorId = professor.Id,
            AtletaId = atletaId,
            Nome = "Força 5 dias",
            Inicio = DateOnly.FromDateTime(DateTime.UtcNow),
            Ativo = true,
            EmUso = false,
        };
        db.PlanosTreino.Add(plano);
        var treino = new Treino
        {
            Id = Guid.NewGuid(),
            PlanoId = plano.Id,
            Nome = "A",
            Ordem = 1,
            Ativo = true,
        };
        db.Treinos.Add(treino);
        await db.SaveChangesAsync();
        return treino.Id;
    }
}
