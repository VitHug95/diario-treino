using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using DiarioTreino.Domain.Execucao;
using DiarioTreino.Domain.Identidade;
using DiarioTreino.Domain.Planejamento;
using DiarioTreino.IntegrationTests.Infraestrutura;
using Microsoft.EntityFrameworkCore;

namespace DiarioTreino.IntegrationTests;

/// <summary>
/// PBI-35: semana planejada do plano (ficha por dia). PUT /planos/{id}/semana
/// substitui a semana; ela volta no detalhe e no plano em uso. Opcional (plano
/// sem semana devolve lista vazia), uma ficha por dia, só fichas ativas do
/// plano. Acesso: outro usuário 404; plano de outro autor 403; educador autor
/// edita. Excluir/arquivar ficha libera os dias; duplicar leva a semana.
/// </summary>
[Collection(PostgresCollection.Nome)]
public sealed class PlanoSemanaEndpointTests
{
    private readonly PostgresFixture _postgres;

    public PlanoSemanaEndpointTests(PostgresFixture postgres)
    {
        _postgres = postgres;
    }

    private sealed record CriadoResposta(Guid Id);
    private sealed record DiaResposta(short DiaSemana, Guid TreinoId);
    private sealed record PlanoDetalheResposta(Guid Id, string Nome, List<DiaResposta> Semana);
    private sealed record PlanoAtivoResposta(Guid Id, string Nome, List<DiaResposta> Semana);
    // "Conta" (e não "Usuario"): Usuario é a entidade do domínio usada no seed.
    private sealed record Conta(ApiFactory Api, HttpClient Client, string Uid, string Email);

    private static Conta NovoUsuario(PostgresFixture pg)
    {
        var api = new ApiFactory(pg.ConnectionString);
        var client = api.CreateClient();
        var uid = $"uid-{Guid.NewGuid():n}";
        var email = $"{uid}@teste.local";
        var token = api.Tokens.Gerar(uid, email: email, nome: "Pessoa");
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
        return new Conta(api, client, uid, email);
    }

    private async Task<Guid> IdDoUsuario(string uid)
    {
        await using var db = _postgres.CriarContexto();
        return await db.Usuarios.Where(u => u.FirebaseUid == uid).Select(u => u.Id).SingleAsync();
    }

    private static async Task Provisionar(Conta u) =>
        (await u.Client.GetAsync("/api/v1/me")).EnsureSuccessStatusCode();

    private static async Task<Guid> CriarPlano(HttpClient client, string nome, Guid? atletaId = null)
    {
        var resp = await client.PostAsJsonAsync("/api/v1/planos", new { nome, atletaId });
        resp.EnsureSuccessStatusCode();
        return (await resp.Content.ReadFromJsonAsync<CriadoResposta>())!.Id;
    }

    private static async Task<Guid> CriarFicha(HttpClient client, Guid planoId, string nome)
    {
        var resp = await client.PostAsJsonAsync(
            $"/api/v1/planos/{planoId}/treinos", new { nome, descricao = (string?)null });
        resp.EnsureSuccessStatusCode();
        return (await resp.Content.ReadFromJsonAsync<CriadoResposta>())!.Id;
    }

    private static Task<HttpResponseMessage> DefinirSemana(
        HttpClient client, Guid planoId, params (int dia, Guid ficha)[] dias) =>
        client.PutAsJsonAsync($"/api/v1/planos/{planoId}/semana", new
        {
            dias = dias.Select(d => new { diaSemana = d.dia, treinoId = d.ficha }).ToArray(),
        });

    private static async Task<List<DiaResposta>> SemanaDoDetalhe(HttpClient client, Guid planoId) =>
        (await client.GetFromJsonAsync<PlanoDetalheResposta>($"/api/v1/planos/{planoId}"))!.Semana;

    // ---- Fluxo principal ----

    [Fact]
    public async Task Semana_definida_volta_no_detalhe_e_no_plano_em_uso()
    {
        var atleta = NovoUsuario(_postgres);
        await using var _a = atleta.Api;
        var planoId = await CriarPlano(atleta.Client, "Hipertrofia"); // primeiro nasce em uso
        var a = await CriarFicha(atleta.Client, planoId, "A");
        var b = await CriarFicha(atleta.Client, planoId, "B");

        // A na segunda e na quinta, B na quarta.
        var resp = await DefinirSemana(atleta.Client, planoId, (1, a), (3, b), (4, a));
        Assert.Equal(HttpStatusCode.NoContent, resp.StatusCode);

        var esperado = new List<DiaResposta> { new(1, a), new(3, b), new(4, a) };
        Assert.Equal(esperado, await SemanaDoDetalhe(atleta.Client, planoId));
        var ativo = await atleta.Client.GetFromJsonAsync<PlanoAtivoResposta>("/api/v1/planos/ativo");
        Assert.Equal(esperado, ativo!.Semana);

        // Trocar a semana substitui a anterior (sai a quinta, a segunda vira B).
        resp = await DefinirSemana(atleta.Client, planoId, (1, b), (3, b));
        Assert.Equal(HttpStatusCode.NoContent, resp.StatusCode);
        Assert.Equal(new List<DiaResposta> { new(1, b), new(3, b) },
            await SemanaDoDetalhe(atleta.Client, planoId));

        // Lista vazia limpa a semana.
        resp = await DefinirSemana(atleta.Client, planoId);
        Assert.Equal(HttpStatusCode.NoContent, resp.StatusCode);
        Assert.Empty(await SemanaDoDetalhe(atleta.Client, planoId));
    }

    [Fact]
    public async Task Plano_sem_semana_devolve_lista_vazia()
    {
        var atleta = NovoUsuario(_postgres);
        await using var _a = atleta.Api;
        var planoId = await CriarPlano(atleta.Client, "Hipertrofia");
        await CriarFicha(atleta.Client, planoId, "A");

        Assert.Empty(await SemanaDoDetalhe(atleta.Client, planoId));
    }

    // ---- Validação (400) ----

    [Fact]
    public async Task Dia_invalido_dia_repetido_e_ficha_de_outro_plano_respondem_400()
    {
        var atleta = NovoUsuario(_postgres);
        await using var _a = atleta.Api;
        var planoId = await CriarPlano(atleta.Client, "Hipertrofia");
        var a = await CriarFicha(atleta.Client, planoId, "A");
        var outroPlano = await CriarPlano(atleta.Client, "Viagem");
        var deOutroPlano = await CriarFicha(atleta.Client, outroPlano, "V1");

        Assert.Equal(HttpStatusCode.BadRequest, (await DefinirSemana(atleta.Client, planoId, (8, a))).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await DefinirSemana(atleta.Client, planoId, (0, a))).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest,
            (await DefinirSemana(atleta.Client, planoId, (2, a), (2, a))).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest,
            (await DefinirSemana(atleta.Client, planoId, (2, deOutroPlano))).StatusCode);

        // Nada foi gravado.
        Assert.Empty(await SemanaDoDetalhe(atleta.Client, planoId));
    }

    // ---- Acesso ----

    [Fact]
    public async Task Plano_de_outro_usuario_responde_404()
    {
        var dono = NovoUsuario(_postgres);
        var terceiro = NovoUsuario(_postgres);
        await using var _d = dono.Api;
        await using var _t = terceiro.Api;
        var planoId = await CriarPlano(dono.Client, "Hipertrofia");
        var a = await CriarFicha(dono.Client, planoId, "A");

        var resp = await DefinirSemana(terceiro.Client, planoId, (1, a));
        Assert.Equal(HttpStatusCode.NotFound, resp.StatusCode);
        Assert.Empty(await SemanaDoDetalhe(dono.Client, planoId));
    }

    [Fact]
    public async Task Plano_do_professor_responde_403_para_o_aluno()
    {
        var aluno = NovoUsuario(_postgres);
        await using var _a = aluno.Api;
        await Provisionar(aluno);
        var alunoId = await IdDoUsuario(aluno.Uid);

        // Plano e ficha montados pelo "professor", direto no banco.
        Guid planoId, fichaId;
        await using (var db = _postgres.CriarContexto())
        {
            var professor = new Usuario
            {
                Id = Guid.NewGuid(),
                FirebaseUid = $"prof-{Guid.NewGuid():n}",
                Nome = "Prof. Rafael",
                Email = $"prof-{Guid.NewGuid():n}@teste.local",
                Ativo = true,
                CriadoEm = DateTimeOffset.UtcNow,
            };
            db.Usuarios.Add(professor);
            var plano = new PlanoTreino
            {
                Id = Guid.NewGuid(), AutorId = professor.Id, AtletaId = alunoId,
                Nome = "Força 5 dias", Inicio = DateOnly.FromDateTime(DateTime.UtcNow),
                Ativo = true, EmUso = false,
            };
            db.PlanosTreino.Add(plano);
            var ficha = new Treino { Id = Guid.NewGuid(), PlanoId = plano.Id, Nome = "A", Ordem = 1, Ativo = true };
            db.Treinos.Add(ficha);
            await db.SaveChangesAsync();
            (planoId, fichaId) = (plano.Id, ficha.Id);
        }

        var resp = await DefinirSemana(aluno.Client, planoId, (1, fichaId));
        Assert.Equal(HttpStatusCode.Forbidden, resp.StatusCode);
    }

    [Fact]
    public async Task Educador_autor_define_a_semana_do_plano_do_aluno()
    {
        var educador = NovoUsuario(_postgres);
        var aluno = NovoUsuario(_postgres);
        await using var _e = educador.Api;
        await using var _a = aluno.Api;
        await Provisionar(educador);
        await Provisionar(aluno);
        (await educador.Client.PostAsync("/api/v1/me/papeis/educador", content: null))
            .EnsureSuccessStatusCode();
        var convite = await educador.Client.PostAsJsonAsync("/api/v1/vinculos", new { email = aluno.Email });
        var vinculoId = (await convite.Content.ReadFromJsonAsync<CriadoResposta>())!.Id;
        (await aluno.Client.PostAsync($"/api/v1/vinculos/{vinculoId}/aceitar", content: null))
            .EnsureSuccessStatusCode();
        var alunoId = await IdDoUsuario(aluno.Uid);

        var planoId = await CriarPlano(educador.Client, "Força 5 dias", atletaId: alunoId);
        var a = await CriarFicha(educador.Client, planoId, "A");

        // O educador (autor) define; o aluno lê e não altera.
        Assert.Equal(HttpStatusCode.NoContent,
            (await DefinirSemana(educador.Client, planoId, (2, a))).StatusCode);
        Assert.Equal(new List<DiaResposta> { new(2, a) }, await SemanaDoDetalhe(aluno.Client, planoId));
        Assert.Equal(HttpStatusCode.Forbidden,
            (await DefinirSemana(aluno.Client, planoId, (3, a))).StatusCode);
    }

    // ---- Fichas e duplicar ----

    [Fact]
    public async Task Excluir_ficha_sem_treinos_e_arquivar_ficha_com_treinos_liberam_os_dias()
    {
        var atleta = NovoUsuario(_postgres);
        await using var _a = atleta.Api;
        await Provisionar(atleta);
        var atletaId = await IdDoUsuario(atleta.Uid);
        var planoId = await CriarPlano(atleta.Client, "Hipertrofia");
        var a = await CriarFicha(atleta.Client, planoId, "A");
        var b = await CriarFicha(atleta.Client, planoId, "B");
        var c = await CriarFicha(atleta.Client, planoId, "C");
        await DefinirSemana(atleta.Client, planoId, (1, a), (3, b), (5, c));

        // B ganha um treino registrado: excluir a B só arquiva.
        await using (var db = _postgres.CriarContexto())
        {
            db.Sessoes.Add(new Sessao
            {
                Id = Guid.NewGuid(), AtletaId = atletaId, RegistradoPorId = atletaId, TreinoId = b,
                Data = DateOnly.FromDateTime(DateTime.UtcNow),
                CriadoEm = DateTimeOffset.UtcNow, AtualizadoEm = DateTimeOffset.UtcNow,
            });
            await db.SaveChangesAsync();
        }

        Assert.Equal(HttpStatusCode.NoContent, (await atleta.Client.DeleteAsync($"/api/v1/treinos/{a}")).StatusCode);
        Assert.Equal(HttpStatusCode.NoContent, (await atleta.Client.DeleteAsync($"/api/v1/treinos/{b}")).StatusCode);

        // Só a sexta (ficha C) continua planejada.
        Assert.Equal(new List<DiaResposta> { new(5, c) }, await SemanaDoDetalhe(atleta.Client, planoId));
        await using var verif = _postgres.CriarContexto();
        Assert.False(await verif.PlanoDiasSemana.AnyAsync(d => d.TreinoId == a || d.TreinoId == b));
        // O treino registrado com a B continua no histórico.
        Assert.True(await verif.Sessoes.AnyAsync(s => s.TreinoId == b));
    }

    [Fact]
    public async Task Duplicar_plano_leva_a_semana_para_as_fichas_copiadas()
    {
        var atleta = NovoUsuario(_postgres);
        await using var _a = atleta.Api;
        var planoId = await CriarPlano(atleta.Client, "Hipertrofia");
        var a = await CriarFicha(atleta.Client, planoId, "A");
        var b = await CriarFicha(atleta.Client, planoId, "B");
        await DefinirSemana(atleta.Client, planoId, (1, a), (4, b));

        var resp = await atleta.Client.PostAsync($"/api/v1/planos/{planoId}/duplicar", content: null);
        Assert.Equal(HttpStatusCode.Created, resp.StatusCode);
        var copiaId = (await resp.Content.ReadFromJsonAsync<CriadoResposta>())!.Id;

        await using var db = _postgres.CriarContexto();
        var fichasCopia = await db.Treinos.Where(t => t.PlanoId == copiaId)
            .ToDictionaryAsync(t => t.Nome, t => t.Id);
        Assert.Equal(
            new List<DiaResposta> { new(1, fichasCopia["A"]), new(4, fichasCopia["B"]) },
            await SemanaDoDetalhe(atleta.Client, copiaId));
        // A original não muda.
        Assert.Equal(new List<DiaResposta> { new(1, a), new(4, b) },
            await SemanaDoDetalhe(atleta.Client, planoId));
    }
}
