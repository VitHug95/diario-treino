using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using DiarioTreino.IntegrationTests.Infraestrutura;
using Microsoft.EntityFrameworkCore;

namespace DiarioTreino.IntegrationTests;

/// <summary>
/// PBI-93: dados corporais e TMB (E12). Sob /me, só o dono. Sexo, nascimento e
/// altura ficam em usuario; o peso vem da medida PESO mais recente. O PUT com
/// pesoKg grava a medida do dia; o DELETE limpa os três campos e preserva o
/// histórico de peso. GET /me não muda.
/// </summary>
[Collection(PostgresCollection.Nome)]
public sealed class PerfilCorporalEndpointTests
{
    private const string Rota = "/api/v1/me/perfil-corporal";

    private readonly PostgresFixture _postgres;

    public PerfilCorporalEndpointTests(PostgresFixture postgres)
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
        string? MotivoSemTmb);
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

    private static DateOnly Hoje(int diasAtras = 0) =>
        DateOnly.FromDateTime(DateTime.UtcNow).AddDays(-diasAtras);

    // 31 anos completos (aniversário 10 dias atrás): a idade não vira no meio do teste.
    private static string Nasc31() => Hoje().AddYears(-31).AddDays(-10).ToString("yyyy-MM-dd");

    private static Task<HttpResponseMessage> Salvar(
        HttpClient c,
        string? sexo = "M",
        string? nascimento = null,
        int? altura = 180,
        double? peso = 78.0,
        string? dataPeso = null) =>
        c.PutAsJsonAsync(Rota, new
        {
            sexo,
            dataNascimento = nascimento ?? Nasc31(),
            alturaCm = altura,
            pesoKg = peso,
            dataPeso,
        });

    private static async Task<PerfilResposta> Obter(HttpClient c) =>
        (await c.GetFromJsonAsync<PerfilResposta>(Rota))!;

    private static Task<HttpResponseMessage> SalvarMedida(HttpClient c, string data, double peso) =>
        c.PutAsJsonAsync($"/api/v1/me/medidas/{data}", new
        {
            valores = new Dictionary<string, double?> { ["PESO"] = peso },
        });

    private async Task<Guid> IdDoUsuario(string uid)
    {
        await using var db = _postgres.CriarContexto();
        return await db.Usuarios.Where(u => u.FirebaseUid == uid).Select(u => u.Id).SingleAsync();
    }

    // ---- Leitura e TMB ----

    [Fact]
    public async Task Sem_dados_nao_ha_numero_e_o_motivo_e_dados_incompletos()
    {
        var a = NovoUsuario(_postgres);
        await using var _a = a.Api;

        var p = await Obter(a.Client);

        Assert.Null(p.Sexo);
        Assert.Null(p.DataNascimento);
        Assert.Null(p.AlturaCm);
        Assert.Null(p.PesoKg);
        Assert.Null(p.Idade);
        Assert.Null(p.TmbKcal);
        Assert.Equal("DADOS_INCOMPLETOS", p.MotivoSemTmb);
    }

    [Fact]
    public async Task Salvar_e_ler_vai_e_volta_com_a_tmb_calculada()
    {
        var a = NovoUsuario(_postgres);
        await using var _a = a.Api;

        var resp = await Salvar(a.Client);
        Assert.Equal(HttpStatusCode.OK, resp.StatusCode);
        var devolvido = await resp.Content.ReadFromJsonAsync<PerfilResposta>();

        var lido = await Obter(a.Client);
        Assert.Equal(devolvido, lido);
        Assert.Equal("M", lido.Sexo);
        Assert.Equal(Nasc31(), lido.DataNascimento);
        Assert.Equal((short)180, lido.AlturaCm);
        Assert.Equal(78.0m, lido.PesoKg);
        Assert.Equal(31, lido.Idade);
        Assert.Equal(1755, lido.TmbKcal); // M, 31 anos, 180 cm, 78,0 kg
        Assert.Null(lido.MotivoSemTmb);
    }

    [Fact]
    public async Task Mulher_usa_a_constante_menos_161()
    {
        var a = NovoUsuario(_postgres);
        await using var _a = a.Api;

        await Salvar(a.Client, sexo: "F", altura: 165, peso: 60.0);

        Assert.Equal(1315, (await Obter(a.Client)).TmbKcal); // F, 31 anos, 165 cm, 60,0 kg
    }

    [Fact]
    public async Task Menor_de_18_nao_tem_numero_e_o_motivo_e_menor_de_idade()
    {
        var a = NovoUsuario(_postgres);
        await using var _a = a.Api;

        var nasc17 = Hoje().AddYears(-17).AddDays(-10).ToString("yyyy-MM-dd");
        var resp = await Salvar(a.Client, nascimento: nasc17);
        Assert.Equal(HttpStatusCode.OK, resp.StatusCode);

        var p = await Obter(a.Client);
        Assert.Null(p.TmbKcal);
        Assert.Equal("MENOR_DE_IDADE", p.MotivoSemTmb);
        Assert.Equal(17, p.Idade);
    }

    [Fact]
    public async Task Faltando_um_dado_o_cartao_diz_que_esta_incompleto()
    {
        var a = NovoUsuario(_postgres);
        await using var _a = a.Api;

        await Salvar(a.Client, altura: null);

        var p = await Obter(a.Client);
        Assert.Null(p.TmbKcal);
        Assert.Equal("DADOS_INCOMPLETOS", p.MotivoSemTmb);
    }

    // ---- Peso: vem das medidas ----

    [Fact]
    public async Task Salvar_com_peso_cria_a_medida_PESO_de_hoje()
    {
        var a = NovoUsuario(_postgres);
        await using var _a = a.Api;

        await Salvar(a.Client, peso: 78.0);

        var dia = await a.Client.GetFromJsonAsync<DiaResposta>($"/api/v1/me/medidas/{Hoje():yyyy-MM-dd}");
        Assert.Equal(78.0m, dia!.Valores["PESO"]);
    }

    [Fact]
    public async Task Salvar_com_peso_no_mesmo_dia_atualiza_a_medida_sem_duplicar()
    {
        var a = NovoUsuario(_postgres);
        await using var _a = a.Api;

        await Salvar(a.Client, peso: 78.0);
        await Salvar(a.Client, peso: 79.5);

        var dia = await a.Client.GetFromJsonAsync<DiaResposta>($"/api/v1/me/medidas/{Hoje():yyyy-MM-dd}");
        Assert.Equal(79.5m, Assert.Single(dia!.Valores).Value);
        Assert.Equal(79.5m, (await Obter(a.Client)).PesoKg);
    }

    [Fact]
    public async Task Data_do_peso_do_app_vale_no_lugar_de_hoje_do_servidor()
    {
        var a = NovoUsuario(_postgres);
        await using var _a = a.Api;
        var ontem = Hoje(1).ToString("yyyy-MM-dd");

        await Salvar(a.Client, peso: 77.0, dataPeso: ontem);

        var dia = await a.Client.GetFromJsonAsync<DiaResposta>($"/api/v1/me/medidas/{ontem}");
        Assert.Equal(77.0m, dia!.Valores["PESO"]);
    }

    [Fact]
    public async Task Salvar_sem_peso_nao_mexe_no_historico_de_peso()
    {
        var a = NovoUsuario(_postgres);
        await using var _a = a.Api;
        await SalvarMedida(a.Client, Hoje(3).ToString("yyyy-MM-dd"), 80.0);

        var resp = await Salvar(a.Client, peso: null);
        Assert.Equal(HttpStatusCode.OK, resp.StatusCode);

        var p = await Obter(a.Client);
        Assert.Equal(80.0m, p.PesoKg); // o peso mais recente continua o das medidas
        Assert.Equal(1775, p.TmbKcal);
        var resumo = await a.Client.GetFromJsonAsync<JsonElement>("/api/v1/me/medidas");
        Assert.Equal(1, resumo.GetProperty("historico").GetArrayLength());
    }

    [Fact]
    public async Task Peso_novo_registrado_nas_medidas_muda_a_tmb()
    {
        var a = NovoUsuario(_postgres);
        await using var _a = a.Api;
        await Salvar(a.Client, peso: 78.0);
        Assert.Equal(1755, (await Obter(a.Client)).TmbKcal);

        await SalvarMedida(a.Client, Hoje().ToString("yyyy-MM-dd"), 80.0);

        var p = await Obter(a.Client);
        Assert.Equal(80.0m, p.PesoKg);
        Assert.Equal(1775, p.TmbKcal); // 800 + 1125 − 155 + 5
    }

    [Fact]
    public async Task O_peso_mais_recente_e_o_de_data_maior_nao_o_ultimo_gravado()
    {
        var a = NovoUsuario(_postgres);
        await using var _a = a.Api;
        await SalvarMedida(a.Client, Hoje().ToString("yyyy-MM-dd"), 78.0);
        await SalvarMedida(a.Client, Hoje(30).ToString("yyyy-MM-dd"), 90.0); // gravado depois, mas antigo

        Assert.Equal(78.0m, (await Obter(a.Client)).PesoKg);
    }

    // ---- Limpar ----

    [Fact]
    public async Task Put_com_tudo_nulo_limpa_sexo_nascimento_e_altura()
    {
        var a = NovoUsuario(_postgres);
        await using var _a = a.Api;
        await Salvar(a.Client);

        var resp = await a.Client.PutAsJsonAsync(Rota, new
        {
            sexo = (string?)null,
            dataNascimento = (string?)null,
            alturaCm = (int?)null,
            pesoKg = (double?)null,
        });
        Assert.Equal(HttpStatusCode.OK, resp.StatusCode);

        var p = await Obter(a.Client);
        Assert.Null(p.Sexo);
        Assert.Null(p.DataNascimento);
        Assert.Null(p.AlturaCm);
        Assert.Equal(78.0m, p.PesoKg); // o histórico de peso fica
    }

    [Fact]
    public async Task Delete_limpa_os_tres_campos_e_preserva_o_historico_de_peso()
    {
        var a = NovoUsuario(_postgres);
        await using var _a = a.Api;
        await Salvar(a.Client);

        var resp = await a.Client.DeleteAsync(Rota);
        Assert.Equal(HttpStatusCode.NoContent, resp.StatusCode);

        var p = await Obter(a.Client);
        Assert.Null(p.Sexo);
        Assert.Null(p.DataNascimento);
        Assert.Null(p.AlturaCm);
        Assert.Null(p.TmbKcal);
        Assert.Equal("DADOS_INCOMPLETOS", p.MotivoSemTmb);
        Assert.Equal(78.0m, p.PesoKg);
        var dia = await a.Client.GetFromJsonAsync<DiaResposta>($"/api/v1/me/medidas/{Hoje():yyyy-MM-dd}");
        Assert.Equal(78.0m, dia!.Valores["PESO"]);
    }

    // ---- Validação ----

    [Fact]
    public async Task Valores_fora_da_faixa_respondem_400_e_nada_e_gravado()
    {
        var a = NovoUsuario(_postgres);
        await using var _a = a.Api;

        Assert.Equal(HttpStatusCode.BadRequest, (await Salvar(a.Client, altura: 99)).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await Salvar(a.Client, altura: 251)).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await Salvar(a.Client, peso: 29.0)).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await Salvar(a.Client, peso: 301.0)).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await Salvar(a.Client, peso: 78.25)).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await Salvar(a.Client, sexo: "X")).StatusCode);
        var amanha = Hoje().AddDays(1).ToString("yyyy-MM-dd");
        Assert.Equal(HttpStatusCode.BadRequest, (await Salvar(a.Client, nascimento: amanha)).StatusCode);
        var nasc9 = Hoje().AddYears(-9).ToString("yyyy-MM-dd");
        Assert.Equal(HttpStatusCode.BadRequest, (await Salvar(a.Client, nascimento: nasc9)).StatusCode);
        var nasc101 = Hoje().AddYears(-101).ToString("yyyy-MM-dd");
        Assert.Equal(HttpStatusCode.BadRequest, (await Salvar(a.Client, nascimento: nasc101)).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await Salvar(a.Client, peso: 78.0, dataPeso: amanha)).StatusCode);

        var p = await Obter(a.Client);
        Assert.Null(p.Sexo);
        Assert.Null(p.AlturaCm);
        Assert.Null(p.PesoKg);
    }

    [Fact]
    public async Task Erro_de_validacao_nao_devolve_o_valor_digitado()
    {
        var a = NovoUsuario(_postgres);
        await using var _a = a.Api;

        var resp = await Salvar(a.Client, altura: 77, peso: 12.3);
        Assert.Equal(HttpStatusCode.BadRequest, resp.StatusCode);

        var corpo = await resp.Content.ReadAsStringAsync();
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

        Assert.Equal(HttpStatusCode.Unauthorized, (await client.GetAsync(Rota)).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await Salvar(client)).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.DeleteAsync(Rota)).StatusCode);
    }

    [Fact]
    public async Task Outro_usuario_nao_ve_nem_altera_os_dados_do_dono()
    {
        var a = NovoUsuario(_postgres);
        var b = NovoUsuario(_postgres);
        await using var _a = a.Api;
        await using var _b = b.Api;
        await Salvar(a.Client);

        // B só alcança o que é dele: os dados de A não aparecem.
        var pb = await Obter(b.Client);
        Assert.Null(pb.Sexo);
        Assert.Null(pb.AlturaCm);
        Assert.Null(pb.PesoKg);
        Assert.Null(pb.TmbKcal);

        // O que B grava e apaga é só de B.
        await Salvar(b.Client, sexo: "F", altura: 165, peso: 60.0);
        Assert.Equal(HttpStatusCode.NoContent, (await b.Client.DeleteAsync(Rota)).StatusCode);

        var pa = await Obter(a.Client);
        Assert.Equal("M", pa.Sexo);
        Assert.Equal((short)180, pa.AlturaCm);
        Assert.Equal(1755, pa.TmbKcal);
    }

    // ---- GET /me, conta e esquema ----

    [Fact]
    public async Task Get_me_nao_traz_dados_corporais()
    {
        var a = NovoUsuario(_postgres);
        await using var _a = a.Api;
        await Salvar(a.Client);

        var me = await a.Client.GetFromJsonAsync<JsonElement>("/api/v1/me");

        var chaves = me.EnumerateObject().Select(p => p.Name.ToLowerInvariant()).ToList();
        Assert.Equal(["id", "nome", "email", "papeis"], chaves);
    }

    [Fact]
    public async Task Excluir_a_conta_apaga_os_dados_corporais()
    {
        var a = NovoUsuario(_postgres);
        await using var _a = a.Api;
        await Salvar(a.Client);
        var id = await IdDoUsuario(a.Uid);

        Assert.Equal(HttpStatusCode.NoContent, (await a.Client.DeleteAsync("/api/v1/me")).StatusCode);

        // As colunas moram na própria linha de usuario: sumiram com ela, e o peso
        // saiu por cascata.
        await using var db = _postgres.CriarContexto();
        Assert.False(await db.Usuarios.AnyAsync(u => u.Id == id));
        Assert.Equal(0, await db.MedidasCorporais.CountAsync(m => m.UsuarioId == id));
    }

    [Fact]
    public async Task Esquema_aplica_do_zero_e_o_banco_recusa_sexo_e_altura_invalidos()
    {
        var a = NovoUsuario(_postgres);
        await using var _a = a.Api;
        await Salvar(a.Client);
        var id = await IdDoUsuario(a.Uid);

        await using var db = _postgres.CriarContexto();
        var usuario = await db.Usuarios.SingleAsync(u => u.Id == id);

        usuario.Sexo = "X";
        await Assert.ThrowsAsync<DbUpdateException>(() => db.SaveChangesAsync());
        db.ChangeTracker.Clear();

        usuario = await db.Usuarios.SingleAsync(u => u.Id == id);
        usuario.AlturaCm = 50;
        await Assert.ThrowsAsync<DbUpdateException>(() => db.SaveChangesAsync());
        db.ChangeTracker.Clear();

        // Nulo é válido: os dados corporais são opcionais.
        usuario = await db.Usuarios.SingleAsync(u => u.Id == id);
        usuario.Sexo = null;
        usuario.AlturaCm = null;
        usuario.DataNascimento = null;
        await db.SaveChangesAsync();
    }
}
