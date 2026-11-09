using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using DiarioTreino.IntegrationTests.Infraestrutura;
using Microsoft.EntityFrameworkCore;

namespace DiarioTreino.IntegrationTests;

/// <summary>
/// PBI-91: medidas corporais (E12). Sob /me, só o dono. Upsert por tipo, variação
/// por tipo, dia vazio recusado, exclusão do dia, isolamento entre usuários e
/// cascata no DELETE /me.
/// </summary>
[Collection(PostgresCollection.Nome)]
public sealed class MedidaEndpointTests
{
    private readonly PostgresFixture _postgres;

    public MedidaEndpointTests(PostgresFixture postgres)
    {
        _postgres = postgres;
    }

    private sealed record Conta(ApiFactory Api, HttpClient Client, string Uid);
    private sealed record UltimaResposta(string Tipo, decimal Valor, string Data, decimal? Variacao);
    private sealed record HistoricoResposta(string Data, int Quantidade);
    private sealed record ResumoResposta(List<UltimaResposta> Ultimas, List<HistoricoResposta> Historico);
    private sealed record DiaResposta(Dictionary<string, decimal> Valores);

    private static Conta NovoUsuario(PostgresFixture pg)
    {
        var api = new ApiFactory(pg.ConnectionString);
        var client = api.CreateClient();
        var uid = $"uid-{Guid.NewGuid():n}";
        var token = api.Tokens.Gerar(uid, email: $"{uid}@teste.local", nome: "Pessoa");
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
        return new Conta(api, client, uid);
    }

    private static string Hoje(int diasAtras = 0) =>
        DateOnly.FromDateTime(DateTime.UtcNow).AddDays(-diasAtras).ToString("yyyy-MM-dd");

    private static Task<HttpResponseMessage> Salvar(HttpClient c, string data, object valores) =>
        c.PutAsJsonAsync($"/api/v1/me/medidas/{data}", new { valores });

    private static async Task<ResumoResposta> Resumo(HttpClient c) =>
        (await c.GetFromJsonAsync<ResumoResposta>("/api/v1/me/medidas"))!;

    private async Task<Guid> IdDoUsuario(string uid)
    {
        await using var db = _postgres.CriarContexto();
        return await db.Usuarios.Where(u => u.FirebaseUid == uid).Select(u => u.Id).SingleAsync();
    }

    // ---- Upsert e leitura ----

    [Fact]
    public async Task Salvar_dois_tipos_cria_so_esses_dois()
    {
        var a = NovoUsuario(_postgres);
        await using var _a = a.Api;

        var resp = await Salvar(a.Client, Hoje(), new { CINTURA = 83.0, PEITO = 102.5 });
        Assert.Equal(HttpStatusCode.OK, resp.StatusCode);

        var dia = await a.Client.GetFromJsonAsync<DiaResposta>($"/api/v1/me/medidas/{Hoje()}");
        Assert.Equal(2, dia!.Valores.Count);
        Assert.Equal(83.0m, dia.Valores["CINTURA"]);
        Assert.Equal(102.5m, dia.Valores["PEITO"]);

        var resumo = await Resumo(a.Client);
        Assert.Equal(["PEITO", "CINTURA"], resumo.Ultimas.Select(u => u.Tipo));
        Assert.Single(resumo.Historico);
        Assert.Equal(2, resumo.Historico[0].Quantidade);
    }

    [Fact]
    public async Task Salvar_no_mesmo_dia_atualiza_sem_duplicar()
    {
        var a = NovoUsuario(_postgres);
        await using var _a = a.Api;
        await Salvar(a.Client, Hoje(), new { CINTURA = 84.0 });

        var resp = await Salvar(a.Client, Hoje(), new { CINTURA = 83.0 });
        Assert.Equal(HttpStatusCode.OK, resp.StatusCode);

        var dia = await a.Client.GetFromJsonAsync<DiaResposta>($"/api/v1/me/medidas/{Hoje()}");
        Assert.Equal(83.0m, Assert.Single(dia!.Valores).Value);
        await using var db = _postgres.CriarContexto();
        var id = await IdDoUsuario(a.Uid);
        Assert.Equal(1, await db.MedidasCorporais.CountAsync(m => m.UsuarioId == id));
    }

    [Fact]
    public async Task Valor_nulo_remove_so_aquele_tipo_e_dia_vazio_e_400()
    {
        var a = NovoUsuario(_postgres);
        await using var _a = a.Api;
        await Salvar(a.Client, Hoje(), new { CINTURA = 84.0, PEITO = 100.0 });

        var resp = await Salvar(a.Client, Hoje(), new { PEITO = (double?)null });
        Assert.Equal(HttpStatusCode.OK, resp.StatusCode);
        var dia = await a.Client.GetFromJsonAsync<DiaResposta>($"/api/v1/me/medidas/{Hoje()}");
        Assert.Equal(["CINTURA"], dia!.Valores.Keys);

        // Remover o último tipo deixaria o dia vazio: 400 (para apagar, existe o DELETE).
        resp = await Salvar(a.Client, Hoje(), new { CINTURA = (double?)null });
        Assert.Equal(HttpStatusCode.BadRequest, resp.StatusCode);
        dia = await a.Client.GetFromJsonAsync<DiaResposta>($"/api/v1/me/medidas/{Hoje()}");
        Assert.Equal(84.0m, dia!.Valores["CINTURA"]);
    }

    [Fact]
    public async Task Variacao_compara_com_o_anterior_do_mesmo_tipo_mesmo_com_lacunas()
    {
        var a = NovoUsuario(_postgres);
        await using var _a = a.Api;
        await Salvar(a.Client, Hoje(60), new { CINTURA = 90.0 });
        await Salvar(a.Client, Hoje(20), new { PEITO = 100.0 });
        await Salvar(a.Client, Hoje(10), new { PEITO = 101.5 });
        await Salvar(a.Client, Hoje(), new { CINTURA = 88.5 });

        var resumo = await Resumo(a.Client);

        Assert.Equal(-1.5m, resumo.Ultimas.Single(u => u.Tipo == "CINTURA").Variacao);
        Assert.Equal(1.5m, resumo.Ultimas.Single(u => u.Tipo == "PEITO").Variacao);
        Assert.Equal(4, resumo.Historico.Count);
        Assert.Equal(Hoje(), resumo.Historico[0].Data);
    }

    [Fact]
    public async Task Primeira_medida_de_um_tipo_nao_tem_variacao()
    {
        var a = NovoUsuario(_postgres);
        await using var _a = a.Api;
        await Salvar(a.Client, Hoje(), new { PESO = 78.0 });

        var resumo = await Resumo(a.Client);
        Assert.Null(Assert.Single(resumo.Ultimas).Variacao);
    }

    // ---- Exclusão ----

    [Fact]
    public async Task Excluir_o_dia_apaga_tudo_dele_e_depois_e_404()
    {
        var a = NovoUsuario(_postgres);
        await using var _a = a.Api;
        await Salvar(a.Client, Hoje(), new { CINTURA = 84.0, PEITO = 100.0 });
        await Salvar(a.Client, Hoje(1), new { CINTURA = 85.0 });

        var resp = await a.Client.DeleteAsync($"/api/v1/me/medidas/{Hoje()}");
        Assert.Equal(HttpStatusCode.NoContent, resp.StatusCode);

        Assert.Equal(HttpStatusCode.NotFound, (await a.Client.GetAsync($"/api/v1/me/medidas/{Hoje()}")).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await a.Client.DeleteAsync($"/api/v1/me/medidas/{Hoje()}")).StatusCode);
        Assert.Single((await Resumo(a.Client)).Historico); // o dia de ontem continua
    }

    // ---- Validação (400) ----

    [Fact]
    public async Task Valida_data_futura_tipo_invalido_faixa_e_casa_decimal()
    {
        var a = NovoUsuario(_postgres);
        await using var _a = a.Api;

        var amanha = DateOnly.FromDateTime(DateTime.UtcNow).AddDays(1).ToString("yyyy-MM-dd");
        Assert.Equal(HttpStatusCode.BadRequest, (await Salvar(a.Client, amanha, new { CINTURA = 80.0 })).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await Salvar(a.Client, Hoje(), new { COTOVELO = 20.0 })).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await Salvar(a.Client, Hoje(), new { PESO = 29.0 })).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await Salvar(a.Client, Hoje(), new { PESO = 301.0 })).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await Salvar(a.Client, Hoje(), new { CINTURA = 4.0 })).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await Salvar(a.Client, Hoje(), new { CINTURA = 80.25 })).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await Salvar(a.Client, Hoje(), new { })).StatusCode);

        // Nada foi gravado.
        Assert.Empty((await Resumo(a.Client)).Historico);
    }

    [Fact]
    public async Task Erro_de_faixa_aponta_o_tipo_e_nao_devolve_o_valor_digitado()
    {
        var a = NovoUsuario(_postgres);
        await using var _a = a.Api;

        var resp = await Salvar(a.Client, Hoje(), new { PESO = 12.3 });
        Assert.Equal(HttpStatusCode.BadRequest, resp.StatusCode);

        var corpo = await resp.Content.ReadAsStringAsync();
        using var doc = JsonDocument.Parse(corpo);
        Assert.True(doc.RootElement.GetProperty("errors").TryGetProperty("PESO", out _));
        Assert.DoesNotContain("12,3", corpo);
        Assert.DoesNotContain("12.3", corpo);
    }

    // ---- Acesso ----

    [Fact]
    public async Task Sem_token_responde_401()
    {
        var api = new ApiFactory(_postgres.ConnectionString);
        await using var _a = api;
        var client = api.CreateClient();

        Assert.Equal(HttpStatusCode.Unauthorized, (await client.GetAsync("/api/v1/me/medidas")).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.GetAsync($"/api/v1/me/medidas/{Hoje()}")).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await Salvar(client, Hoje(), new { PESO = 70.0 })).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.DeleteAsync($"/api/v1/me/medidas/{Hoje()}")).StatusCode);
    }

    [Fact]
    public async Task Outro_usuario_nao_ve_nem_altera_as_medidas_do_dono()
    {
        var a = NovoUsuario(_postgres);
        var b = NovoUsuario(_postgres);
        await using var _a = a.Api;
        await using var _b = b.Api;
        await Salvar(a.Client, Hoje(), new { CINTURA = 84.0 });

        // B não enxerga: o dia dele não existe (404) e o resumo vem vazio.
        Assert.Equal(HttpStatusCode.NotFound, (await b.Client.GetAsync($"/api/v1/me/medidas/{Hoje()}")).StatusCode);
        var resumoB = await Resumo(b.Client);
        Assert.Empty(resumoB.Ultimas);
        Assert.Empty(resumoB.Historico);

        // B não apaga o dia de A (404) e o PUT de B grava só para B.
        Assert.Equal(HttpStatusCode.NotFound, (await b.Client.DeleteAsync($"/api/v1/me/medidas/{Hoje()}")).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await Salvar(b.Client, Hoje(), new { CINTURA = 70.0 })).StatusCode);

        var diaA = await a.Client.GetFromJsonAsync<DiaResposta>($"/api/v1/me/medidas/{Hoje()}");
        Assert.Equal(84.0m, diaA!.Valores["CINTURA"]);
    }

    // ---- Conta e esquema ----

    [Fact]
    public async Task Excluir_a_conta_apaga_as_medidas()
    {
        var a = NovoUsuario(_postgres);
        await using var _a = a.Api;
        await Salvar(a.Client, Hoje(), new { CINTURA = 84.0, PESO = 78.0 });
        var id = await IdDoUsuario(a.Uid);

        var resp = await a.Client.DeleteAsync("/api/v1/me");
        Assert.Equal(HttpStatusCode.NoContent, resp.StatusCode);

        await using var db = _postgres.CriarContexto();
        Assert.Equal(0, await db.MedidasCorporais.CountAsync(m => m.UsuarioId == id));
    }

    [Fact]
    public async Task Esquema_aplica_do_zero_e_o_banco_recusa_tipo_invalido_valor_nao_positivo_e_duplicata()
    {
        var a = NovoUsuario(_postgres);
        await using var _a = a.Api;
        await Salvar(a.Client, Hoje(), new { PESO = 70.0 });
        var id = await IdDoUsuario(a.Uid);

        await using var db = _postgres.CriarContexto();
        var hoje = DateOnly.FromDateTime(DateTime.UtcNow);

        db.MedidasCorporais.Add(new() { Id = Guid.NewGuid(), UsuarioId = id, Data = hoje, Tipo = "COTOVELO", Valor = 10m });
        await Assert.ThrowsAsync<DbUpdateException>(() => db.SaveChangesAsync());
        db.ChangeTracker.Clear();

        db.MedidasCorporais.Add(new() { Id = Guid.NewGuid(), UsuarioId = id, Data = hoje.AddDays(-1), Tipo = "PESO", Valor = 0m });
        await Assert.ThrowsAsync<DbUpdateException>(() => db.SaveChangesAsync());
        db.ChangeTracker.Clear();

        // Mesma (usuário, dia, tipo) do PUT acima: unicidade.
        db.MedidasCorporais.Add(new() { Id = Guid.NewGuid(), UsuarioId = id, Data = hoje, Tipo = "PESO", Valor = 71m });
        await Assert.ThrowsAsync<DbUpdateException>(() => db.SaveChangesAsync());
    }
}
