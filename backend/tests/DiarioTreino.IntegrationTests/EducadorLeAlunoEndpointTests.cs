using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using DiarioTreino.IntegrationTests.Infraestrutura;
using Microsoft.EntityFrameworkCore;

namespace DiarioTreino.IntegrationTests;

/// <summary>
/// PBI-86: o educador com vínculo ATIVO lê os dados do aluno via o parâmetro
/// opcional <c>atletaId</c> nas rotas de leitura (planos, sessões, progresso).
/// Sem vínculo ativo (nunca teve, ou encerrado), responde 404 — a mesma regra
/// do MAS 11.3 que vale para recurso de outro usuário.
/// </summary>
[Collection(PostgresCollection.Nome)]
public sealed class EducadorLeAlunoEndpointTests
{
    private readonly PostgresFixture _postgres;

    public EducadorLeAlunoEndpointTests(PostgresFixture postgres)
    {
        _postgres = postgres;
    }

    private sealed record CriadoResposta(Guid Id);
    private sealed record PlanoDaListaResposta(Guid Id, string Nome);

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

    private async Task<Guid> IdDoUsuario(string uid)
    {
        await using var db = _postgres.CriarContexto();
        return await db.Usuarios.Where(u => u.FirebaseUid == uid).Select(u => u.Id).SingleAsync();
    }

    private static Task Provisionar(Usuario u) =>
        u.Client.GetAsync("/api/v1/me").ContinueWith(t => t.Result.EnsureSuccessStatusCode());

    // Cria educador + aluno e deixa o vínculo ATIVO; devolve os dois e o id do aluno.
    private async Task<(Usuario educador, Usuario aluno, Guid alunoId)> ComVinculoAtivo()
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

        var alunoId = await IdDoUsuario(aluno.Uid);
        return (educador, aluno, alunoId);
    }

    // ---- Educador com vínculo ativo LÊ os dados do aluno ----

    [Fact]
    public async Task Educador_com_vinculo_ativo_ve_os_planos_do_aluno()
    {
        var (educador, aluno, alunoId) = await ComVinculoAtivo();
        await using var _e = educador.Api;
        await using var _a = aluno.Api;

        // O aluno cria um plano.
        await aluno.Client.PostAsJsonAsync("/api/v1/planos", new { nome = "Hipertrofia do aluno" });

        // O educador lê os planos do aluno via atletaId.
        var resp = await educador.Client.GetAsync($"/api/v1/planos?atletaId={alunoId}");
        Assert.Equal(HttpStatusCode.OK, resp.StatusCode);
        var planos = await resp.Content.ReadFromJsonAsync<List<PlanoDaListaResposta>>();
        Assert.Contains(planos!, p => p.Nome == "Hipertrofia do aluno");

        // E o plano em uso e as sessões (vazias, mas 200 — tem acesso).
        Assert.Equal(HttpStatusCode.OK,
            (await educador.Client.GetAsync($"/api/v1/planos/ativo?atletaId={alunoId}")).StatusCode);
        Assert.Equal(HttpStatusCode.OK,
            (await educador.Client.GetAsync($"/api/v1/sessoes?atletaId={alunoId}")).StatusCode);
        Assert.Equal(HttpStatusCode.OK,
            (await educador.Client.GetAsync($"/api/v1/progresso/exercicios?atletaId={alunoId}")).StatusCode);
    }

    [Fact]
    public async Task Sem_atletaId_o_educador_ve_os_proprios_dados()
    {
        var (educador, aluno, _) = await ComVinculoAtivo();
        await using var _e = educador.Api;
        await using var _a = aluno.Api;

        // Sem atletaId, a rota vale para o próprio logado (o educador), que não
        // tem planos — lista vazia, 200.
        var resp = await educador.Client.GetAsync("/api/v1/planos");
        Assert.Equal(HttpStatusCode.OK, resp.StatusCode);
        var planos = await resp.Content.ReadFromJsonAsync<List<PlanoDaListaResposta>>();
        Assert.Empty(planos!);
    }

    // ---- Sem vínculo ativo → 404 em todas as rotas de leitura ----

    [Fact]
    public async Task Sem_vinculo_o_educador_recebe_404_nas_rotas_do_aluno()
    {
        // Educador e aluno existem, mas NÃO há vínculo entre eles.
        var educador = NovoUsuario(_postgres);
        var aluno = NovoUsuario(_postgres);
        await using var _e = educador.Api;
        await using var _a = aluno.Api;
        await Provisionar(educador);
        await Provisionar(aluno);
        (await educador.Client.PostAsync("/api/v1/me/papeis/educador", content: null))
            .EnsureSuccessStatusCode();
        var alunoId = await IdDoUsuario(aluno.Uid);

        var exercicioId = Guid.NewGuid(); // id qualquer: o 404 vem do acesso, antes.

        Assert.Equal(HttpStatusCode.NotFound,
            (await educador.Client.GetAsync($"/api/v1/planos?atletaId={alunoId}")).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound,
            (await educador.Client.GetAsync($"/api/v1/planos/ativo?atletaId={alunoId}")).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound,
            (await educador.Client.GetAsync($"/api/v1/sessoes?atletaId={alunoId}")).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound,
            (await educador.Client.GetAsync($"/api/v1/progresso/exercicios?atletaId={alunoId}")).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound,
            (await educador.Client.GetAsync(
                $"/api/v1/progresso/exercicios/{exercicioId}?atletaId={alunoId}")).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound,
            (await educador.Client.GetAsync(
                $"/api/v1/exercicios/{exercicioId}/historico?atletaId={alunoId}")).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound,
            (await educador.Client.GetAsync(
                $"/api/v1/exercicios/{exercicioId}/ultima-execucao?atletaId={alunoId}")).StatusCode);
    }

    [Fact]
    public async Task Vinculo_encerrado_tira_o_acesso_do_educador()
    {
        var (educador, aluno, alunoId) = await ComVinculoAtivo();
        await using var _e = educador.Api;
        await using var _a = aluno.Api;

        // Com vínculo ativo, o educador vê (200).
        Assert.Equal(HttpStatusCode.OK,
            (await educador.Client.GetAsync($"/api/v1/planos?atletaId={alunoId}")).StatusCode);

        // Encerra o vínculo: o acesso cai na hora (404), sem apagar nada do aluno.
        await using (var db = _postgres.CriarContexto())
        {
            var v = await db.Vinculos.SingleAsync(x => x.AlunoId == alunoId);
            v.Status = "ENCERRADO";
            v.Fim = DateTimeOffset.UtcNow;
            await db.SaveChangesAsync();
        }

        Assert.Equal(HttpStatusCode.NotFound,
            (await educador.Client.GetAsync($"/api/v1/planos?atletaId={alunoId}")).StatusCode);
    }
}
