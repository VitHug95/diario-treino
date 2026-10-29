using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using DiarioTreino.IntegrationTests.Infraestrutura;

namespace DiarioTreino.IntegrationTests;

/// <summary>
/// Vínculo educador-aluno (PBI-85): ativar o papel educador, convidar por
/// e-mail, aceitar/recusar/encerrar e listar alunos. Cobre as regras de erro
/// (403/400/404/409) e o isolamento (recurso de outro usuário → 404).
/// </summary>
[Collection(PostgresCollection.Nome)]
public sealed class VinculoEndpointTests
{
    private readonly PostgresFixture _postgres;

    public VinculoEndpointTests(PostgresFixture postgres)
    {
        _postgres = postgres;
    }

    private sealed record CriadoResposta(Guid Id);
    private sealed record ConvitePendenteResposta(
        Guid VinculoId, Guid EducadorId, string EducadorNome, string EducadorEmail);
    private sealed record AlunoVinculadoResposta(
        Guid VinculoId, Guid AlunoId, string AlunoNome, string AlunoEmail);

    // Cada usuário tem sua ApiFactory/HttpClient autenticado por um token falso.
    private sealed record Usuario(ApiFactory Api, HttpClient Client, string Uid, string Email);

    private static Usuario NovoUsuario(PostgresFixture pg, string papel = "Atleta")
    {
        var api = new ApiFactory(pg.ConnectionString);
        var client = api.CreateClient();
        var uid = $"uid-{Guid.NewGuid():n}";
        var email = $"{uid}@teste.local";
        var token = api.Tokens.Gerar(uid, email: email, nome: papel);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
        return new Usuario(api, client, uid, email);
    }

    // Provisiona o usuário no banco (GET /me cria no primeiro acesso).
    private static async Task Provisionar(Usuario u) =>
        (await u.Client.GetAsync("/api/v1/me")).EnsureSuccessStatusCode();

    private static async Task TornarEducador(Usuario u) =>
        (await u.Client.PostAsync("/api/v1/me/papeis/educador", content: null)).EnsureSuccessStatusCode();

    // ---- Fluxo feliz: convite → aceite → lista de alunos ----

    [Fact]
    public async Task Convite_aceito_vira_vinculo_ativo_e_o_aluno_aparece_na_lista()
    {
        var educador = NovoUsuario(_postgres);
        var aluno = NovoUsuario(_postgres);
        await using var _e = educador.Api;
        await using var _a = aluno.Api;
        await Provisionar(educador);
        await Provisionar(aluno);
        await TornarEducador(educador);

        // Educador convida o aluno por e-mail.
        var convite = await educador.Client.PostAsJsonAsync(
            "/api/v1/vinculos", new { email = aluno.Email });
        Assert.Equal(HttpStatusCode.Created, convite.StatusCode);
        var vinculoId = (await convite.Content.ReadFromJsonAsync<CriadoResposta>())!.Id;

        // O aluno vê o convite pendente.
        var pendentes = await aluno.Client.GetFromJsonAsync<List<ConvitePendenteResposta>>(
            "/api/v1/vinculos/pendentes");
        Assert.Single(pendentes!);
        Assert.Equal(vinculoId, pendentes![0].VinculoId);
        Assert.Equal(educador.Email, pendentes[0].EducadorEmail);

        // Antes do aceite, o educador ainda não tem alunos.
        var antes = await educador.Client.GetFromJsonAsync<List<AlunoVinculadoResposta>>("/api/v1/alunos");
        Assert.Empty(antes!);

        // O aluno aceita.
        var aceite = await aluno.Client.PostAsync($"/api/v1/vinculos/{vinculoId}/aceitar", content: null);
        Assert.Equal(HttpStatusCode.NoContent, aceite.StatusCode);

        // Agora o aluno aparece na lista do educador e não há mais pendência.
        var alunos = await educador.Client.GetFromJsonAsync<List<AlunoVinculadoResposta>>("/api/v1/alunos");
        Assert.Single(alunos!);
        Assert.Equal(aluno.Email, alunos![0].AlunoEmail);

        var pendentesDepois = await aluno.Client.GetFromJsonAsync<List<ConvitePendenteResposta>>(
            "/api/v1/vinculos/pendentes");
        Assert.Empty(pendentesDepois!);
    }

    [Fact]
    public async Task Recusar_nao_cria_vinculo_ativo()
    {
        var educador = NovoUsuario(_postgres);
        var aluno = NovoUsuario(_postgres);
        await using var _e = educador.Api;
        await using var _a = aluno.Api;
        await Provisionar(educador);
        await Provisionar(aluno);
        await TornarEducador(educador);

        var convite = await educador.Client.PostAsJsonAsync("/api/v1/vinculos", new { email = aluno.Email });
        var vinculoId = (await convite.Content.ReadFromJsonAsync<CriadoResposta>())!.Id;

        var recusa = await aluno.Client.PostAsync($"/api/v1/vinculos/{vinculoId}/recusar", content: null);
        Assert.Equal(HttpStatusCode.NoContent, recusa.StatusCode);

        var alunos = await educador.Client.GetFromJsonAsync<List<AlunoVinculadoResposta>>("/api/v1/alunos");
        Assert.Empty(alunos!);
    }

    [Fact]
    public async Task Encerrar_tira_o_aluno_da_lista()
    {
        var educador = NovoUsuario(_postgres);
        var aluno = NovoUsuario(_postgres);
        await using var _e = educador.Api;
        await using var _a = aluno.Api;
        await Provisionar(educador);
        await Provisionar(aluno);
        await TornarEducador(educador);

        var convite = await educador.Client.PostAsJsonAsync("/api/v1/vinculos", new { email = aluno.Email });
        var vinculoId = (await convite.Content.ReadFromJsonAsync<CriadoResposta>())!.Id;
        await aluno.Client.PostAsync($"/api/v1/vinculos/{vinculoId}/aceitar", content: null);

        var encerra = await educador.Client.PostAsync($"/api/v1/vinculos/{vinculoId}/encerrar", content: null);
        Assert.Equal(HttpStatusCode.NoContent, encerra.StatusCode);

        var alunos = await educador.Client.GetFromJsonAsync<List<AlunoVinculadoResposta>>("/api/v1/alunos");
        Assert.Empty(alunos!);
    }

    // ---- Erros de regra ----

    [Fact]
    public async Task Convidar_sem_ser_educador_responde_403()
    {
        var usuario = NovoUsuario(_postgres);
        var aluno = NovoUsuario(_postgres);
        await using var _u = usuario.Api;
        await using var _a = aluno.Api;
        await Provisionar(usuario);
        await Provisionar(aluno);
        // Não chama TornarEducador de propósito.

        var resp = await usuario.Client.PostAsJsonAsync("/api/v1/vinculos", new { email = aluno.Email });
        Assert.Equal(HttpStatusCode.Forbidden, resp.StatusCode);
    }

    [Fact]
    public async Task Convidar_a_si_mesmo_responde_400()
    {
        var educador = NovoUsuario(_postgres);
        await using var _e = educador.Api;
        await Provisionar(educador);
        await TornarEducador(educador);

        var resp = await educador.Client.PostAsJsonAsync("/api/v1/vinculos", new { email = educador.Email });
        Assert.Equal(HttpStatusCode.BadRequest, resp.StatusCode);
    }

    [Fact]
    public async Task Convidar_email_inexistente_responde_404()
    {
        var educador = NovoUsuario(_postgres);
        await using var _e = educador.Api;
        await Provisionar(educador);
        await TornarEducador(educador);

        var resp = await educador.Client.PostAsJsonAsync(
            "/api/v1/vinculos", new { email = "ninguem@teste.local" });
        Assert.Equal(HttpStatusCode.NotFound, resp.StatusCode);
    }

    [Fact]
    public async Task Convidar_duas_vezes_o_mesmo_aluno_responde_409()
    {
        var educador = NovoUsuario(_postgres);
        var aluno = NovoUsuario(_postgres);
        await using var _e = educador.Api;
        await using var _a = aluno.Api;
        await Provisionar(educador);
        await Provisionar(aluno);
        await TornarEducador(educador);

        var primeiro = await educador.Client.PostAsJsonAsync("/api/v1/vinculos", new { email = aluno.Email });
        Assert.Equal(HttpStatusCode.Created, primeiro.StatusCode);

        var segundo = await educador.Client.PostAsJsonAsync("/api/v1/vinculos", new { email = aluno.Email });
        Assert.Equal(HttpStatusCode.Conflict, segundo.StatusCode);
    }

    [Fact]
    public async Task Email_invalido_responde_400_de_validacao()
    {
        var educador = NovoUsuario(_postgres);
        await using var _e = educador.Api;
        await Provisionar(educador);
        await TornarEducador(educador);

        var resp = await educador.Client.PostAsJsonAsync("/api/v1/vinculos", new { email = "nao-e-email" });
        Assert.Equal(HttpStatusCode.BadRequest, resp.StatusCode);
    }

    // ---- Isolamento: recurso de outro usuário → 404 ----

    [Fact]
    public async Task Vinculo_de_outros_responde_404_para_um_terceiro()
    {
        var educador = NovoUsuario(_postgres);
        var aluno = NovoUsuario(_postgres);
        var terceiro = NovoUsuario(_postgres);
        await using var _e = educador.Api;
        await using var _a = aluno.Api;
        await using var _t = terceiro.Api;
        await Provisionar(educador);
        await Provisionar(aluno);
        await Provisionar(terceiro);
        await TornarEducador(educador);

        var convite = await educador.Client.PostAsJsonAsync("/api/v1/vinculos", new { email = aluno.Email });
        var vinculoId = (await convite.Content.ReadFromJsonAsync<CriadoResposta>())!.Id;

        // Um terceiro (nem educador nem aluno do vínculo) não consegue mexer nele.
        Assert.Equal(HttpStatusCode.NotFound,
            (await terceiro.Client.PostAsync($"/api/v1/vinculos/{vinculoId}/aceitar", content: null)).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound,
            (await terceiro.Client.PostAsync($"/api/v1/vinculos/{vinculoId}/recusar", content: null)).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound,
            (await terceiro.Client.PostAsync($"/api/v1/vinculos/{vinculoId}/encerrar", content: null)).StatusCode);
    }

    [Fact]
    public async Task Educador_nao_aceita_o_proprio_convite_pelo_aluno()
    {
        // Aceitar é do aluno: o educador tentando aceitar o vínculo que criou
        // não é o aluno dele, então responde 404 (não é "dele" para aceitar).
        var educador = NovoUsuario(_postgres);
        var aluno = NovoUsuario(_postgres);
        await using var _e = educador.Api;
        await using var _a = aluno.Api;
        await Provisionar(educador);
        await Provisionar(aluno);
        await TornarEducador(educador);

        var convite = await educador.Client.PostAsJsonAsync("/api/v1/vinculos", new { email = aluno.Email });
        var vinculoId = (await convite.Content.ReadFromJsonAsync<CriadoResposta>())!.Id;

        var resp = await educador.Client.PostAsync($"/api/v1/vinculos/{vinculoId}/aceitar", content: null);
        Assert.Equal(HttpStatusCode.NotFound, resp.StatusCode);
    }
}
