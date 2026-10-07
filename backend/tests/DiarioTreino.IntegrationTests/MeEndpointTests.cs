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

    private sealed record PerfilResposta(
        Guid Id,
        string Nome,
        string Email,
        IReadOnlyList<string> Papeis);
}
