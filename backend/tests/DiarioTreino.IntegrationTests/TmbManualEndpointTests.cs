using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using DiarioTreino.IntegrationTests.Infraestrutura;
using Microsoft.EntityFrameworkCore;

namespace DiarioTreino.IntegrationTests;

/// <summary>
/// PBI-98: TMB informada pelo atleta. PUT/DELETE /me/perfil-corporal/tmb-manual;
/// o GET devolve o valor efetivo (manual, senão calculado), o calculado e se é
/// manual. O manual sobrevive a mudar os dados, vale sem dados completos e para
/// menor de idade, e "Limpar dados corporais" apaga ele junto.
/// </summary>
[Collection(PostgresCollection.Nome)]
public sealed class TmbManualEndpointTests
{
    private const string Rota = "/api/v1/me/perfil-corporal";
    private const string RotaManual = "/api/v1/me/perfil-corporal/tmb-manual";

    private readonly PostgresFixture _postgres;

    public TmbManualEndpointTests(PostgresFixture postgres)
    {
        _postgres = postgres;
    }

    private sealed record Conta(ApiFactory Api, HttpClient Client, string Uid);
    private sealed record PerfilResposta(
        string? Sexo,
        string? DataNascimento,
        short? AlturaCm,
        decimal? PesoKg,
        int? Idade,
        int? TmbKcal,
        string? MotivoSemTmb,
        int? TmbCalculadaKcal,
        bool TmbManual);

    private static Conta NovoUsuario(PostgresFixture pg)
    {
        var api = new ApiFactory(pg.ConnectionString);
        var client = api.CreateClient();
        var uid = $"uid-{Guid.NewGuid():n}";
        var token = api.Tokens.Gerar(uid, email: $"{uid}@teste.local", nome: "Pessoa");
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
        return new Conta(api, client, uid);
    }

    private static DateOnly Hoje() => DateOnly.FromDateTime(DateTime.UtcNow);

    // 31 anos completos (aniversário 10 dias atrás).
    private static string Nasc31() => Hoje().AddYears(-31).AddDays(-10).ToString("yyyy-MM-dd");

    private static Task<HttpResponseMessage> SalvarDados(
        HttpClient c, string? sexo = "M", string? nascimento = null, int? altura = 180, double? peso = 78.0) =>
        c.PutAsJsonAsync(Rota, new
        {
            sexo,
            dataNascimento = nascimento ?? Nasc31(),
            alturaCm = altura,
            pesoKg = peso,
        });

    private static Task<HttpResponseMessage> DefinirManual(HttpClient c, object? kcal) =>
        c.PutAsJsonAsync(RotaManual, new { kcal });

    private static async Task<PerfilResposta> Obter(HttpClient c) =>
        (await c.GetFromJsonAsync<PerfilResposta>(Rota))!;

    private async Task<Guid> IdDoUsuario(string uid)
    {
        await using var db = _postgres.CriarContexto();
        return await db.Usuarios.Where(u => u.FirebaseUid == uid).Select(u => u.Id).SingleAsync();
    }

    [Fact]
    public async Task Sem_manual_o_efetivo_e_o_calculado()
    {
        var a = NovoUsuario(_postgres);
        await using var _a = a.Api;
        await SalvarDados(a.Client);

        var p = await Obter(a.Client);

        Assert.Equal(1755, p.TmbKcal);
        Assert.Equal(1755, p.TmbCalculadaKcal);
        Assert.False(p.TmbManual);
        Assert.Null(p.MotivoSemTmb);
    }

    [Fact]
    public async Task Put_e_get_ida_e_volta_com_o_valor_efetivo_e_o_calculado()
    {
        var a = NovoUsuario(_postgres);
        await using var _a = a.Api;
        await SalvarDados(a.Client);

        var resp = await DefinirManual(a.Client, 1800);
        Assert.Equal(HttpStatusCode.OK, resp.StatusCode);
        var devolvido = await resp.Content.ReadFromJsonAsync<PerfilResposta>();
        var lido = await Obter(a.Client);

        Assert.Equal(devolvido, lido);
        Assert.Equal(1800, lido.TmbKcal);
        Assert.Equal(1755, lido.TmbCalculadaKcal);
        Assert.True(lido.TmbManual);
        // O PUT da TMB não mexeu nos outros dados.
        Assert.Equal("M", lido.Sexo);
        Assert.Equal((short)180, lido.AlturaCm);
    }

    [Fact]
    public async Task O_manual_sobrevive_a_mudar_peso_altura_nascimento_e_sexo()
    {
        var a = NovoUsuario(_postgres);
        await using var _a = a.Api;
        await SalvarDados(a.Client);
        await DefinirManual(a.Client, 1800);

        await SalvarDados(a.Client, sexo: "F", altura: 165, peso: 60.0,
            nascimento: Hoje().AddYears(-40).AddDays(-10).ToString("yyyy-MM-dd"));

        var p = await Obter(a.Client);
        Assert.Equal(1800, p.TmbKcal);
        Assert.True(p.TmbManual);
        // A linha "Calculada" acompanha os dados novos: F, 40 anos, 165 cm, 60 kg.
        Assert.Equal(1270, p.TmbCalculadaKcal);
    }

    [Fact]
    public async Task Delete_volta_ao_automatico()
    {
        var a = NovoUsuario(_postgres);
        await using var _a = a.Api;
        await SalvarDados(a.Client);
        await DefinirManual(a.Client, 1800);

        var resp = await a.Client.DeleteAsync(RotaManual);
        Assert.Equal(HttpStatusCode.NoContent, resp.StatusCode);

        var p = await Obter(a.Client);
        Assert.Equal(1755, p.TmbKcal);
        Assert.False(p.TmbManual);

        // Idempotente: voltar ao automático de novo não é erro.
        Assert.Equal(HttpStatusCode.NoContent, (await a.Client.DeleteAsync(RotaManual)).StatusCode);
    }

    [Fact]
    public async Task Manual_vale_sem_dados_completos_e_o_motivo_do_calculo_continua()
    {
        var a = NovoUsuario(_postgres);
        await using var _a = a.Api;

        await DefinirManual(a.Client, 1800);

        var p = await Obter(a.Client);
        Assert.Equal(1800, p.TmbKcal);
        Assert.True(p.TmbManual);
        Assert.Null(p.TmbCalculadaKcal);
        Assert.Equal("DADOS_INCOMPLETOS", p.MotivoSemTmb);
    }

    [Fact]
    public async Task Manual_vale_para_menor_de_idade()
    {
        var a = NovoUsuario(_postgres);
        await using var _a = a.Api;
        await SalvarDados(a.Client, nascimento: Hoje().AddYears(-16).AddDays(-10).ToString("yyyy-MM-dd"));

        await DefinirManual(a.Client, 1500);

        var p = await Obter(a.Client);
        Assert.Equal(1500, p.TmbKcal);
        Assert.Null(p.TmbCalculadaKcal);
        Assert.Equal("MENOR_DE_IDADE", p.MotivoSemTmb);
    }

    [Fact]
    public async Task Fora_da_faixa_vazio_ou_quebrado_responde_400_e_nada_e_gravado()
    {
        var a = NovoUsuario(_postgres);
        await using var _a = a.Api;
        await SalvarDados(a.Client);

        foreach (var invalido in new object?[] { 799, 5001, 0, -1800, null, 1800.5 })
        {
            var resp = await DefinirManual(a.Client, invalido);
            Assert.Equal(HttpStatusCode.BadRequest, resp.StatusCode);
        }

        var p = await Obter(a.Client);
        Assert.False(p.TmbManual);
        Assert.Equal(1755, p.TmbKcal);
    }

    [Fact]
    public async Task Os_limites_800_e_5000_sao_aceitos()
    {
        var a = NovoUsuario(_postgres);
        await using var _a = a.Api;

        Assert.Equal(HttpStatusCode.OK, (await DefinirManual(a.Client, 800)).StatusCode);
        Assert.Equal(800, (await Obter(a.Client)).TmbKcal);
        Assert.Equal(HttpStatusCode.OK, (await DefinirManual(a.Client, 5000)).StatusCode);
        Assert.Equal(5000, (await Obter(a.Client)).TmbKcal);
    }

    [Fact]
    public async Task Erro_de_validacao_nao_devolve_o_valor_digitado()
    {
        var a = NovoUsuario(_postgres);
        await using var _a = a.Api;

        var resp = await DefinirManual(a.Client, 6123);
        var corpo = await resp.Content.ReadAsStringAsync();

        Assert.Equal(HttpStatusCode.BadRequest, resp.StatusCode);
        Assert.DoesNotContain("6123", corpo);
    }

    [Fact]
    public async Task Limpar_dados_corporais_apaga_o_manual_e_mantem_o_peso()
    {
        var a = NovoUsuario(_postgres);
        await using var _a = a.Api;
        await SalvarDados(a.Client);
        await DefinirManual(a.Client, 1800);

        Assert.Equal(HttpStatusCode.NoContent, (await a.Client.DeleteAsync(Rota)).StatusCode);

        var p = await Obter(a.Client);
        Assert.False(p.TmbManual);
        Assert.Null(p.TmbKcal);
        Assert.Null(p.Sexo);
        Assert.Equal(78.0m, p.PesoKg);
    }

    [Fact]
    public async Task Sem_token_responde_401()
    {
        var api = new ApiFactory(_postgres.ConnectionString);
        await using var _a = api;
        var client = api.CreateClient();

        Assert.Equal(HttpStatusCode.Unauthorized, (await DefinirManual(client, 1800)).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.DeleteAsync(RotaManual)).StatusCode);
    }

    [Fact]
    public async Task Outro_usuario_nao_ve_nem_altera_o_manual_do_dono()
    {
        var a = NovoUsuario(_postgres);
        var b = NovoUsuario(_postgres);
        await using var _a = a.Api;
        await using var _b = b.Api;
        await SalvarDados(a.Client);
        await DefinirManual(a.Client, 1800);

        var pb = await Obter(b.Client);
        Assert.False(pb.TmbManual);
        Assert.Null(pb.TmbKcal);

        // O que B grava e apaga é só de B.
        await DefinirManual(b.Client, 2500);
        Assert.Equal(HttpStatusCode.NoContent, (await b.Client.DeleteAsync(RotaManual)).StatusCode);

        var pa = await Obter(a.Client);
        Assert.Equal(1800, pa.TmbKcal);
        Assert.True(pa.TmbManual);
    }

    [Fact]
    public async Task Excluir_a_conta_apaga_o_manual()
    {
        var a = NovoUsuario(_postgres);
        await using var _a = a.Api;
        await DefinirManual(a.Client, 1800);
        var id = await IdDoUsuario(a.Uid);

        Assert.Equal(HttpStatusCode.NoContent, (await a.Client.DeleteAsync("/api/v1/me")).StatusCode);

        await using var db = _postgres.CriarContexto();
        Assert.False(await db.Usuarios.AnyAsync(u => u.Id == id));
    }

    [Fact]
    public async Task Esquema_aplica_do_zero_e_o_banco_recusa_tmb_fora_da_faixa()
    {
        var a = NovoUsuario(_postgres);
        await using var _a = a.Api;
        await DefinirManual(a.Client, 1800);
        var id = await IdDoUsuario(a.Uid);

        await using var db = _postgres.CriarContexto();
        var usuario = await db.Usuarios.SingleAsync(u => u.Id == id);
        Assert.Equal((short)1800, usuario.TmbManualKcal);

        usuario.TmbManualKcal = 700;
        await Assert.ThrowsAsync<DbUpdateException>(() => db.SaveChangesAsync());
        db.ChangeTracker.Clear();

        usuario = await db.Usuarios.SingleAsync(u => u.Id == id);
        usuario.TmbManualKcal = null; // nulo = automático, válido
        await db.SaveChangesAsync();
    }
}