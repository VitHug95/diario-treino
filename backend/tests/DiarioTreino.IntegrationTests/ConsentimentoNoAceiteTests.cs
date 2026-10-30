using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using DiarioTreino.IntegrationTests.Infraestrutura;
using Microsoft.EntityFrameworkCore;

namespace DiarioTreino.IntegrationTests;

/// <summary>
/// PBI-88a (fecha a parte 2 da PBI-87): aceitar o convite de um educador É o ato
/// de consentir (LGPD). O aceite registra o consentimento do aluno (versão
/// vigente do termo) na tabela, de forma idempotente; recusar não registra.
/// </summary>
[Collection(PostgresCollection.Nome)]
public sealed class ConsentimentoNoAceiteTests
{
    private readonly PostgresFixture _postgres;

    public ConsentimentoNoAceiteTests(PostgresFixture postgres)
    {
        _postgres = postgres;
    }

    private const string VersaoVigente = "1";

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

    private async Task<Guid> IdDoUsuario(string uid)
    {
        await using var db = _postgres.CriarContexto();
        return await db.Usuarios.Where(u => u.FirebaseUid == uid).Select(u => u.Id).SingleAsync();
    }

    private async Task<int> ConsentimentosDe(Guid usuarioId)
    {
        await using var db = _postgres.CriarContexto();
        return await db.Consentimentos.CountAsync(c => c.UsuarioId == usuarioId);
    }

    // educador + aluno provisionados; devolve o id do convite PENDENTE.
    private async Task<(Usuario educador, Usuario aluno, Guid vinculoId)> ComConvitePendente()
    {
        var educador = NovoUsuario(_postgres);
        var aluno = NovoUsuario(_postgres);
        await Provisionar(educador);
        await Provisionar(aluno);
        (await educador.Client.PostAsync("/api/v1/me/papeis/educador", content: null))
            .EnsureSuccessStatusCode();
        var convite = await educador.Client.PostAsJsonAsync("/api/v1/vinculos", new { email = aluno.Email });
        var vinculoId = (await convite.Content.ReadFromJsonAsync<CriadoResposta>())!.Id;
        return (educador, aluno, vinculoId);
    }

    [Fact]
    public async Task Aceitar_o_convite_registra_o_consentimento_do_aluno()
    {
        var (educador, aluno, vinculoId) = await ComConvitePendente();
        await using var _e = educador.Api;
        await using var _a = aluno.Api;

        var alunoId = await IdDoUsuario(aluno.Uid);
        Assert.Equal(0, await ConsentimentosDe(alunoId)); // antes do aceite, nada.

        (await aluno.Client.PostAsync($"/api/v1/vinculos/{vinculoId}/aceitar", content: null))
            .EnsureSuccessStatusCode();

        // Depois do aceite: exatamente um consentimento, na versão vigente.
        await using var db = _postgres.CriarContexto();
        var consentimentos = await db.Consentimentos.Where(c => c.UsuarioId == alunoId).ToListAsync();
        Assert.Single(consentimentos);
        Assert.Equal(VersaoVigente, consentimentos[0].VersaoTermo);
    }

    [Fact]
    public async Task Aceitar_um_segundo_convite_nao_duplica_o_consentimento()
    {
        // Aluno aceita convite de dois educadores diferentes: o consentimento
        // (por versão de termo) é registrado uma vez só, não um por vínculo.
        var (educador1, aluno, vinculo1) = await ComConvitePendente();
        await using var _e1 = educador1.Api;
        await using var _a = aluno.Api;
        (await aluno.Client.PostAsync($"/api/v1/vinculos/{vinculo1}/aceitar", content: null))
            .EnsureSuccessStatusCode();

        var educador2 = NovoUsuario(_postgres);
        await using var _e2 = educador2.Api;
        await Provisionar(educador2);
        (await educador2.Client.PostAsync("/api/v1/me/papeis/educador", content: null))
            .EnsureSuccessStatusCode();
        var convite2 = await educador2.Client.PostAsJsonAsync("/api/v1/vinculos", new { email = aluno.Email });
        var vinculo2 = (await convite2.Content.ReadFromJsonAsync<CriadoResposta>())!.Id;
        (await aluno.Client.PostAsync($"/api/v1/vinculos/{vinculo2}/aceitar", content: null))
            .EnsureSuccessStatusCode();

        var alunoId = await IdDoUsuario(aluno.Uid);
        Assert.Equal(1, await ConsentimentosDe(alunoId)); // ainda um só.
    }

    [Fact]
    public async Task Recusar_o_convite_nao_registra_consentimento()
    {
        var (educador, aluno, vinculoId) = await ComConvitePendente();
        await using var _e = educador.Api;
        await using var _a = aluno.Api;

        (await aluno.Client.PostAsync($"/api/v1/vinculos/{vinculoId}/recusar", content: null))
            .EnsureSuccessStatusCode();

        var alunoId = await IdDoUsuario(aluno.Uid);
        Assert.Equal(0, await ConsentimentosDe(alunoId));
    }
}
