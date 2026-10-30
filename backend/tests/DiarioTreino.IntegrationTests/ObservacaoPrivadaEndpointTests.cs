using System.Net.Http.Headers;
using System.Net.Http.Json;
using DiarioTreino.IntegrationTests.Infraestrutura;
using Microsoft.EntityFrameworkCore;

namespace DiarioTreino.IntegrationTests;

/// <summary>
/// PBI-87: observação da sessão marcada como privada só é visível ao próprio
/// atleta. O educador com vínculo ativo acessa a sessão, mas não recebe o texto
/// da observação privada (recebe a não-privada normalmente).
/// </summary>
[Collection(PostgresCollection.Nome)]
public sealed class ObservacaoPrivadaEndpointTests
{
    private readonly PostgresFixture _postgres;

    public ObservacaoPrivadaEndpointTests(PostgresFixture postgres)
    {
        _postgres = postgres;
    }

    private static readonly Guid SupinoReto = Guid.Parse("11111111-0000-0000-0000-000000000001");
    private const short CargaKg = 1;
    private const short Repeticoes = 10;

    private sealed record CriadoResposta(Guid Id);
    private sealed record SessaoDetalheResposta(Guid Id, string? Observacao);

    private sealed record Usuario(ApiFactory Api, HttpClient Client, string Uid, string Email);

    private static Usuario NovoUsuario(PostgresFixture pg)
    {
        var api = new ApiFactory(pg.ConnectionString);
        var client = api.CreateClient();
        var uid = $"uid-{Guid.NewGuid():n}";
        var email = $"{uid}@teste.local";
        var token = api.Tokens.Gerar(uid, email: email, nome: "Pessoa");
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
        return new Usuario(api, client, uid, email);
    }

    private static Task Provisionar(Usuario u) =>
        u.Client.GetAsync("/api/v1/me").ContinueWith(t => t.Result.EnsureSuccessStatusCode());

    // Educador + aluno com vínculo ATIVO.
    private async Task<(Usuario educador, Usuario aluno)> ComVinculoAtivo()
    {
        var educador = NovoUsuario(_postgres);
        var aluno = NovoUsuario(_postgres);
        await Provisionar(educador);
        await Provisionar(aluno);
        (await educador.Client.PostAsync("/api/v1/me/papeis/educador", content: null))
            .EnsureSuccessStatusCode();
        var convite = await educador.Client.PostAsJsonAsync("/api/v1/vinculos", new { email = aluno.Email });
        var vinculoId = (await convite.Content.ReadFromJsonAsync<CriadoResposta>())!.Id;
        (await aluno.Client.PostAsync($"/api/v1/vinculos/{vinculoId}/aceitar", content: null))
            .EnsureSuccessStatusCode();
        return (educador, aluno);
    }

    // Cria uma sessão de treino livre com uma série de Supino e a observação dada.
    private static async Task<Guid> CriarSessao(Usuario u, string observacao, bool privada)
    {
        var hoje = DateOnly.FromDateTime(DateTime.UtcNow.Date);
        var resp = await u.Client.PostAsJsonAsync("/api/v1/sessoes", new
        {
            treinoId = (Guid?)null,
            data = hoje,
            duracaoMin = (short?)null,
            observacao,
            observacaoPrivada = privada,
            exercicios = new[]
            {
                new
                {
                    exercicioId = SupinoReto,
                    treinoExercicioId = (Guid?)null,
                    series = new[]
                    {
                        new
                        {
                            rodada = (short)1, ordem = (short)1, tipo = "ESFORCO",
                            intensidadeMetricaId = CargaKg, intensidade = 30m,
                            volumeMetricaId = (short)10, volume = (decimal)Repeticoes,
                            descansoSeg = (short?)null, marcador = "VALIDA",
                        },
                    },
                },
            },
        });
        resp.EnsureSuccessStatusCode();
        return (await resp.Content.ReadFromJsonAsync<CriadoResposta>())!.Id;
    }

    [Fact]
    public async Task Observacao_privada_some_para_o_educador_mas_o_dono_ve()
    {
        var (educador, aluno) = await ComVinculoAtivo();
        await using var _e = educador.Api;
        await using var _a = aluno.Api;

        var sessaoId = await CriarSessao(aluno, "Ombro doeu no supino", privada: true);

        // Dono vê o texto.
        var doDono = await aluno.Client.GetFromJsonAsync<SessaoDetalheResposta>($"/api/v1/sessoes/{sessaoId}");
        Assert.Equal("Ombro doeu no supino", doDono!.Observacao);

        // Educador acessa a sessão (tem vínculo) mas NÃO recebe o texto privado.
        var doEducador = await educador.Client.GetAsync($"/api/v1/sessoes/{sessaoId}");
        doEducador.EnsureSuccessStatusCode();
        var detalhe = await doEducador.Content.ReadFromJsonAsync<SessaoDetalheResposta>();
        Assert.Null(detalhe!.Observacao);
    }

    [Fact]
    public async Task Observacao_nao_privada_o_educador_ve_normalmente()
    {
        var (educador, aluno) = await ComVinculoAtivo();
        await using var _e = educador.Api;
        await using var _a = aluno.Api;

        var sessaoId = await CriarSessao(aluno, "Treino leve hoje", privada: false);

        var detalhe = await educador.Client.GetFromJsonAsync<SessaoDetalheResposta>(
            $"/api/v1/sessoes/{sessaoId}");
        Assert.Equal("Treino leve hoje", detalhe!.Observacao);
    }

    [Fact]
    public async Task Observacao_privada_persiste_a_flag_no_banco()
    {
        var aluno = NovoUsuario(_postgres);
        await using var _a = aluno.Api;
        await Provisionar(aluno);

        var sessaoId = await CriarSessao(aluno, "nota privada", privada: true);

        await using var db = _postgres.CriarContexto();
        var sessao = await db.Sessoes.SingleAsync(s => s.Id == sessaoId);
        Assert.True(sessao.ObservacaoPrivada);
        Assert.Equal("nota privada", sessao.Observacao);
    }
}
