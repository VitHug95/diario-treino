using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using DiarioTreino.IntegrationTests.Infraestrutura;
using Microsoft.EntityFrameworkCore;

namespace DiarioTreino.IntegrationTests;

/// <summary>
/// PBI-101: bloco conjugado na ficha. Monta a ficha do PO (Mobilidade de ombro):
/// itens 1, 2 e 5 em bloco e 3 e 4 avulsos, e confere criar, descanso, desfazer,
/// membros, ordem contígua, limites (400), outro usuário (404), cascata ao
/// excluir a ficha, duplicar o plano e fichas antigas sem bloco.
/// </summary>
[Collection(PostgresCollection.Nome)]
public sealed class BlocoConjugadoEndpointTests
{
    private readonly PostgresFixture _postgres;

    public BlocoConjugadoEndpointTests(PostgresFixture postgres)
    {
        _postgres = postgres;
    }

    private sealed record PlanoResp(Guid Id);
    private sealed record CriadoResp(Guid Id);
    private sealed record TeResp(Guid Id, short Ordem, short Rodadas, short? DescansoSeg, Guid? BlocoId);
    private sealed record BlocoResp(Guid Id, short? DescansoSeg, List<Guid> TreinoExercicioIds, short Rodadas);
    private sealed record FichaResp(Guid Id, List<TeResp> Exercicios, List<BlocoResp> Blocos);

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

    /// <summary>Exercícios globais do seed, para montar fichas com vários itens.</summary>
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

    /// <summary>Plano com uma ficha e <paramref name="quantos"/> exercícios, na ordem.</summary>
    private async Task<(Guid PlanoId, Guid TreinoId, List<Guid> Tes)> MontarFicha(HttpClient c, int quantos)
    {
        var plano = await (await c.PostAsync("/api/v1/planos", null)).Content.ReadFromJsonAsync<PlanoResp>();
        var ficha = await (await c.PostAsJsonAsync($"/api/v1/planos/{plano!.Id}/treinos",
            new { nome = "Mobilidade de ombro", descricao = (string?)null })).Content.ReadFromJsonAsync<CriadoResp>();
        var tes = new List<Guid>();
        foreach (var exercicioId in await ExerciciosDoSeed(quantos))
        {
            var r = await c.PostAsJsonAsync($"/api/v1/treinos/{ficha!.Id}/exercicios", new { exercicioId });
            r.EnsureSuccessStatusCode();
            tes.Add((await r.Content.ReadFromJsonAsync<CriadoResp>())!.Id);
        }
        return (plano.Id, ficha!.Id, tes);
    }

    private static Task<HttpResponseMessage> Series(HttpClient c, Guid treinoId, Guid teId, int series, int? descanso = null) =>
        c.PutAsJsonAsync($"/api/v1/treinos/{treinoId}/exercicios/{teId}/alvos", new
        {
            series,
            intensidadeMetricaId = 1,
            volumeMetricaId = 10,
            descansoSeg = descanso,
        });

    private static async Task<Guid> Juntar(HttpClient c, Guid treinoId, short? descanso, params Guid[] tes)
    {
        var r = await c.PostAsJsonAsync($"/api/v1/treinos/{treinoId}/blocos",
            new { treinoExercicioIds = tes, descansoSeg = descanso });
        Assert.Equal(HttpStatusCode.Created, r.StatusCode);
        return (await r.Content.ReadFromJsonAsync<CriadoResp>())!.Id;
    }

    private static async Task<FichaResp> Ficha(HttpClient c, Guid treinoId) =>
        (await c.GetFromJsonAsync<FichaResp>($"/api/v1/treinos/{treinoId}"))!;

    private static List<Guid> Ordem(FichaResp f) => f.Exercicios.OrderBy(e => e.Ordem).Select(e => e.Id).ToList();

    // ---- A ficha do PO ----

    [Fact]
    public async Task Monta_a_ficha_do_PO_com_tres_blocos_e_dois_avulsos()
    {
        var u = NovoUsuario(_postgres);
        await using var _a = u.Api;
        var c = u.Client;
        // 1 prancha, 2 elevação, 3 adução, 4 agachamento, 5 caixote, 6 afundo, 7 isometria, 8 panturrilha.
        var (_, treinoId, t) = await MontarFicha(c, 8);
        var series = new[] { 2, 4, 3, 3, 3, 3, 2, 2 };
        for (var i = 0; i < t.Count; i++)
        {
            (await Series(c, treinoId, t[i], series[i], descanso: i is 4 ? 30 : i is 5 ? 40 : null))
                .EnsureSuccessStatusCode();
        }

        var item1 = await Juntar(c, treinoId, null, t[0], t[1]);
        var item2 = await Juntar(c, treinoId, 30, t[2], t[3]);
        var item5 = await Juntar(c, treinoId, null, t[6], t[7]);

        var f = await Ficha(c, treinoId);
        Assert.Equal(3, f.Blocos.Count);
        Assert.Equal(new[] { item1, item2, item5 }, f.Blocos.Select(b => b.Id));

        var b1 = f.Blocos[0];
        Assert.Equal((short)4, b1.Rodadas); // prancha 2, elevação 4
        Assert.Null(b1.DescansoSeg);
        Assert.Equal(new[] { t[0], t[1] }, b1.TreinoExercicioIds);

        var b2 = f.Blocos[1];
        Assert.Equal((short)3, b2.Rodadas);
        Assert.Equal((short)30, b2.DescansoSeg);

        // Itens 3 e 4 continuam avulsos, com o descanso deles.
        Assert.Null(f.Exercicios.Single(e => e.Id == t[4]).BlocoId);
        Assert.Equal((short)30, f.Exercicios.Single(e => e.Id == t[4]).DescansoSeg);
        Assert.Null(f.Exercicios.Single(e => e.Id == t[5]).BlocoId);
        Assert.Equal(item1, f.Exercicios.Single(e => e.Id == t[1]).BlocoId);

        // A ordem não mudou (todos já eram vizinhos).
        Assert.Equal(t, Ordem(f));
    }

    [Fact]
    public async Task Ficha_antiga_sem_bloco_devolve_bloco_nulo_e_lista_vazia()
    {
        var u = NovoUsuario(_postgres);
        await using var _a = u.Api;
        var (_, treinoId, _) = await MontarFicha(u.Client, 2);

        var f = await Ficha(u.Client, treinoId);
        Assert.Empty(f.Blocos);
        Assert.All(f.Exercicios, e => Assert.Null(e.BlocoId));
    }

    [Fact]
    public async Task Juntar_exercicios_separados_leva_os_membros_para_a_posicao_do_primeiro()
    {
        var u = NovoUsuario(_postgres);
        await using var _a = u.Api;
        var (_, treinoId, t) = await MontarFicha(u.Client, 4);

        await Juntar(u.Client, treinoId, 30, t[3], t[1]);

        // Na ordem da ficha: o 2º e o 4º juntos no lugar do 2º.
        Assert.Equal(new[] { t[0], t[1], t[3], t[2] }, Ordem(await Ficha(u.Client, treinoId)));
    }

    // ---- Descanso ----

    [Fact]
    public async Task Mudar_o_descanso_vale_para_o_bloco_e_nao_mexe_no_dos_membros()
    {
        var u = NovoUsuario(_postgres);
        await using var _a = u.Api;
        var c = u.Client;
        var (_, treinoId, t) = await MontarFicha(c, 2);
        (await Series(c, treinoId, t[0], 3, descanso: 90)).EnsureSuccessStatusCode();
        var bloco = await Juntar(c, treinoId, 30, t[0], t[1]);

        var r = await c.PutAsJsonAsync($"/api/v1/treinos/{treinoId}/blocos/{bloco}", new { descansoSeg = 45 });
        Assert.Equal(HttpStatusCode.NoContent, r.StatusCode);
        Assert.Equal((short)45, (await Ficha(c, treinoId)).Blocos.Single().DescansoSeg);

        // Salvar os alvos de um membro não troca o descanso dele (vale o do bloco).
        (await Series(c, treinoId, t[0], 4, descanso: 10)).EnsureSuccessStatusCode();
        var f = await Ficha(c, treinoId);
        Assert.Equal((short)90, f.Exercicios.Single(e => e.Id == t[0]).DescansoSeg);
        Assert.Equal((short)4, f.Blocos.Single().Rodadas);

        // Sem descanso (nulo) e 0 são aceitos.
        Assert.Equal(HttpStatusCode.NoContent, (await c.PutAsJsonAsync(
            $"/api/v1/treinos/{treinoId}/blocos/{bloco}", new { descansoSeg = (int?)null })).StatusCode);
        Assert.Null((await Ficha(c, treinoId)).Blocos.Single().DescansoSeg);
        Assert.Equal(HttpStatusCode.NoContent, (await c.PutAsJsonAsync(
            $"/api/v1/treinos/{treinoId}/blocos/{bloco}", new { descansoSeg = 0 })).StatusCode);
    }

    [Theory]
    [InlineData(-1)]
    [InlineData(601)]
    public async Task Descanso_fora_de_0_a_600_responde_400(int descanso)
    {
        var u = NovoUsuario(_postgres);
        await using var _a = u.Api;
        var (_, treinoId, t) = await MontarFicha(u.Client, 2);

        var criar = await u.Client.PostAsJsonAsync($"/api/v1/treinos/{treinoId}/blocos",
            new { treinoExercicioIds = new[] { t[0], t[1] }, descansoSeg = descanso });
        Assert.Equal(HttpStatusCode.BadRequest, criar.StatusCode);

        var bloco = await Juntar(u.Client, treinoId, 30, t[0], t[1]);
        var mudar = await u.Client.PutAsJsonAsync(
            $"/api/v1/treinos/{treinoId}/blocos/{bloco}", new { descansoSeg = descanso });
        Assert.Equal(HttpStatusCode.BadRequest, mudar.StatusCode);
    }

    // ---- Desfazer e membros ----

    [Fact]
    public async Task Desfazer_deixa_os_membros_avulsos_na_mesma_ordem_com_o_descanso_do_bloco()
    {
        var u = NovoUsuario(_postgres);
        await using var _a = u.Api;
        var c = u.Client;
        var (_, treinoId, t) = await MontarFicha(c, 3);
        var bloco = await Juntar(c, treinoId, 30, t[1], t[2]);

        var r = await c.DeleteAsync($"/api/v1/treinos/{treinoId}/blocos/{bloco}");
        Assert.Equal(HttpStatusCode.NoContent, r.StatusCode);

        var f = await Ficha(c, treinoId);
        Assert.Empty(f.Blocos);
        Assert.Equal(t, Ordem(f));
        Assert.All(f.Exercicios.Where(e => e.Id != t[0]), e => Assert.Equal((short)30, e.DescansoSeg));
        Assert.Null(f.Exercicios.Single(e => e.Id == t[0]).DescansoSeg);
    }

    [Fact]
    public async Task Adicionar_e_reordenar_membros_mantem_o_bloco_junto()
    {
        var u = NovoUsuario(_postgres);
        await using var _a = u.Api;
        var c = u.Client;
        var (_, treinoId, t) = await MontarFicha(c, 4);
        var bloco = await Juntar(c, treinoId, 30, t[0], t[1]);

        // Entra o 4º, e a ordem dentro do bloco vira 4º, 1º, 2º.
        var r = await c.PutAsJsonAsync($"/api/v1/treinos/{treinoId}/blocos/{bloco}/membros",
            new { treinoExercicioIds = new[] { t[3], t[0], t[1] } });
        Assert.Equal(HttpStatusCode.NoContent, r.StatusCode);

        var f = await Ficha(c, treinoId);
        Assert.Equal(new[] { t[3], t[0], t[1] }, f.Blocos.Single().TreinoExercicioIds);
        Assert.Equal(new[] { t[3], t[0], t[1], t[2] }, Ordem(f));
    }

    [Fact]
    public async Task Tirar_do_bloco_deixa_o_exercicio_logo_depois_com_o_descanso_do_bloco()
    {
        var u = NovoUsuario(_postgres);
        await using var _a = u.Api;
        var c = u.Client;
        var (_, treinoId, t) = await MontarFicha(c, 4);
        var bloco = await Juntar(c, treinoId, 40, t[0], t[1], t[2]);

        // Tira o do meio.
        await c.PutAsJsonAsync($"/api/v1/treinos/{treinoId}/blocos/{bloco}/membros",
            new { treinoExercicioIds = new[] { t[0], t[2] } });

        var f = await Ficha(c, treinoId);
        Assert.Equal(new[] { t[0], t[2] }, f.Blocos.Single().TreinoExercicioIds);
        Assert.Equal(new[] { t[0], t[2], t[1], t[3] }, Ordem(f));
        var tirado = f.Exercicios.Single(e => e.Id == t[1]);
        Assert.Null(tirado.BlocoId);
        Assert.Equal((short)40, tirado.DescansoSeg);
    }

    [Fact]
    public async Task Tirar_um_de_um_bloco_de_dois_desfaz_e_o_outro_fica_com_o_descanso()
    {
        var u = NovoUsuario(_postgres);
        await using var _a = u.Api;
        var c = u.Client;
        var (_, treinoId, t) = await MontarFicha(c, 2);
        var bloco = await Juntar(c, treinoId, 30, t[0], t[1]);

        var r = await c.PutAsJsonAsync($"/api/v1/treinos/{treinoId}/blocos/{bloco}/membros",
            new { treinoExercicioIds = new[] { t[1] } });
        Assert.Equal(HttpStatusCode.NoContent, r.StatusCode);

        var f = await Ficha(c, treinoId);
        Assert.Empty(f.Blocos);
        Assert.All(f.Exercicios, e =>
        {
            Assert.Null(e.BlocoId);
            Assert.Equal((short)30, e.DescansoSeg);
        });
        await using var db = _postgres.CriarContexto();
        Assert.False(await db.BlocosExercicio.AnyAsync(b => b.Id == bloco));
    }

    [Fact]
    public async Task Excluir_um_membro_de_um_bloco_de_dois_desfaz_o_bloco()
    {
        var u = NovoUsuario(_postgres);
        await using var _a = u.Api;
        var c = u.Client;
        var (_, treinoId, t) = await MontarFicha(c, 3);
        await Juntar(c, treinoId, 30, t[0], t[1]);

        var r = await c.DeleteAsync($"/api/v1/treinos/{treinoId}/exercicios/{t[0]}");
        Assert.Equal(HttpStatusCode.NoContent, r.StatusCode);

        var f = await Ficha(c, treinoId);
        Assert.Empty(f.Blocos);
        var sobrou = f.Exercicios.Single(e => e.Id == t[1]);
        Assert.Null(sobrou.BlocoId);
        Assert.Equal((short)30, sobrou.DescansoSeg);
    }

    [Fact]
    public async Task Excluir_um_membro_de_um_bloco_de_tres_mantem_o_bloco_com_dois()
    {
        var u = NovoUsuario(_postgres);
        await using var _a = u.Api;
        var c = u.Client;
        var (_, treinoId, t) = await MontarFicha(c, 3);
        var bloco = await Juntar(c, treinoId, 30, t[0], t[1], t[2]);

        await c.DeleteAsync($"/api/v1/treinos/{treinoId}/exercicios/{t[1]}");

        var f = await Ficha(c, treinoId);
        Assert.Equal(new[] { t[0], t[2] }, f.Blocos.Single(b => b.Id == bloco).TreinoExercicioIds);
    }

    // ---- Reordenar ----

    [Fact]
    public async Task Reordenar_movendo_o_bloco_inteiro_passa_e_separando_responde_400()
    {
        var u = NovoUsuario(_postgres);
        await using var _a = u.Api;
        var c = u.Client;
        var (_, treinoId, t) = await MontarFicha(c, 3);
        await Juntar(c, treinoId, 30, t[0], t[1]);

        // Bloco inteiro para o fim: ok.
        var ok = await c.PutAsJsonAsync($"/api/v1/treinos/{treinoId}/exercicios/ordem",
            new { treinoExercicioIds = new[] { t[2], t[0], t[1] } });
        Assert.Equal(HttpStatusCode.NoContent, ok.StatusCode);
        Assert.Equal(new[] { t[2], t[0], t[1] }, Ordem(await Ficha(c, treinoId)));

        // Avulso no meio do bloco: 400 e nada muda.
        var quebra = await c.PutAsJsonAsync($"/api/v1/treinos/{treinoId}/exercicios/ordem",
            new { treinoExercicioIds = new[] { t[0], t[2], t[1] } });
        Assert.Equal(HttpStatusCode.BadRequest, quebra.StatusCode);
        Assert.Equal(new[] { t[2], t[0], t[1] }, Ordem(await Ficha(c, treinoId)));
    }

    // ---- Limites (400) ----

    [Fact]
    public async Task Limites_de_membros_respondem_400()
    {
        var u = NovoUsuario(_postgres);
        await using var _a = u.Api;
        var c = u.Client;
        var (_, treinoId, t) = await MontarFicha(c, 5);
        var (_, outraFicha, outros) = await MontarFicha(c, 1);

        async Task<HttpStatusCode> Criar(params Guid[] ids) =>
            (await c.PostAsJsonAsync($"/api/v1/treinos/{treinoId}/blocos",
                new { treinoExercicioIds = ids, descansoSeg = 30 })).StatusCode;

        Assert.Equal(HttpStatusCode.BadRequest, await Criar(t[0]));                        // menos de 2
        Assert.Equal(HttpStatusCode.BadRequest, await Criar(t[0], t[1], t[2], t[3], t[4])); // mais de 4
        Assert.Equal(HttpStatusCode.BadRequest, await Criar(t[0], t[0]));                  // repetido
        Assert.Equal(HttpStatusCode.BadRequest, await Criar(t[0], outros[0]));             // de outra ficha

        var bloco = await Juntar(c, treinoId, 30, t[0], t[1]);
        Assert.Equal(HttpStatusCode.BadRequest, await Criar(t[1], t[2]));                  // já em bloco

        // Membros: noutro bloco e mais de 4.
        var outro = await Juntar(c, treinoId, null, t[2], t[3]);
        Assert.Equal(HttpStatusCode.BadRequest, (await c.PutAsJsonAsync(
            $"/api/v1/treinos/{treinoId}/blocos/{bloco}/membros",
            new { treinoExercicioIds = new[] { t[0], t[1], t[2] } })).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await c.PutAsJsonAsync(
            $"/api/v1/treinos/{treinoId}/blocos/{outro}/membros",
            new { treinoExercicioIds = new[] { t[2], t[3], t[4], t[0], t[1] } })).StatusCode);

        // Nada mudou.
        var f = await Ficha(c, treinoId);
        Assert.Equal(2, f.Blocos.Count);
        Assert.Null((await Ficha(c, outraFicha)).Exercicios.Single().BlocoId);
    }

    [Fact]
    public async Task Bloco_de_outra_ficha_responde_404()
    {
        var u = NovoUsuario(_postgres);
        await using var _a = u.Api;
        var c = u.Client;
        var (_, ficha1, t) = await MontarFicha(c, 2);
        var (_, ficha2, _) = await MontarFicha(c, 2);
        var bloco = await Juntar(c, ficha1, 30, t[0], t[1]);

        Assert.Equal(HttpStatusCode.NotFound, (await c.PutAsJsonAsync(
            $"/api/v1/treinos/{ficha2}/blocos/{bloco}", new { descansoSeg = 10 })).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound,
            (await c.DeleteAsync($"/api/v1/treinos/{ficha2}/blocos/{Guid.NewGuid()}")).StatusCode);
    }

    // ---- Acesso (MAS 11.3) ----

    [Fact]
    public async Task Outro_usuario_recebe_404_em_todas_as_rotas_de_bloco()
    {
        var dono = NovoUsuario(_postgres);
        var intruso = NovoUsuario(_postgres);
        await using var _d = dono.Api;
        await using var _i = intruso.Api;
        var (_, treinoId, t) = await MontarFicha(dono.Client, 3);
        var bloco = await Juntar(dono.Client, treinoId, 30, t[0], t[1]);
        var c = intruso.Client;

        Assert.Equal(HttpStatusCode.NotFound, (await c.PostAsJsonAsync($"/api/v1/treinos/{treinoId}/blocos",
            new { treinoExercicioIds = new[] { t[1], t[2] }, descansoSeg = 30 })).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await c.PutAsJsonAsync(
            $"/api/v1/treinos/{treinoId}/blocos/{bloco}", new { descansoSeg = 10 })).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await c.PutAsJsonAsync(
            $"/api/v1/treinos/{treinoId}/blocos/{bloco}/membros",
            new { treinoExercicioIds = new[] { t[0] } })).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound,
            (await c.DeleteAsync($"/api/v1/treinos/{treinoId}/blocos/{bloco}")).StatusCode);

        // O bloco do dono continua igual.
        var f = await Ficha(dono.Client, treinoId);
        Assert.Equal((short)30, f.Blocos.Single().DescansoSeg);
        Assert.Equal(new[] { t[0], t[1] }, f.Blocos.Single().TreinoExercicioIds);
    }

    [Fact]
    public async Task Educador_com_vinculo_monta_o_bloco_na_ficha_do_aluno()
    {
        var educador = NovoUsuario(_postgres);
        var aluno = NovoUsuario(_postgres);
        await using var _e = educador.Api;
        await using var _a = aluno.Api;
        (await educador.Client.GetAsync("/api/v1/me")).EnsureSuccessStatusCode();
        (await aluno.Client.GetAsync("/api/v1/me")).EnsureSuccessStatusCode();
        (await educador.Client.PostAsync("/api/v1/me/papeis/educador", null)).EnsureSuccessStatusCode();
        var convite = await educador.Client.PostAsJsonAsync("/api/v1/vinculos", new { email = aluno.Email });
        var vinculoId = (await convite.Content.ReadFromJsonAsync<CriadoResp>())!.Id;
        (await aluno.Client.PostAsync($"/api/v1/vinculos/{vinculoId}/aceitar", null)).EnsureSuccessStatusCode();

        // A ficha é do aluno; quem junta é o educador.
        var (_, treinoId, t) = await MontarFicha(aluno.Client, 2);
        await Juntar(educador.Client, treinoId, 30, t[0], t[1]);

        var f = await Ficha(aluno.Client, treinoId);
        Assert.Equal((short)30, f.Blocos.Single().DescansoSeg);
    }

    // ---- Cascata e cópia ----

    [Fact]
    public async Task Excluir_a_ficha_apaga_os_blocos()
    {
        var u = NovoUsuario(_postgres);
        await using var _a = u.Api;
        var (_, treinoId, t) = await MontarFicha(u.Client, 2);
        var bloco = await Juntar(u.Client, treinoId, 30, t[0], t[1]);

        Assert.Equal(HttpStatusCode.NoContent, (await u.Client.DeleteAsync($"/api/v1/treinos/{treinoId}")).StatusCode);

        await using var db = _postgres.CriarContexto();
        Assert.False(await db.BlocosExercicio.AnyAsync(b => b.Id == bloco));
        Assert.False(await db.TreinoExercicios.AnyAsync(te => te.TreinoId == treinoId));
    }

    [Fact]
    public async Task Duplicar_o_plano_copia_os_blocos_com_membros_ordem_e_descanso()
    {
        var u = NovoUsuario(_postgres);
        await using var _a = u.Api;
        var c = u.Client;
        var (planoId, treinoId, t) = await MontarFicha(c, 4);
        await Juntar(c, treinoId, 30, t[1], t[2]);

        var dup = await c.PostAsync($"/api/v1/planos/{planoId}/duplicar", null);
        Assert.Equal(HttpStatusCode.Created, dup.StatusCode);
        var copiaId = (await dup.Content.ReadFromJsonAsync<CriadoResp>())!.Id;

        Guid fichaCopia;
        await using (var db = _postgres.CriarContexto())
        {
            fichaCopia = await db.Treinos.Where(x => x.PlanoId == copiaId).Select(x => x.Id).SingleAsync();
        }

        var original = await Ficha(c, treinoId);
        var copia = await Ficha(c, fichaCopia);
        var bOrig = original.Blocos.Single();
        var bCopia = copia.Blocos.Single();
        Assert.NotEqual(bOrig.Id, bCopia.Id);
        Assert.Equal(bOrig.DescansoSeg, bCopia.DescansoSeg);
        Assert.Equal(bOrig.Rodadas, bCopia.Rodadas);
        // Mesmas posições (os ids da cópia são novos).
        var posOrig = bOrig.TreinoExercicioIds.Select(id => original.Exercicios.Single(e => e.Id == id).Ordem);
        var posCopia = bCopia.TreinoExercicioIds.Select(id => copia.Exercicios.Single(e => e.Id == id).Ordem);
        Assert.Equal(posOrig, posCopia);
        Assert.All(bCopia.TreinoExercicioIds, id => Assert.Contains(copia.Exercicios, e => e.Id == id));
    }
}
