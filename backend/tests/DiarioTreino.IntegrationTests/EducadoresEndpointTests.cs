using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using DiarioTreino.IntegrationTests.Infraestrutura;
using Microsoft.EntityFrameworkCore;

namespace DiarioTreino.IntegrationTests;

/// <summary>
/// PBI-104: <c>GET /educadores</c> lista os educadores com vínculo ATIVO do aluno
/// logado (espelha o <c>GET /alunos</c>). Pendente, recusado e encerrado não
/// entram; vínculos de outro aluno não vazam; encerrar tira da lista e corta o
/// acesso do educador na hora.
/// </summary>
[Collection(PostgresCollection.Nome)]
public sealed class EducadoresEndpointTests
{
    private readonly PostgresFixture _postgres;

    public EducadoresEndpointTests(PostgresFixture postgres)
    {
        _postgres = postgres;
    }

    private const string Rota = "/api/v1/educadores";

    private sealed record CriadoResposta(Guid Id);
    private sealed record EducadorResp(
        Guid VinculoId, Guid EducadorId, string EducadorNome, string EducadorEmail, DateTimeOffset? Desde);

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

    private static async Task Provisionar(Usuario u) =>
        (await u.Client.GetAsync("/api/v1/me")).EnsureSuccessStatusCode();

    private static async Task<Usuario> NovoEducador(PostgresFixture pg, string nome)
    {
        var e = NovoUsuario(pg, nome);
        await Provisionar(e);
        (await e.Client.PostAsync("/api/v1/me/papeis/educador", content: null)).EnsureSuccessStatusCode();
        return e;
    }

    private static async Task<Guid> Convidar(Usuario educador, Usuario aluno)
    {
        var r = await educador.Client.PostAsJsonAsync("/api/v1/vinculos", new { email = aluno.Email });
        r.EnsureSuccessStatusCode();
        return (await r.Content.ReadFromJsonAsync<CriadoResposta>())!.Id;
    }

    private static async Task Acao(Usuario quem, Guid vinculoId, string acao) =>
        (await quem.Client.PostAsync($"/api/v1/vinculos/{vinculoId}/{acao}", content: null))
            .EnsureSuccessStatusCode();

    private async Task<Guid> IdDoUsuario(string uid)
    {
        await using var db = _postgres.CriarContexto();
        return await db.Usuarios.Where(u => u.FirebaseUid == uid).Select(u => u.Id).SingleAsync();
    }

    [Fact]
    public async Task Lista_so_os_vinculos_ativos_do_aluno_com_nome_email_e_desde()
    {
        var aluno = NovoUsuario(_postgres, "Aluno");
        await using var _a = aluno.Api;
        await Provisionar(aluno);

        var ativo = await NovoEducador(_postgres, "Prof. Ana");
        var pendente = await NovoEducador(_postgres, "Prof. Bia");
        var recusado = await NovoEducador(_postgres, "Prof. Caio");
        var encerrado = await NovoEducador(_postgres, "Prof. Davi");
        await using var _e1 = ativo.Api;
        await using var _e2 = pendente.Api;
        await using var _e3 = recusado.Api;
        await using var _e4 = encerrado.Api;

        var vAtivo = await Convidar(ativo, aluno);
        await Acao(aluno, vAtivo, "aceitar");
        await Convidar(pendente, aluno);
        await Acao(aluno, await Convidar(recusado, aluno), "recusar");
        var vEncerrado = await Convidar(encerrado, aluno);
        await Acao(aluno, vEncerrado, "aceitar");
        await Acao(encerrado, vEncerrado, "encerrar");

        var lista = await aluno.Client.GetFromJsonAsync<List<EducadorResp>>(Rota);

        var unico = Assert.Single(lista!);
        Assert.Equal(vAtivo, unico.VinculoId);
        Assert.Equal(await IdDoUsuario(ativo.Uid), unico.EducadorId);
        Assert.Equal("Prof. Ana", unico.EducadorNome);
        Assert.Equal(ativo.Email, unico.EducadorEmail);
        Assert.NotNull(unico.Desde);
    }

    [Fact]
    public async Task Ordena_do_vinculo_mais_recente_ao_mais_antigo()
    {
        var aluno = NovoUsuario(_postgres, "Aluno");
        await using var _a = aluno.Api;
        await Provisionar(aluno);
        var antigo = await NovoEducador(_postgres, "Prof. Antigo");
        var novo = await NovoEducador(_postgres, "Prof. Novo");
        await using var _e1 = antigo.Api;
        await using var _e2 = novo.Api;

        // Aceita o "novo" primeiro e recua a data do "antigo" no banco.
        var vNovo = await Convidar(novo, aluno);
        await Acao(aluno, vNovo, "aceitar");
        var vAntigo = await Convidar(antigo, aluno);
        await Acao(aluno, vAntigo, "aceitar");
        await using (var db = _postgres.CriarContexto())
        {
            var v = await db.Vinculos.SingleAsync(x => x.Id == vAntigo);
            v.Inicio = DateTimeOffset.UtcNow.AddDays(-30);
            await db.SaveChangesAsync();
        }

        var lista = await aluno.Client.GetFromJsonAsync<List<EducadorResp>>(Rota);

        Assert.Equal(new[] { vNovo, vAntigo }, lista!.Select(e => e.VinculoId));
    }

    [Fact]
    public async Task Nao_vaza_vinculos_de_outro_aluno()
    {
        var aluno = NovoUsuario(_postgres, "Aluno");
        var outro = NovoUsuario(_postgres, "Outro");
        await using var _a = aluno.Api;
        await using var _o = outro.Api;
        await Provisionar(aluno);
        await Provisionar(outro);
        var educador = await NovoEducador(_postgres, "Prof. Ana");
        await using var _e = educador.Api;
        await Acao(outro, await Convidar(educador, outro), "aceitar");

        var lista = await aluno.Client.GetFromJsonAsync<List<EducadorResp>>(Rota);
        Assert.Empty(lista!);

        // O próprio educador, do lado dele, também não tem educadores.
        var doEducador = await educador.Client.GetFromJsonAsync<List<EducadorResp>>(Rota);
        Assert.Empty(doEducador!);
    }

    [Fact]
    public async Task Encerrar_tira_da_lista_corta_o_acesso_e_nao_apaga_dados()
    {
        var aluno = NovoUsuario(_postgres, "Aluno");
        await using var _a = aluno.Api;
        await Provisionar(aluno);
        var educador = await NovoEducador(_postgres, "Prof. Ana");
        await using var _e = educador.Api;
        var vinculo = await Convidar(educador, aluno);
        await Acao(aluno, vinculo, "aceitar");
        var alunoId = await IdDoUsuario(aluno.Uid);
        (await aluno.Client.PutAsJsonAsync("/api/v1/me/medidas/2026-11-01", new { valores = new Dictionary<string, decimal> { ["CINTURA"] = 84.0m } }))
            .EnsureSuccessStatusCode();

        var leitura = $"/api/v1/sessoes?de=2026-01-01&ate=2026-12-31&atletaId={alunoId}";
        Assert.Equal(HttpStatusCode.OK, (await educador.Client.GetAsync(leitura)).StatusCode);

        // O aluno encerra.
        var r = await aluno.Client.PostAsync($"/api/v1/vinculos/{vinculo}/encerrar", content: null);
        Assert.Equal(HttpStatusCode.NoContent, r.StatusCode);

        Assert.Empty((await aluno.Client.GetFromJsonAsync<List<EducadorResp>>(Rota))!);
        Assert.Equal(HttpStatusCode.NotFound, (await educador.Client.GetAsync(leitura)).StatusCode);
        var alunos = await educador.Client.GetFromJsonAsync<List<object>>("/api/v1/alunos");
        Assert.Empty(alunos!);

        // Nada do aluno foi apagado.
        Assert.Equal(HttpStatusCode.OK, (await aluno.Client.GetAsync("/api/v1/me/medidas/2026-11-01")).StatusCode);

        // Encerrar de novo: 409.
        var de_novo = await aluno.Client.PostAsync($"/api/v1/vinculos/{vinculo}/encerrar", content: null);
        Assert.Equal(HttpStatusCode.Conflict, de_novo.StatusCode);
    }

    [Fact]
    public async Task Educador_que_excluiu_a_conta_some_da_lista()
    {
        var aluno = NovoUsuario(_postgres, "Aluno");
        await using var _a = aluno.Api;
        await Provisionar(aluno);
        var educador = await NovoEducador(_postgres, "Prof. Ana");
        await using var _e = educador.Api;
        await Acao(aluno, await Convidar(educador, aluno), "aceitar");

        (await educador.Client.DeleteAsync("/api/v1/me")).EnsureSuccessStatusCode();

        var r = await aluno.Client.GetAsync(Rota);
        Assert.Equal(HttpStatusCode.OK, r.StatusCode);
        Assert.Empty((await r.Content.ReadFromJsonAsync<List<EducadorResp>>())!);
    }

    [Fact]
    public async Task Sem_token_responde_401()
    {
        await using var api = new ApiFactory(_postgres.ConnectionString);
        var anonimo = api.CreateClient();
        Assert.Equal(HttpStatusCode.Unauthorized, (await anonimo.GetAsync(Rota)).StatusCode);
    }
}
