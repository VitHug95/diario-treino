using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using DiarioTreino.IntegrationTests.Infraestrutura;
using Microsoft.EntityFrameworkCore;

namespace DiarioTreino.IntegrationTests;

/// <summary>
/// Regra do autor na ficha (MAS 11.3, regra 11 do MER): como no plano, só o
/// autor do plano edita a ficha, os exercícios, os alvos, a ordem e os blocos.
/// O aluno lê, treina e duplica a ficha do professor, mas qualquer escrita
/// responde 403 <c>plano-somente-leitura</c>, sempre depois do 404 de acesso.
/// </summary>
[Collection(PostgresCollection.Nome)]
public sealed class FichaAutorEndpointTests
{
    private readonly PostgresFixture _postgres;

    public FichaAutorEndpointTests(PostgresFixture postgres)
    {
        _postgres = postgres;
    }

    private sealed record CriadoResp(Guid Id);
    private sealed record TeResp(Guid Id, short Ordem, Guid? BlocoId);
    private sealed record FichaResp(Guid Id, string Nome, List<TeResp> Exercicios, bool SomenteLeitura);
    private sealed record ProblemaResp(string? Type);

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

    private async Task<List<Guid>> ExerciciosDoSeed(int quantos)
    {
        await using var db = _postgres.CriarContexto();
        return await db.Exercicios
            .Where(e => e.CriadoPorId == null && e.Ativo)
            .OrderBy(e => e.Id)
            .Select(e => e.Id)
            .Take(quantos)
            .ToListAsync();
    }

    /// <summary>
    /// Educador e aluno com vínculo ativo, e um plano do educador para o aluno
    /// com uma ficha de três exercícios (os dois primeiros num bloco).
    /// </summary>
    private async Task<(Usuario Educador, Usuario Aluno, Guid PlanoId, Guid TreinoId, List<Guid> Tes, Guid BlocoId)>
        PlanoDoProfessor()
    {
        var educador = NovoUsuario(_postgres);
        var aluno = NovoUsuario(_postgres);
        (await educador.Client.GetAsync("/api/v1/me")).EnsureSuccessStatusCode();
        (await aluno.Client.GetAsync("/api/v1/me")).EnsureSuccessStatusCode();
        (await educador.Client.PostAsync("/api/v1/me/papeis/educador", null)).EnsureSuccessStatusCode();
        var convite = await educador.Client.PostAsJsonAsync("/api/v1/vinculos", new { email = aluno.Email });
        var vinculoId = (await convite.Content.ReadFromJsonAsync<CriadoResp>())!.Id;
        (await aluno.Client.PostAsync($"/api/v1/vinculos/{vinculoId}/aceitar", null)).EnsureSuccessStatusCode();

        Guid alunoId;
        await using (var db = _postgres.CriarContexto())
        {
            alunoId = await db.Usuarios.Where(u => u.FirebaseUid == aluno.Uid).Select(u => u.Id).SingleAsync();
        }

        var plano = await educador.Client.PostAsJsonAsync("/api/v1/planos", new { nome = "Do professor", atletaId = alunoId });
        plano.EnsureSuccessStatusCode();
        var planoId = (await plano.Content.ReadFromJsonAsync<CriadoResp>())!.Id;
        var ficha = await educador.Client.PostAsJsonAsync($"/api/v1/planos/{planoId}/treinos",
            new { nome = "A", descricao = (string?)null });
        ficha.EnsureSuccessStatusCode();
        var treinoId = (await ficha.Content.ReadFromJsonAsync<CriadoResp>())!.Id;
        var tes = new List<Guid>();
        foreach (var exercicioId in await ExerciciosDoSeed(3))
        {
            var r = await educador.Client.PostAsJsonAsync($"/api/v1/treinos/{treinoId}/exercicios", new { exercicioId });
            r.EnsureSuccessStatusCode();
            tes.Add((await r.Content.ReadFromJsonAsync<CriadoResp>())!.Id);
        }
        var bloco = await educador.Client.PostAsJsonAsync($"/api/v1/treinos/{treinoId}/blocos",
            new { treinoExercicioIds = new[] { tes[0], tes[1] }, descansoSeg = (short?)30 });
        bloco.EnsureSuccessStatusCode();
        var blocoId = (await bloco.Content.ReadFromJsonAsync<CriadoResp>())!.Id;

        return (educador, aluno, planoId, treinoId, tes, blocoId);
    }

    /// <summary>Todas as escritas da ficha, com um corpo válido.</summary>
    private static async Task<List<(string Rota, HttpResponseMessage Resposta)>> TodasAsEscritas(
        HttpClient c, Guid treinoId, List<Guid> tes, Guid blocoId)
    {
        return
        [
            ("PUT ficha", await c.PutAsJsonAsync($"/api/v1/treinos/{treinoId}", new { nome = "Mudada", descricao = (string?)null })),
            ("PUT alvos", await c.PutAsJsonAsync($"/api/v1/treinos/{treinoId}/exercicios/{tes[2]}/alvos",
                new { series = 5, intensidadeMetricaId = 1, volumeMetricaId = 10, descansoSeg = 60 })),
            ("PUT ordem", await c.PutAsJsonAsync($"/api/v1/treinos/{treinoId}/exercicios/ordem",
                new { treinoExercicioIds = new[] { tes[2], tes[0], tes[1] } })),
            ("PUT descanso do bloco", await c.PutAsJsonAsync($"/api/v1/treinos/{treinoId}/blocos/{blocoId}",
                new { descansoSeg = (short?)90 })),
            ("PUT membros", await c.PutAsJsonAsync($"/api/v1/treinos/{treinoId}/blocos/{blocoId}/membros",
                new { treinoExercicioIds = new[] { tes[0], tes[1], tes[2] } })),
            // Na ordem em que o autor consegue fazer tudo: desfaz antes de juntar de novo.
            ("DELETE bloco", await c.DeleteAsync($"/api/v1/treinos/{treinoId}/blocos/{blocoId}")),
            ("POST bloco", await c.PostAsJsonAsync($"/api/v1/treinos/{treinoId}/blocos",
                new { treinoExercicioIds = new[] { tes[2], tes[1] }, descansoSeg = (short?)30 })),
            ("DELETE exercício", await c.DeleteAsync($"/api/v1/treinos/{treinoId}/exercicios/{tes[2]}")),
            ("DELETE ficha", await c.DeleteAsync($"/api/v1/treinos/{treinoId}")),
        ];
    }

    [Fact]
    public async Task Aluno_recebe_403_em_toda_escrita_da_ficha_do_professor_e_nada_muda()
    {
        var (educador, aluno, _, treinoId, tes, blocoId) = await PlanoDoProfessor();
        await using var _e = educador.Api;
        await using var _a = aluno.Api;

        foreach (var (rota, r) in await TodasAsEscritas(aluno.Client, treinoId, tes, blocoId))
        {
            Assert.True(r.StatusCode == HttpStatusCode.Forbidden, $"{rota}: {(int)r.StatusCode}");
            var problema = await r.Content.ReadFromJsonAsync<ProblemaResp>();
            Assert.EndsWith("plano-somente-leitura", problema!.Type);
        }

        // Adicionar exercício também.
        var extra = (await ExerciciosDoSeed(4))[3];
        var add = await aluno.Client.PostAsJsonAsync($"/api/v1/treinos/{treinoId}/exercicios", new { exercicioId = extra });
        Assert.Equal(HttpStatusCode.Forbidden, add.StatusCode);

        // A ficha continua como o educador deixou, e o aluno ainda lê.
        var ficha = await aluno.Client.GetFromJsonAsync<FichaResp>($"/api/v1/treinos/{treinoId}");
        Assert.Equal("A", ficha!.Nome);
        Assert.True(ficha.SomenteLeitura);
        Assert.Equal(tes, ficha.Exercicios.OrderBy(e => e.Ordem).Select(e => e.Id));
        Assert.Equal(2, ficha.Exercicios.Count(e => e.BlocoId == blocoId));
    }

    [Fact]
    public async Task Educador_autor_continua_editando_tudo()
    {
        var (educador, aluno, _, treinoId, tes, blocoId) = await PlanoDoProfessor();
        await using var _e = educador.Api;
        await using var _a = aluno.Api;

        foreach (var (rota, r) in await TodasAsEscritas(educador.Client, treinoId, tes, blocoId))
        {
            Assert.True(r.IsSuccessStatusCode, $"{rota}: {(int)r.StatusCode}");
        }
    }

    [Fact]
    public async Task Terceiro_recebe_404_e_nao_403()
    {
        var (educador, aluno, _, treinoId, tes, blocoId) = await PlanoDoProfessor();
        var terceiro = NovoUsuario(_postgres);
        await using var _e = educador.Api;
        await using var _a = aluno.Api;
        await using var _t = terceiro.Api;
        (await terceiro.Client.GetAsync("/api/v1/me")).EnsureSuccessStatusCode();

        foreach (var (rota, r) in await TodasAsEscritas(terceiro.Client, treinoId, tes, blocoId))
        {
            Assert.True(r.StatusCode == HttpStatusCode.NotFound, $"{rota}: {(int)r.StatusCode}");
        }
    }

    [Fact]
    public async Task Aluno_continua_editando_a_ficha_que_ele_mesmo_criou()
    {
        var aluno = NovoUsuario(_postgres);
        await using var _a = aluno.Api;
        var plano = await (await aluno.Client.PostAsJsonAsync("/api/v1/planos", new { nome = "Meu" }))
            .Content.ReadFromJsonAsync<CriadoResp>();
        var ficha = await (await aluno.Client.PostAsJsonAsync($"/api/v1/planos/{plano!.Id}/treinos",
            new { nome = "A", descricao = (string?)null })).Content.ReadFromJsonAsync<CriadoResp>();

        var r = await aluno.Client.PutAsJsonAsync($"/api/v1/treinos/{ficha!.Id}", new { nome = "B", descricao = (string?)null });

        Assert.Equal(HttpStatusCode.NoContent, r.StatusCode);
    }

    [Fact]
    public async Task Salvar_treino_livre_como_ficha_com_o_plano_do_professor_em_uso_da_403_sem_criar_nada()
    {
        var (educador, aluno, planoId, _, _, _) = await PlanoDoProfessor();
        await using var _e = educador.Api;
        await using var _a = aluno.Api;
        (await aluno.Client.PostAsync($"/api/v1/planos/{planoId}/em-uso", null)).EnsureSuccessStatusCode();
        await using var db = _postgres.CriarContexto();
        var antes = await db.Treinos.CountAsync(t => t.PlanoId == planoId);

        var r = await aluno.Client.PostAsJsonAsync("/api/v1/planos/fichas-de-treino", new
        {
            nome = "Treino de hoje",
            descricao = (string?)null,
            exercicioIds = await ExerciciosDoSeed(1),
        });

        Assert.Equal(HttpStatusCode.Forbidden, r.StatusCode);
        Assert.Equal(antes, await db.Treinos.CountAsync(t => t.PlanoId == planoId));
    }
}
