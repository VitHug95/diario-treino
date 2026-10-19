using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using DiarioTreino.Domain.Execucao;
using DiarioTreino.Domain.Planejamento;
using DiarioTreino.Infrastructure.Persistencia;
using DiarioTreino.IntegrationTests.Infraestrutura;
using Microsoft.EntityFrameworkCore;

namespace DiarioTreino.IntegrationTests;

/// <summary>
/// Vários planos por atleta (PBI-44): coluna em_uso, troca em uso, duplicar,
/// excluir com reatribuição do uso, somente-leitura (403) e isolamento (404).
/// </summary>
[Collection(PostgresCollection.Nome)]
public sealed class PlanosVariosEndpointTests
{
    private readonly PostgresFixture _postgres;

    public PlanosVariosEndpointTests(PostgresFixture postgres)
    {
        _postgres = postgres;
    }

    private sealed record PlanoDaListaResposta(
        Guid Id, string Nome, DateOnly Inicio, bool EmUso,
        string Autor, bool SomenteLeitura, int QuantidadeFichas, int QuantidadeExercicios);
    private sealed record PlanoDetalheResposta(
        Guid Id, string Nome, DateOnly Inicio, bool EmUso, string Autor, bool SomenteLeitura,
        List<TreinoResumoResposta> Treinos);
    private sealed record TreinoResumoResposta(Guid Id, string Nome, string? Descricao, short Ordem);
    private sealed record CriadoResposta(Guid Id);

    private static (ApiFactory api, HttpClient client, string uid) Autenticar(PostgresFixture pg)
    {
        var api = new ApiFactory(pg.ConnectionString);
        var client = api.CreateClient();
        var uid = $"uid-{Guid.NewGuid():n}";
        var token = api.Tokens.Gerar(uid, email: $"{uid}@teste.local", nome: "Atleta");
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
        return (api, client, uid);
    }

    private async Task<Guid> IdDoUsuario(string uid)
    {
        await using var db = _postgres.CriarContexto();
        return await db.Usuarios.Where(u => u.FirebaseUid == uid).Select(u => u.Id).SingleAsync();
    }

    private static async Task<Guid> CriarPlanoNomeado(HttpClient client, string nome)
    {
        var resp = await client.PostAsJsonAsync("/api/v1/planos", new { nome });
        resp.EnsureSuccessStatusCode();
        var criado = await resp.Content.ReadFromJsonAsync<CriadoResposta>();
        return criado!.Id;
    }

    // ---- CA 1 e 2: criar planos e o estado de "em uso" ----

    [Fact]
    public async Task Primeiro_plano_nasce_em_uso_e_o_segundo_nao_muda_o_uso()
    {
        var (api, client, _) = Autenticar(_postgres);
        await using var _api = api;

        var primeiro = await CriarPlanoNomeado(client, "Hipertrofia");
        var segundo = await CriarPlanoNomeado(client, "Treino de viagem");

        var planos = await client.GetFromJsonAsync<List<PlanoDaListaResposta>>("/api/v1/planos");
        Assert.Equal(2, planos!.Count);
        // Em uso primeiro na ordem.
        Assert.Equal(primeiro, planos[0].Id);
        Assert.True(planos[0].EmUso);
        Assert.False(planos.Single(p => p.Id == segundo).EmUso);
    }

    // ---- CA 3: trocar o uso ----

    [Fact]
    public async Task Definir_em_uso_troca_de_plano_sem_sobrar_dois()
    {
        var (api, client, uid) = Autenticar(_postgres);
        await using var _api = api;

        var hipertrofia = await CriarPlanoNomeado(client, "Hipertrofia");
        var viagem = await CriarPlanoNomeado(client, "Treino de viagem");

        var resp = await client.PostAsync($"/api/v1/planos/{viagem}/em-uso", content: null);
        Assert.Equal(HttpStatusCode.NoContent, resp.StatusCode);

        var atletaId = await IdDoUsuario(uid);
        await using var db = _postgres.CriarContexto();
        var emUso = await db.PlanosTreino.Where(p => p.AtletaId == atletaId && p.EmUso).ToListAsync();
        Assert.Single(emUso);
        Assert.Equal(viagem, emUso[0].Id);
        Assert.True(await db.PlanosTreino.Where(p => p.Id == hipertrofia).Select(p => !p.EmUso).SingleAsync());
    }

    // ---- CA 4: duplicar ----

    [Fact]
    public async Task Duplicar_copia_fichas_fora_de_uso_sem_sessoes()
    {
        var (api, client, _) = Autenticar(_postgres);
        await using var _api = api;

        var planoId = await CriarPlanoNomeado(client, "Hipertrofia");
        await client.PostAsJsonAsync($"/api/v1/planos/{planoId}/treinos", new { nome = "A", descricao = "Peito" });
        await client.PostAsJsonAsync($"/api/v1/planos/{planoId}/treinos", new { nome = "B", descricao = (string?)null });

        var resp = await client.PostAsync($"/api/v1/planos/{planoId}/duplicar", content: null);
        Assert.Equal(HttpStatusCode.Created, resp.StatusCode);
        var copiaId = (await resp.Content.ReadFromJsonAsync<CriadoResposta>())!.Id;

        var copia = await client.GetFromJsonAsync<PlanoDetalheResposta>($"/api/v1/planos/{copiaId}");
        Assert.Equal("Hipertrofia (cópia)", copia!.Nome);
        Assert.False(copia.EmUso);
        Assert.Equal(2, copia.Treinos.Count);
        Assert.Equal(new[] { "A", "B" }, copia.Treinos.Select(t => t.Nome).ToArray());
    }

    // ---- CA 5: excluir o plano em uso passa o uso para o outro ----

    [Fact]
    public async Task Excluir_plano_em_uso_passa_o_uso_para_o_de_sessao_mais_recente()
    {
        var (api, client, uid) = Autenticar(_postgres);
        await using var _api = api;

        var emUso = await CriarPlanoNomeado(client, "Hipertrofia");
        var outro = await CriarPlanoNomeado(client, "Força 5 dias");
        var atletaId = await IdDoUsuario(uid);

        // Dá uma sessão ao "outro" plano, ligada a uma ficha dele.
        var criarFicha = await client.PostAsJsonAsync(
            $"/api/v1/planos/{outro}/treinos", new { nome = "A", descricao = (string?)null });
        var treinoId = (await criarFicha.Content.ReadFromJsonAsync<CriadoResposta>())!.Id;
        await using (var seed = _postgres.CriarContexto())
        {
            seed.Sessoes.Add(new Sessao
            {
                Id = Guid.NewGuid(),
                AtletaId = atletaId,
                RegistradoPorId = atletaId,
                TreinoId = treinoId,
                Data = DateOnly.FromDateTime(DateTime.UtcNow),
                CriadoEm = DateTimeOffset.UtcNow,
                AtualizadoEm = DateTimeOffset.UtcNow,
            });
            await seed.SaveChangesAsync();
        }

        var excluir = await client.DeleteAsync($"/api/v1/planos/{emUso}");
        Assert.Equal(HttpStatusCode.NoContent, excluir.StatusCode);

        await using var db = _postgres.CriarContexto();
        var usados = await db.PlanosTreino.Where(p => p.AtletaId == atletaId && p.EmUso).ToListAsync();
        Assert.Single(usados);
        Assert.Equal(outro, usados[0].Id);
        // Sessão do "outro" permanece intacta.
        Assert.True(await db.Sessoes.AnyAsync(s => s.TreinoId == treinoId));
    }

    // ---- CA 6 e 7: somente-leitura (403) e isolamento (404) ----

    [Fact]
    public async Task Renomear_plano_do_professor_responde_403()
    {
        var (api, client, uid) = Autenticar(_postgres);
        await using var _api = api;

        // Provisiona o atleta no Postgres (o usuário só é criado na primeira
        // chamada autenticada). Sem isso, IdDoUsuario não acha o registro.
        (await client.GetAsync("/api/v1/me")).EnsureSuccessStatusCode();
        var atletaId = await IdDoUsuario(uid);

        // Plano com autor diferente do atleta (montado pelo "professor"),
        // inserido direto no banco porque o fluxo do educador ainda não existe.
        var professorId = await InserirProfessorEPlano(atletaId);

        var resp = await client.PutAsJsonAsync($"/api/v1/planos/{professorId.PlanoId}", new { nome = "Meu jeito" });
        Assert.Equal(HttpStatusCode.Forbidden, resp.StatusCode);

        // Mas GET (leitura) funciona.
        var leitura = await client.GetAsync($"/api/v1/planos/{professorId.PlanoId}");
        Assert.Equal(HttpStatusCode.OK, leitura.StatusCode);
    }

    [Fact]
    public async Task Plano_de_outro_atleta_responde_404_em_todas_as_rotas()
    {
        var (apiA, clientA, _) = Autenticar(_postgres);
        await using var _apiA = apiA;
        var planoDeA = await CriarPlanoNomeado(clientA, "Hipertrofia");

        var (apiB, clientB, _) = Autenticar(_postgres);
        await using var _apiB = apiB;

        Assert.Equal(HttpStatusCode.NotFound, (await clientB.GetAsync($"/api/v1/planos/{planoDeA}")).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound,
            (await clientB.PutAsJsonAsync($"/api/v1/planos/{planoDeA}", new { nome = "X" })).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound,
            (await clientB.PostAsync($"/api/v1/planos/{planoDeA}/em-uso", content: null)).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound,
            (await clientB.DeleteAsync($"/api/v1/planos/{planoDeA}")).StatusCode);
    }

    // ---- CA 9: ficha vai para o plano do id da URL ----

    [Fact]
    public async Task Ficha_criada_vai_para_o_plano_do_id_e_nao_para_o_em_uso()
    {
        var (api, client, _) = Autenticar(_postgres);
        await using var _api = api;

        var emUso = await CriarPlanoNomeado(client, "Hipertrofia");
        var foraDeUso = await CriarPlanoNomeado(client, "Treino de viagem");

        await client.PostAsJsonAsync($"/api/v1/planos/{foraDeUso}/treinos", new { nome = "V1", descricao = (string?)null });

        var destino = await client.GetFromJsonAsync<PlanoDetalheResposta>($"/api/v1/planos/{foraDeUso}");
        var emUsoDet = await client.GetFromJsonAsync<PlanoDetalheResposta>($"/api/v1/planos/{emUso}");
        Assert.Contains(destino!.Treinos, t => t.Nome == "V1");
        Assert.DoesNotContain(emUsoDet!.Treinos, t => t.Nome == "V1");
    }

    // ---- CA 11: compatibilidade do contrato antigo ----

    [Fact]
    public async Task Post_planos_sem_corpo_mantem_o_comportamento_antigo()
    {
        var (api, client, _) = Autenticar(_postgres);
        await using var _api = api;

        var r1 = await client.PostAsync("/api/v1/planos", content: null);
        Assert.Equal(HttpStatusCode.OK, r1.StatusCode);
        // Idempotente: segunda chamada sem corpo não cria um segundo plano.
        var r2 = await client.PostAsync("/api/v1/planos", content: null);
        Assert.Equal(HttpStatusCode.OK, r2.StatusCode);

        var planos = await client.GetFromJsonAsync<List<PlanoDaListaResposta>>("/api/v1/planos");
        Assert.Single(planos!);
        Assert.True(planos![0].EmUso);
    }

    // ---- PBI-77: criar plano depois de excluir todos volta a ter em uso ----

    [Fact]
    public async Task Criar_plano_apos_excluir_o_unico_com_historico_nasce_em_uso()
    {
        var (api, client, uid) = Autenticar(_postgres);
        await using var _api = api;

        // Plano em uso com uma ficha e uma sessão (ganha histórico).
        var planoId = await CriarPlanoNomeado(client, "Hipertrofia");
        var criarFicha = await client.PostAsJsonAsync(
            $"/api/v1/planos/{planoId}/treinos", new { nome = "A", descricao = (string?)null });
        var treinoId = (await criarFicha.Content.ReadFromJsonAsync<CriadoResposta>())!.Id;
        var atletaId = await IdDoUsuario(uid);
        await using (var seed = _postgres.CriarContexto())
        {
            seed.Sessoes.Add(new Sessao
            {
                Id = Guid.NewGuid(),
                AtletaId = atletaId,
                RegistradoPorId = atletaId,
                TreinoId = treinoId,
                Data = DateOnly.FromDateTime(DateTime.UtcNow),
                CriadoEm = DateTimeOffset.UtcNow,
                AtualizadoEm = DateTimeOffset.UtcNow,
            });
            await seed.SaveChangesAsync();
        }

        // Exclui o único plano: como tem sessão, vira ativo=false, em_uso=false.
        var excluir = await client.DeleteAsync($"/api/v1/planos/{planoId}");
        Assert.Equal(HttpStatusCode.NoContent, excluir.StatusCode);

        // Antes do fix, GET /planos/ativo responderia 204 aqui (nenhum em uso).
        var novoId = await CriarPlanoNomeado(client, "Meu plano");

        var ativo = await client.GetAsync("/api/v1/planos/ativo");
        Assert.Equal(HttpStatusCode.OK, ativo.StatusCode);
        var corpo = await ativo.Content.ReadFromJsonAsync<PlanoDetalheResposta>();
        Assert.Equal(novoId, corpo!.Id);

        await using var db = _postgres.CriarContexto();
        var emUso = await db.PlanosTreino.Where(p => p.AtletaId == atletaId && p.EmUso).ToListAsync();
        Assert.Single(emUso);
        Assert.Equal(novoId, emUso[0].Id);
    }

    // ---- PBI-77: migration de reparo com dois atletas ----

    [Fact]
    public async Task Reparo_marca_em_uso_do_atleta_preso_e_nao_toca_no_normal()
    {
        // Simula o estado anterior ao fix e roda o MESMO SQL da migration de
        // reparo (20261019145756_ReparoPlanoEmUso). Atleta A: dois planos
        // ativos sem nenhum em uso (um com sessão mais recente). Atleta B:
        // normal, já com um plano em uso — não pode ser tocado.
        var atletaA = await CriarUsuario();
        var atletaB = await CriarUsuario();

        Guid aAntigo, aRecente, bEmUso, bOutro;
        await using (var db = _postgres.CriarContexto())
        {
            // Atleta A: dois planos ATIVOS, nenhum em uso.
            aAntigo = InserirPlano(db, atletaA, "A antigo", ativo: true, emUso: false,
                inicio: new DateOnly(2026, 1, 1));
            aRecente = InserirPlano(db, atletaA, "A recente", ativo: true, emUso: false,
                inicio: new DateOnly(2026, 2, 1));
            // Atleta B: um em uso + um fora de uso (estado saudável).
            bEmUso = InserirPlano(db, atletaB, "B em uso", ativo: true, emUso: true,
                inicio: new DateOnly(2026, 1, 1));
            bOutro = InserirPlano(db, atletaB, "B outro", ativo: true, emUso: false,
                inicio: new DateOnly(2026, 3, 1));
            await db.SaveChangesAsync();

            // Dá ao plano "A antigo" uma sessão MAIS RECENTE que a do "A recente",
            // para o reparo escolher por sessão, não por data de início.
            var tAntigo = InserirFicha(db, aAntigo);
            var tRecente = InserirFicha(db, aRecente);
            await db.SaveChangesAsync();
            InserirSessao(db, atletaA, tAntigo, new DateOnly(2026, 5, 1));
            InserirSessao(db, atletaA, tRecente, new DateOnly(2026, 4, 1));
            await db.SaveChangesAsync();
        }

        // Executa o SQL de reparo (idêntico ao da migration).
        await using (var db = _postgres.CriarContexto())
        {
            await db.Database.ExecuteSqlRawAsync(SqlReparoPbi77);
        }

        await using (var db = _postgres.CriarContexto())
        {
            // Atleta A: exatamente um em uso, e é o "A antigo" (sessão mais recente).
            var emUsoA = await db.PlanosTreino
                .Where(p => p.AtletaId == atletaA && p.EmUso).Select(p => p.Id).ToListAsync();
            Assert.Single(emUsoA);
            Assert.Equal(aAntigo, emUsoA[0]);

            // Atleta B: intocado — segue com o mesmo plano em uso.
            var emUsoB = await db.PlanosTreino
                .Where(p => p.AtletaId == atletaB && p.EmUso).Select(p => p.Id).ToListAsync();
            Assert.Single(emUsoB);
            Assert.Equal(bEmUso, emUsoB[0]);
        }
    }

    // SQL idêntico ao da migration 20261019145756_ReparoPlanoEmUso.
    private const string SqlReparoPbi77 = @"
        WITH sem_em_uso AS (
            SELECT p.atleta_id
            FROM plano_treino p
            GROUP BY p.atleta_id
            HAVING bool_or(p.em_uso) = false
               AND bool_or(p.ativo) = true
        ),
        escolhido AS (
            SELECT DISTINCT ON (p.atleta_id) p.id
            FROM plano_treino p
            JOIN sem_em_uso s ON s.atleta_id = p.atleta_id
            LEFT JOIN treino t ON t.plano_id = p.id
            LEFT JOIN sessao se ON se.treino_id = t.id
            WHERE p.ativo = true
            GROUP BY p.atleta_id, p.id, p.inicio
            ORDER BY p.atleta_id,
                     MAX(se.data) DESC NULLS LAST,
                     p.inicio DESC,
                     p.id
        )
        UPDATE plano_treino
        SET em_uso = true
        WHERE id IN (SELECT id FROM escolhido);
    ";

    private async Task<Guid> CriarUsuario()
    {
        await using var db = _postgres.CriarContexto();
        var u = new DiarioTreino.Domain.Identidade.Usuario
        {
            Id = Guid.NewGuid(),
            FirebaseUid = $"uid-{Guid.NewGuid():n}",
            Nome = "Atleta",
            Email = $"a-{Guid.NewGuid():n}@teste.local",
            Ativo = true,
            CriadoEm = DateTimeOffset.UtcNow,
        };
        db.Usuarios.Add(u);
        await db.SaveChangesAsync();
        return u.Id;
    }

    private static Guid InserirPlano(
        DiarioTreinoDbContext db, Guid atletaId, string nome, bool ativo, bool emUso, DateOnly inicio)
    {
        var id = Guid.NewGuid();
        db.PlanosTreino.Add(new PlanoTreino
        {
            Id = id,
            AutorId = atletaId,
            AtletaId = atletaId,
            Nome = nome,
            Inicio = inicio,
            Ativo = ativo,
            EmUso = emUso,
        });
        return id;
    }

    private static Guid InserirFicha(DiarioTreinoDbContext db, Guid planoId)
    {
        var id = Guid.NewGuid();
        db.Treinos.Add(new Treino
        {
            Id = id,
            PlanoId = planoId,
            Nome = "Ficha",
            Ordem = 1,
            Ativo = true,
        });
        return id;
    }

    private static void InserirSessao(DiarioTreinoDbContext db, Guid atletaId, Guid treinoId, DateOnly data)
    {
        db.Sessoes.Add(new Sessao
        {
            Id = Guid.NewGuid(),
            AtletaId = atletaId,
            RegistradoPorId = atletaId,
            TreinoId = treinoId,
            Data = data,
            CriadoEm = DateTimeOffset.UtcNow,
            AtualizadoEm = DateTimeOffset.UtcNow,
        });
    }

    private async Task<(Guid ProfessorId, Guid PlanoId)> InserirProfessorEPlano(Guid atletaId)
    {
        await using var db = _postgres.CriarContexto();
        var professor = new DiarioTreino.Domain.Identidade.Usuario
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
            Id = Guid.NewGuid(),
            AutorId = professor.Id, // autor = professor
            AtletaId = atletaId,    // atleta = o logado
            Nome = "Força 5 dias",
            Inicio = DateOnly.FromDateTime(DateTime.UtcNow),
            Ativo = true,
            EmUso = false,
        };
        db.PlanosTreino.Add(plano);
        await db.SaveChangesAsync();
        return (professor.Id, plano.Id);
    }
}
