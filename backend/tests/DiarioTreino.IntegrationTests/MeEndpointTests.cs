using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using DiarioTreino.Domain.Comum;
using DiarioTreino.IntegrationTests.Infraestrutura;
using Microsoft.EntityFrameworkCore;

namespace DiarioTreino.IntegrationTests;

[Collection(PostgresCollection.Nome)]
public sealed class MeEndpointTests
{
    private readonly PostgresFixture _postgres;

    public MeEndpointTests(PostgresFixture postgres)
    {
        _postgres = postgres;
    }

    [Fact]
    public async Task Me_sem_token_responde_401()
    {
        await using var api = new ApiFactory(_postgres.ConnectionString);
        var client = api.CreateClient();

        var resposta = await client.GetAsync("/api/v1/me");

        Assert.Equal(HttpStatusCode.Unauthorized, resposta.StatusCode);
    }

    [Fact]
    public async Task Me_com_token_invalido_responde_401()
    {
        await using var api = new ApiFactory(_postgres.ConnectionString);
        var client = api.CreateClient();
        client.DefaultRequestHeaders.Authorization =
            new AuthenticationHeaderValue("Bearer", "token.invalido.aqui");

        var resposta = await client.GetAsync("/api/v1/me");

        Assert.Equal(HttpStatusCode.Unauthorized, resposta.StatusCode);
    }

    [Fact]
    public async Task Me_com_token_valido_provisiona_atleta_no_primeiro_acesso()
    {
        await using var api = new ApiFactory(_postgres.ConnectionString);
        var client = api.CreateClient();

        var uid = $"uid-{Guid.NewGuid():n}";
        // E-mail único (evita colisão no banco compartilhado) e com caixa alta,
        // para também verificar que a API o normaliza para minúsculas.
        var emailEnviado = $"ATLETA-{uid}@Teste.Local";
        var token = api.Tokens.Gerar(uid, email: emailEnviado, nome: "Atleta Teste");
        client.DefaultRequestHeaders.Authorization =
            new AuthenticationHeaderValue("Bearer", token);

        var resposta = await client.GetAsync("/api/v1/me");

        Assert.Equal(HttpStatusCode.OK, resposta.StatusCode);

        var perfil = await resposta.Content.ReadFromJsonAsync<PerfilResposta>();
        Assert.NotNull(perfil);
        Assert.Equal(emailEnviado.ToLowerInvariant(), perfil!.Email);
        Assert.Equal("Atleta Teste", perfil.Nome);
        Assert.Contains(Papeis.Atleta, perfil.Papeis);

        // Confirma a persistência: usuário criado com o papel ATLETA.
        await using var db = _postgres.CriarContexto();
        var usuario = await db.Usuarios
            .Include(u => u.Papeis)
            .SingleAsync(u => u.FirebaseUid == uid);
        Assert.Single(usuario.Papeis);
        Assert.Equal(Papeis.Atleta, usuario.Papeis.First().Papel);
    }

    [Fact]
    public async Task Me_no_segundo_acesso_nao_duplica_usuario()
    {
        await using var api = new ApiFactory(_postgres.ConnectionString);
        var client = api.CreateClient();

        var uid = $"uid-{Guid.NewGuid():n}";
        var token = api.Tokens.Gerar(uid, email: $"{uid}@teste.local", nome: "Repetido");
        client.DefaultRequestHeaders.Authorization =
            new AuthenticationHeaderValue("Bearer", token);

        await client.GetAsync("/api/v1/me");
        await client.GetAsync("/api/v1/me");

        await using var db = _postgres.CriarContexto();
        var quantos = await db.Usuarios.CountAsync(u => u.FirebaseUid == uid);
        Assert.Equal(1, quantos);
    }

    [Fact]
    public async Task Excluir_conta_sem_token_responde_401()
    {
        await using var api = new ApiFactory(_postgres.ConnectionString);
        var client = api.CreateClient();

        var resposta = await client.DeleteAsync("/api/v1/me");

        Assert.Equal(HttpStatusCode.Unauthorized, resposta.StatusCode);
    }

    [Fact]
    public async Task Excluir_conta_apaga_o_usuario_e_todos_os_seus_dados()
    {
        await using var api = new ApiFactory(_postgres.ConnectionString);
        var client = api.CreateClient();

        var uid = $"uid-{Guid.NewGuid():n}";
        var token = api.Tokens.Gerar(uid, email: $"{uid}@teste.local", nome: "A Excluir");
        client.DefaultRequestHeaders.Authorization =
            new AuthenticationHeaderValue("Bearer", token);

        // Provisiona o usuário e cria dados ligados a ele: um plano (ficha),
        // um exercício próprio e uma sessão com séries.
        await client.GetAsync("/api/v1/me");

        var plano = await (await client.PostAsync("/api/v1/planos", null))
            .Content.ReadFromJsonAsync<IdResp>();
        var treino = await (await client.PostAsJsonAsync(
                $"/api/v1/planos/{plano!.Id}/treinos",
                new { nome = "A", descricao = (string?)null }))
            .Content.ReadFromJsonAsync<IdResp>();

        // Exercício próprio (criado_por = usuário).
        var exProprio = await (await client.PostAsJsonAsync("/api/v1/exercicios", new
        {
            nome = $"Meu exercício {uid}",
            grupoMuscular = "Peito",
            modalidade = "FORCA",
            intensidadeMetricaId = 1,
            volumeMetricaId = 10,
        })).Content.ReadFromJsonAsync<IdResp>();

        var te = await (await client.PostAsJsonAsync(
                $"/api/v1/treinos/{treino!.Id}/exercicios",
                new { exercicioId = SupinoReto }))
            .Content.ReadFromJsonAsync<IdResp>();

        var hoje = DateOnly.FromDateTime(DateTime.UtcNow.Date);
        var criarSessao = await client.PostAsJsonAsync("/api/v1/sessoes", new
        {
            treinoId = treino.Id,
            data = hoje,
            duracaoMin = (short?)null,
            observacao = (string?)null,
            exercicios = new[]
            {
                new
                {
                    exercicioId = SupinoReto,
                    treinoExercicioId = te!.Id,
                    series = new[]
                    {
                        new
                        {
                            rodada = (short)1,
                            ordem = (short)1,
                            tipo = "ESFORCO",
                            intensidadeMetricaId = 1,
                            intensidade = 30m,
                            volumeMetricaId = 10,
                            volume = 10m,
                            descansoSeg = (short?)90,
                        },
                    },
                },
            },
        });
        criarSessao.EnsureSuccessStatusCode();

        // Pega o id do usuário para conferir o banco depois.
        Guid usuarioId;
        await using (var dbAntes = _postgres.CriarContexto())
        {
            usuarioId = await dbAntes.Usuarios
                .Where(u => u.FirebaseUid == uid).Select(u => u.Id).SingleAsync();
        }

        // Excluir conta.
        var resposta = await client.DeleteAsync("/api/v1/me");
        Assert.Equal(HttpStatusCode.NoContent, resposta.StatusCode);

        // Nada do usuário sobra no banco.
        await using var db = _postgres.CriarContexto();
        Assert.False(await db.Usuarios.AnyAsync(u => u.Id == usuarioId));
        Assert.False(await db.UsuarioPapeis.AnyAsync(p => p.UsuarioId == usuarioId));
        Assert.False(await db.PlanosTreino.AnyAsync(p => p.AtletaId == usuarioId));
        Assert.False(await db.Sessoes.AnyAsync(s => s.AtletaId == usuarioId));
        Assert.False(await db.Exercicios.AnyAsync(e => e.CriadoPorId == usuarioId));
        // O exercício global do seed continua intacto.
        Assert.True(await db.Exercicios.AnyAsync(e => e.Id == SupinoReto));
        Assert.False(await db.Exercicios.AnyAsync(e => e.Id == exProprio!.Id));
    }

    [Fact]
    public async Task Excluir_conta_nao_afeta_dados_de_outro_usuario()
    {
        await using var api = new ApiFactory(_postgres.ConnectionString);

        // Usuário A, com uma ficha.
        var clientA = api.CreateClient();
        var uidA = $"uid-{Guid.NewGuid():n}";
        clientA.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue(
            "Bearer", api.Tokens.Gerar(uidA, email: $"{uidA}@teste.local", nome: "A"));
        await clientA.GetAsync("/api/v1/me");
        var planoA = await (await clientA.PostAsync("/api/v1/planos", null))
            .Content.ReadFromJsonAsync<IdResp>();

        // Usuário B exclui a própria conta.
        var clientB = api.CreateClient();
        var uidB = $"uid-{Guid.NewGuid():n}";
        clientB.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue(
            "Bearer", api.Tokens.Gerar(uidB, email: $"{uidB}@teste.local", nome: "B"));
        await clientB.GetAsync("/api/v1/me");

        var resposta = await clientB.DeleteAsync("/api/v1/me");
        Assert.Equal(HttpStatusCode.NoContent, resposta.StatusCode);

        // A continua intacto.
        await using var db = _postgres.CriarContexto();
        Assert.True(await db.Usuarios.AnyAsync(u => u.FirebaseUid == uidA));
        Assert.True(await db.PlanosTreino.AnyAsync(p => p.Id == planoA!.Id));
        Assert.False(await db.Usuarios.AnyAsync(u => u.FirebaseUid == uidB));
    }

    // Exercício global do seed, usado para montar a sessão de teste.
    private static readonly Guid SupinoReto =
        Guid.Parse("11111111-0000-0000-0000-000000000001");

    private sealed record PerfilResposta(
        Guid Id,
        string Nome,
        string Email,
        IReadOnlyList<string> Papeis);

    private sealed record IdResp(Guid Id);
}
