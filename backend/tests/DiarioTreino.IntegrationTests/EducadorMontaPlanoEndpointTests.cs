using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using DiarioTreino.IntegrationTests.Infraestrutura;
using Microsoft.EntityFrameworkCore;

namespace DiarioTreino.IntegrationTests;

/// <summary>
/// PBI-48/PBI-88d: o educador com vínculo ATIVO monta o plano e as fichas do
/// aluno. O plano nasce com autor = educador e atleta = aluno; a regra de
/// somente-leitura (MAS 11.3) passa a comparar o AUTOR com quem está logado,
/// então o educador edita o próprio plano, o aluno não (403), e sem vínculo o
/// acesso responde 404 — nunca 403.
/// </summary>
[Collection(PostgresCollection.Nome)]
public sealed class EducadorMontaPlanoEndpointTests
{
    private readonly PostgresFixture _postgres;

    public EducadorMontaPlanoEndpointTests(PostgresFixture postgres)
    {
        _postgres = postgres;
    }

    private sealed record CriadoResposta(Guid Id);
    private sealed record PlanoDetalheResposta(
        Guid Id, string Nome, DateOnly Inicio, bool EmUso, string Autor, bool SomenteLeitura,
        List<TreinoResumoResposta> Treinos);
    private sealed record TreinoResumoResposta(Guid Id, string Nome, string? Descricao, short Ordem);

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

    // Cria educador + aluno e deixa o vínculo ATIVO; devolve os dois e os ids.
    private async Task<(Usuario educador, Usuario aluno, Guid educadorId, Guid alunoId)> ComVinculoAtivo()
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

        var educadorId = await IdDoUsuario(educador.Uid);
        var alunoId = await IdDoUsuario(aluno.Uid);
        return (educador, aluno, educadorId, alunoId);
    }

    // ---- Educador monta o plano e a ficha do aluno (201) ----

    [Fact]
    public async Task Educador_com_vinculo_cria_plano_e_ficha_para_o_aluno()
    {
        var (educador, aluno, educadorId, alunoId) = await ComVinculoAtivo();
        await using var _e = educador.Api;
        await using var _a = aluno.Api;

        // Cria o plano para o aluno (atletaId no corpo = modo educador).
        var criar = await educador.Client.PostAsJsonAsync(
            "/api/v1/planos", new { nome = "Força 5 dias", atletaId = alunoId });
        Assert.Equal(HttpStatusCode.Created, criar.StatusCode);
        var planoId = (await criar.Content.ReadFromJsonAsync<CriadoResposta>())!.Id;

        // Adiciona uma ficha ao plano (reusa POST /planos/{id}/treinos).
        var ficha = await educador.Client.PostAsJsonAsync(
            $"/api/v1/planos/{planoId}/treinos", new { nome = "A", descricao = "Peito" });
        Assert.Equal(HttpStatusCode.Created, ficha.StatusCode);

        // No banco: autor = educador, atleta = aluno.
        await using (var db = _postgres.CriarContexto())
        {
            var plano = await db.PlanosTreino.SingleAsync(p => p.Id == planoId);
            Assert.Equal(educadorId, plano.AutorId);
            Assert.Equal(alunoId, plano.AtletaId);
        }

        // O aluno vê o plano do professor como somente-leitura, com a ficha.
        var det = await aluno.Client.GetFromJsonAsync<PlanoDetalheResposta>($"/api/v1/planos/{planoId}");
        Assert.True(det!.SomenteLeitura);
        Assert.Contains(det.Treinos, t => t.Nome == "A");
    }

    // ---- Sem vínculo: 404 (não 403) e nada gravado ----

    [Fact]
    public async Task Educador_sem_vinculo_recebe_404_ao_criar_plano_para_o_aluno()
    {
        var educador = NovoUsuario(_postgres);
        var aluno = NovoUsuario(_postgres);
        await using var _e = educador.Api;
        await using var _a = aluno.Api;
        await Provisionar(educador);
        await Provisionar(aluno);
        (await educador.Client.PostAsync("/api/v1/me/papeis/educador", content: null))
            .EnsureSuccessStatusCode();
        var alunoId = await IdDoUsuario(aluno.Uid);

        var resp = await educador.Client.PostAsJsonAsync(
            "/api/v1/planos", new { nome = "Força", atletaId = alunoId });
        Assert.Equal(HttpStatusCode.NotFound, resp.StatusCode); // 404, não 403

        await using var db = _postgres.CriarContexto();
        Assert.False(await db.PlanosTreino.AnyAsync(p => p.AtletaId == alunoId));
    }

    // ---- Autor edita; aluno não (403) ----

    [Fact]
    public async Task Educador_edita_o_plano_que_montou_e_o_aluno_nao_pode()
    {
        var (educador, aluno, _, alunoId) = await ComVinculoAtivo();
        await using var _e = educador.Api;
        await using var _a = aluno.Api;

        var criar = await educador.Client.PostAsJsonAsync(
            "/api/v1/planos", new { nome = "Força 5 dias", atletaId = alunoId });
        var planoId = (await criar.Content.ReadFromJsonAsync<CriadoResposta>())!.Id;

        // O educador (autor) renomeia sem problema.
        var renomearEducador = await educador.Client.PutAsJsonAsync(
            $"/api/v1/planos/{planoId}", new { nome = "Força - ajuste" });
        Assert.Equal(HttpStatusCode.NoContent, renomearEducador.StatusCode);

        // O aluno (dono, mas não autor) não edita: 403.
        var renomearAluno = await aluno.Client.PutAsJsonAsync(
            $"/api/v1/planos/{planoId}", new { nome = "Meu jeito" });
        Assert.Equal(HttpStatusCode.Forbidden, renomearAluno.StatusCode);

        // Mas o aluno LÊ o plano normalmente (200).
        Assert.Equal(HttpStatusCode.OK,
            (await aluno.Client.GetAsync($"/api/v1/planos/{planoId}")).StatusCode);
    }
}
