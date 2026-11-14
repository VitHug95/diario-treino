using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using DiarioTreino.IntegrationTests.Infraestrutura;
using Microsoft.EntityFrameworkCore;

namespace DiarioTreino.IntegrationTests;

/// <summary>
/// PBI-95: o atleta tranca e destranca os dados corporais e as medidas; o
/// educador com vínculo ATIVO lê só o que está destrancado. Matriz do educador
/// (ATIVO, PENDENTE, ENCERRADO, sem vínculo) × cadeado; sem vínculo é sempre
/// 404 (MAS 11.3) e o 403 só vem depois, na evolução trancada.
/// </summary>
[Collection(PostgresCollection.Nome)]
public sealed class CompartilhamentoCorporalEndpointTests
{
    private readonly PostgresFixture _postgres;

    public CompartilhamentoCorporalEndpointTests(PostgresFixture postgres)
    {
        _postgres = postgres;
    }

    private const string RotaMe = "/api/v1/me/compartilhamento-corporal";

    private sealed record CriadoResposta(Guid Id);
    private sealed record EducadorResp(Guid EducadorId, string Nome);
    private sealed record CompartilhamentoResp(
        bool DadosCorporais, DateTimeOffset? DadosCorporaisDesde,
        bool Medidas, DateTimeOffset? MedidasDesde, List<EducadorResp> Educadores);
    private sealed record PerfilResp(string? Sexo, short? AlturaCm, decimal? PesoKg, int? TmbKcal, bool TmbManual);
    private sealed record UltimaResp(string Tipo, decimal Valor);
    private sealed record ResumoResp(List<UltimaResp> Ultimas);
    private sealed record CorpoResp(
        bool DadosCorporaisCompartilhados, PerfilResp? DadosCorporais,
        bool MedidasCompartilhadas, ResumoResp? Medidas);
    private sealed record PontoResp(DateOnly Data, decimal Valor);
    private sealed record EvolucaoResp(string Tipo, List<PontoResp> Pontos);
    private sealed record ProblemaResp(string? Type, string? Title, string? Detail);

    private sealed record Usuario(ApiFactory Api, HttpClient Client, string Uid, string Email);

    private static Usuario NovoUsuario(PostgresFixture pg, string nome = "Pessoa")
    {
        var api = new ApiFactory(pg.ConnectionString);
        var client = api.CreateClient();
        var uid = $"uid-{Guid.NewGuid():n}";
        var email = $"{uid}@teste.local";
        var token = api.Tokens.Gerar(uid, email: email, nome: nome);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
        return new Usuario(api, client, uid, email);
    }

    private async Task<Guid> IdDoUsuario(string uid)
    {
        await using var db = _postgres.CriarContexto();
        return await db.Usuarios.Where(u => u.FirebaseUid == uid).Select(u => u.Id).SingleAsync();
    }

    private static async Task Provisionar(Usuario u) =>
        (await u.Client.GetAsync("/api/v1/me")).EnsureSuccessStatusCode();

    /// <summary>Educador e aluno; o convite fica no estado pedido.</summary>
    private async Task<(Usuario Educador, Usuario Aluno, Guid AlunoId)> Par(string estado)
    {
        var educador = NovoUsuario(_postgres, "Prof. Ana");
        var aluno = NovoUsuario(_postgres, "Aluno");
        await Provisionar(educador);
        await Provisionar(aluno);
        var alunoId = await IdDoUsuario(aluno.Uid);
        if (estado == "SEM") return (educador, aluno, alunoId);

        (await educador.Client.PostAsync("/api/v1/me/papeis/educador", null)).EnsureSuccessStatusCode();
        var convite = await educador.Client.PostAsJsonAsync("/api/v1/vinculos", new { email = aluno.Email });
        var vinculoId = (await convite.Content.ReadFromJsonAsync<CriadoResposta>())!.Id;
        if (estado == "PENDENTE") return (educador, aluno, alunoId);

        (await aluno.Client.PostAsync($"/api/v1/vinculos/{vinculoId}/aceitar", null)).EnsureSuccessStatusCode();
        if (estado == "ENCERRADO")
        {
            await using var db = _postgres.CriarContexto();
            var v = await db.Vinculos.SingleAsync(x => x.Id == vinculoId);
            v.Status = "ENCERRADO";
            v.Fim = DateTimeOffset.UtcNow;
            await db.SaveChangesAsync();
        }
        return (educador, aluno, alunoId);
    }

    private static Task<HttpResponseMessage> Definir(HttpClient c, bool dados, bool medidas) =>
        c.PutAsJsonAsync(RotaMe, new { dadosCorporais = dados, medidas });

    /// <summary>O aluno preenche dados corporais e uma medida de cintura.</summary>
    private static async Task PreencherCorpo(HttpClient aluno)
    {
        var hoje = DateOnly.FromDateTime(DateTime.UtcNow);
        (await aluno.PutAsJsonAsync("/api/v1/me/perfil-corporal", new
        {
            sexo = "M",
            dataNascimento = hoje.AddYears(-31).AddDays(-10).ToString("yyyy-MM-dd"),
            alturaCm = 180,
            pesoKg = 78.0,
        })).EnsureSuccessStatusCode();
        (await aluno.PutAsJsonAsync($"/api/v1/me/medidas/{hoje:yyyy-MM-dd}", new
        {
            valores = new Dictionary<string, double?> { ["CINTURA"] = 84.0 },
        })).EnsureSuccessStatusCode();
    }

    // ---- O atleta ----

    [Fact]
    public async Task Comeca_tudo_trancado_e_sem_educador()
    {
        var u = NovoUsuario(_postgres);
        await using var _a = u.Api;

        var c = await u.Client.GetFromJsonAsync<CompartilhamentoResp>(RotaMe);
        Assert.False(c!.DadosCorporais);
        Assert.False(c.Medidas);
        Assert.Null(c.DadosCorporaisDesde);
        Assert.Empty(c.Educadores);
    }

    [Fact]
    public async Task Destrancar_e_trancar_cada_cadeado_separado()
    {
        var u = NovoUsuario(_postgres);
        await using var _a = u.Api;

        var r = await Definir(u.Client, dados: false, medidas: true);
        Assert.Equal(HttpStatusCode.OK, r.StatusCode);
        var c = (await r.Content.ReadFromJsonAsync<CompartilhamentoResp>())!;
        Assert.False(c.DadosCorporais);
        Assert.True(c.Medidas);
        Assert.NotNull(c.MedidasDesde);

        // Destrancar de novo mantém o "desde"; trancar zera.
        var desde = c.MedidasDesde;
        var c2 = (await (await Definir(u.Client, dados: true, medidas: true)).Content
            .ReadFromJsonAsync<CompartilhamentoResp>())!;
        Assert.Equal(desde, c2.MedidasDesde);
        Assert.True(c2.DadosCorporais);

        var c3 = (await (await Definir(u.Client, dados: true, medidas: false)).Content
            .ReadFromJsonAsync<CompartilhamentoResp>())!;
        Assert.False(c3.Medidas);
        Assert.Null(c3.MedidasDesde);
        Assert.True(c3.DadosCorporais);
    }

    [Fact]
    public async Task Campo_ausente_responde_400_e_nao_tranca_nada()
    {
        var u = NovoUsuario(_postgres);
        await using var _a = u.Api;
        await Definir(u.Client, dados: true, medidas: true);

        var r = await u.Client.PutAsJsonAsync(RotaMe, new { dadosCorporais = false });
        Assert.Equal(HttpStatusCode.BadRequest, r.StatusCode);

        var c = await u.Client.GetFromJsonAsync<CompartilhamentoResp>(RotaMe);
        Assert.True(c!.DadosCorporais);
        Assert.True(c.Medidas);
    }

    [Fact]
    public async Task Lista_quem_ve_so_os_educadores_com_vinculo_ativo()
    {
        var (ativo, aluno, _) = await Par("ATIVO");
        await using var _e = ativo.Api;
        await using var _a = aluno.Api;
        // Um segundo educador, só com convite pendente: não vê.
        var pendente = NovoUsuario(_postgres, "Prof. Bia");
        await using var _p = pendente.Api;
        await Provisionar(pendente);
        (await pendente.Client.PostAsync("/api/v1/me/papeis/educador", null)).EnsureSuccessStatusCode();
        await pendente.Client.PostAsJsonAsync("/api/v1/vinculos", new { email = aluno.Email });

        var c = await aluno.Client.GetFromJsonAsync<CompartilhamentoResp>(RotaMe);
        var quem = Assert.Single(c!.Educadores);
        Assert.Equal("Prof. Ana", quem.Nome);
    }

    [Fact]
    public async Task Sem_token_responde_401()
    {
        await using var api = new ApiFactory(_postgres.ConnectionString);
        var anonimo = api.CreateClient();
        Assert.Equal(HttpStatusCode.Unauthorized, (await anonimo.GetAsync(RotaMe)).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized,
            (await anonimo.GetAsync($"/api/v1/alunos/{Guid.NewGuid()}/corpo")).StatusCode);
    }

    // ---- O educador ----

    [Fact]
    public async Task Com_vinculo_ativo_e_tudo_trancado_o_corpo_vem_sem_nenhum_valor()
    {
        var (educador, aluno, alunoId) = await Par("ATIVO");
        await using var _e = educador.Api;
        await using var _a = aluno.Api;
        await PreencherCorpo(aluno.Client);

        var corpo = await educador.Client.GetFromJsonAsync<CorpoResp>($"/api/v1/alunos/{alunoId}/corpo");
        Assert.False(corpo!.DadosCorporaisCompartilhados);
        Assert.Null(corpo.DadosCorporais);
        Assert.False(corpo.MedidasCompartilhadas);
        Assert.Null(corpo.Medidas);

        var evolucao = await educador.Client.GetAsync($"/api/v1/alunos/{alunoId}/medidas/CINTURA/evolucao");
        Assert.Equal(HttpStatusCode.Forbidden, evolucao.StatusCode);
        var problema = (await evolucao.Content.ReadFromJsonAsync<ProblemaResp>())!;
        Assert.Equal("corpo-nao-compartilhado", problema.Type);
        // A mensagem de erro não carrega valor corporal.
        Assert.DoesNotContain("84", problema.Title + problema.Detail);
    }

    [Fact]
    public async Task Cada_cadeado_libera_so_a_sua_parte()
    {
        var (educador, aluno, alunoId) = await Par("ATIVO");
        await using var _e = educador.Api;
        await using var _a = aluno.Api;
        await PreencherCorpo(aluno.Client);

        // Só os dados corporais.
        await Definir(aluno.Client, dados: true, medidas: false);
        var corpo = await educador.Client.GetFromJsonAsync<CorpoResp>($"/api/v1/alunos/{alunoId}/corpo");
        Assert.True(corpo!.DadosCorporaisCompartilhados);
        Assert.Equal((short)180, corpo.DadosCorporais!.AlturaCm);
        Assert.Equal(78.0m, corpo.DadosCorporais.PesoKg);
        Assert.NotNull(corpo.DadosCorporais.TmbKcal);
        Assert.Null(corpo.Medidas);
        Assert.Equal(HttpStatusCode.Forbidden,
            (await educador.Client.GetAsync($"/api/v1/alunos/{alunoId}/medidas/CINTURA/evolucao")).StatusCode);

        // Só as medidas.
        await Definir(aluno.Client, dados: false, medidas: true);
        corpo = await educador.Client.GetFromJsonAsync<CorpoResp>($"/api/v1/alunos/{alunoId}/corpo");
        Assert.Null(corpo!.DadosCorporais);
        Assert.Contains(corpo.Medidas!.Ultimas, m => m.Tipo == "CINTURA" && m.Valor == 84.0m);
        var evolucao = await educador.Client.GetFromJsonAsync<EvolucaoResp>(
            $"/api/v1/alunos/{alunoId}/medidas/CINTURA/evolucao");
        Assert.Equal(84.0m, Assert.Single(evolucao!.Pontos).Valor);
    }

    [Fact]
    public async Task Tmb_informada_pelo_aluno_aparece_como_informada()
    {
        var (educador, aluno, alunoId) = await Par("ATIVO");
        await using var _e = educador.Api;
        await using var _a = aluno.Api;
        await PreencherCorpo(aluno.Client);
        (await aluno.Client.PutAsJsonAsync("/api/v1/me/perfil-corporal/tmb-manual", new { kcal = 1800 }))
            .EnsureSuccessStatusCode();
        await Definir(aluno.Client, dados: true, medidas: false);

        var corpo = await educador.Client.GetFromJsonAsync<CorpoResp>($"/api/v1/alunos/{alunoId}/corpo");
        Assert.Equal(1800, corpo!.DadosCorporais!.TmbKcal);
        Assert.True(corpo.DadosCorporais.TmbManual);
    }

    [Fact]
    public async Task Trancar_corta_o_acesso_na_hora()
    {
        var (educador, aluno, alunoId) = await Par("ATIVO");
        await using var _e = educador.Api;
        await using var _a = aluno.Api;
        await PreencherCorpo(aluno.Client);
        await Definir(aluno.Client, dados: true, medidas: true);
        Assert.Equal(HttpStatusCode.OK,
            (await educador.Client.GetAsync($"/api/v1/alunos/{alunoId}/medidas/CINTURA/evolucao")).StatusCode);

        await Definir(aluno.Client, dados: false, medidas: false);

        var corpo = await educador.Client.GetFromJsonAsync<CorpoResp>($"/api/v1/alunos/{alunoId}/corpo");
        Assert.Null(corpo!.DadosCorporais);
        Assert.Null(corpo.Medidas);
        Assert.Equal(HttpStatusCode.Forbidden,
            (await educador.Client.GetAsync($"/api/v1/alunos/{alunoId}/medidas/CINTURA/evolucao")).StatusCode);
    }

    [Theory]
    [InlineData("PENDENTE")]
    [InlineData("ENCERRADO")]
    [InlineData("SEM")]
    public async Task Sem_vinculo_ativo_responde_404_mesmo_com_tudo_destrancado(string estado)
    {
        var (educador, aluno, alunoId) = await Par(estado);
        await using var _e = educador.Api;
        await using var _a = aluno.Api;
        await PreencherCorpo(aluno.Client);
        await Definir(aluno.Client, dados: true, medidas: true);

        Assert.Equal(HttpStatusCode.NotFound,
            (await educador.Client.GetAsync($"/api/v1/alunos/{alunoId}/corpo")).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound,
            (await educador.Client.GetAsync($"/api/v1/alunos/{alunoId}/medidas/CINTURA/evolucao")).StatusCode);
    }

    [Fact]
    public async Task O_proprio_atleta_e_aluno_inexistente_respondem_404_nas_rotas_do_educador()
    {
        var u = NovoUsuario(_postgres);
        await using var _a = u.Api;
        await Provisionar(u);
        var id = await IdDoUsuario(u.Uid);
        await Definir(u.Client, dados: true, medidas: true);

        Assert.Equal(HttpStatusCode.NotFound,
            (await u.Client.GetAsync($"/api/v1/alunos/{id}/corpo")).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound,
            (await u.Client.GetAsync($"/api/v1/alunos/{Guid.NewGuid()}/corpo")).StatusCode);
    }

    [Fact]
    public async Task Tipo_de_medida_invalido_responde_400_com_medidas_destrancadas()
    {
        var (educador, aluno, alunoId) = await Par("ATIVO");
        await using var _e = educador.Api;
        await using var _a = aluno.Api;
        await Definir(aluno.Client, dados: false, medidas: true);

        Assert.Equal(HttpStatusCode.BadRequest,
            (await educador.Client.GetAsync($"/api/v1/alunos/{alunoId}/medidas/XPTO/evolucao")).StatusCode);
    }

    [Fact]
    public async Task O_educador_nao_grava_nada_no_corpo_do_aluno()
    {
        var (educador, aluno, alunoId) = await Par("ATIVO");
        await using var _e = educador.Api;
        await using var _a = aluno.Api;
        await Definir(aluno.Client, dados: true, medidas: true);

        // Não existem rotas de escrita para o educador.
        var put = await educador.Client.PutAsJsonAsync($"/api/v1/alunos/{alunoId}/corpo", new { });
        Assert.Equal(HttpStatusCode.MethodNotAllowed, put.StatusCode);
    }

    [Fact]
    public async Task Get_me_continua_sem_dado_corporal()
    {
        var u = NovoUsuario(_postgres);
        await using var _a = u.Api;
        await Definir(u.Client, dados: true, medidas: true);

        var me = await u.Client.GetStringAsync("/api/v1/me");
        Assert.DoesNotContain("compartilhad", me, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("altura", me, StringComparison.OrdinalIgnoreCase);
    }
}
