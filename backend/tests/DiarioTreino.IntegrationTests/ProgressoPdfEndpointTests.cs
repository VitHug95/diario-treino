using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using DiarioTreino.IntegrationTests.Infraestrutura;

namespace DiarioTreino.IntegrationTests;

/// <summary>
/// PBI-89: PDF do progresso (evolução por exercício + sessões do período).
/// Tanto o próprio atleta quanto o educador com vínculo ativo baixam; quem não
/// tem acesso recebe 404 (MAS 11.3), e sem token é 401. O conteúdo é um PDF de
/// verdade (começa com "%PDF").
/// </summary>
[Collection(PostgresCollection.Nome)]
public sealed class ProgressoPdfEndpointTests
{
    private readonly PostgresFixture _postgres;

    public ProgressoPdfEndpointTests(PostgresFixture postgres)
    {
        _postgres = postgres;
    }

    private static readonly Guid SupinoReto = Guid.Parse("11111111-0000-0000-0000-000000000001");
    private const short CargaKg = 1;
    private const short Repeticoes = 10;

    private sealed record CriadoResposta(Guid Id);
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

    // Cria uma sessão simples com uma série de Supino (carga × reps).
    private static async Task CriarSessao(Usuario u)
    {
        var hoje = DateOnly.FromDateTime(DateTime.UtcNow.Date);
        var resp = await u.Client.PostAsJsonAsync("/api/v1/sessoes", new
        {
            treinoId = (Guid?)null,
            data = hoje,
            duracaoMin = (short?)45,
            observacao = (string?)null,
            observacaoPrivada = false,
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
                            intensidadeMetricaId = CargaKg, intensidade = 40m,
                            volumeMetricaId = (short)10, volume = (decimal)Repeticoes,
                            descansoSeg = (short?)null, marcador = "VALIDA",
                        },
                    },
                },
            },
        });
        resp.EnsureSuccessStatusCode();
    }

    private static async Task<(HttpStatusCode status, string? contentType, byte[] corpo)> Baixar(
        HttpClient client, string url)
    {
        var resp = await client.GetAsync(url);
        var bytes = await resp.Content.ReadAsByteArrayAsync();
        return (resp.StatusCode, resp.Content.Headers.ContentType?.MediaType, bytes);
    }

    private static bool EhPdf(byte[] b) =>
        b.Length > 4 && b[0] == (byte)'%' && b[1] == (byte)'P' && b[2] == (byte)'D' && b[3] == (byte)'F';

    [Fact]
    public async Task Proprio_atleta_baixa_o_pdf_do_progresso()
    {
        var atleta = NovoUsuario(_postgres);
        await using var _a = atleta.Api;
        await Provisionar(atleta);
        await CriarSessao(atleta);

        var (status, contentType, corpo) = await Baixar(atleta.Client, "/api/v1/progresso/pdf");

        Assert.Equal(HttpStatusCode.OK, status);
        Assert.Equal("application/pdf", contentType);
        Assert.True(EhPdf(corpo), "o corpo deveria começar com %PDF");
    }

    [Fact]
    public async Task Educador_com_vinculo_baixa_o_pdf_do_aluno()
    {
        var (educador, aluno) = await ComVinculoAtivo();
        await using var _e = educador.Api;
        await using var _a = aluno.Api;
        await CriarSessao(aluno);

        var alunoId = await IdDoUsuario(aluno.Uid);
        var (status, contentType, corpo) =
            await Baixar(educador.Client, $"/api/v1/progresso/pdf?atletaId={alunoId}");

        Assert.Equal(HttpStatusCode.OK, status);
        Assert.Equal("application/pdf", contentType);
        Assert.True(EhPdf(corpo));
    }

    [Fact]
    public async Task Sem_vinculo_o_educador_recebe_404()
    {
        var educador = NovoUsuario(_postgres);
        var aluno = NovoUsuario(_postgres);
        await using var _e = educador.Api;
        await using var _a = aluno.Api;
        await Provisionar(educador);
        await Provisionar(aluno);
        var alunoId = await IdDoUsuario(aluno.Uid);

        var resp = await educador.Client.GetAsync($"/api/v1/progresso/pdf?atletaId={alunoId}");
        Assert.Equal(HttpStatusCode.NotFound, resp.StatusCode);
    }

    [Fact]
    public async Task Sem_token_responde_401()
    {
        await using var api = new ApiFactory(_postgres.ConnectionString);
        var client = api.CreateClient();

        var resp = await client.GetAsync("/api/v1/progresso/pdf");
        Assert.Equal(HttpStatusCode.Unauthorized, resp.StatusCode);
    }

    private async Task<Guid> IdDoUsuario(string uid)
    {
        await using var db = _postgres.CriarContexto();
        return await Microsoft.EntityFrameworkCore.EntityFrameworkQueryableExtensions.SingleAsync(
            db.Usuarios.Where(u => u.FirebaseUid == uid).Select(u => u.Id));
    }
}
