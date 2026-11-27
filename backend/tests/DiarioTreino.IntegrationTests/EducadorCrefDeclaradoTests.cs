using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using DiarioTreino.Domain.Comum;
using DiarioTreino.Domain.Educador;
using DiarioTreino.Domain.Identidade;
using DiarioTreino.Domain.Vinculos;
using DiarioTreino.IntegrationTests.Infraestrutura;
using Microsoft.EntityFrameworkCore;
using Npgsql;

namespace DiarioTreino.IntegrationTests;

/// <summary>
/// PBI-106, habilitação declarada (decisão do PO, 27/11): UF, número e foto da
/// carteira do CREF liberam o modo educador na hora, sem consulta ao site. A foto
/// fica no banco, não volta em resposta e some com o registro e com a conta.
/// </summary>
[Collection(PostgresCollection.Nome)]
public sealed class EducadorCrefDeclaradoTests
{
    private readonly PostgresFixture _postgres;

    public EducadorCrefDeclaradoTests(PostgresFixture postgres)
    {
        _postgres = postgres;
    }

    private const string Declarar = "/api/v1/me/educador/cref/declarar";
    private const string Situacao = "/api/v1/me/educador/cref";

    private readonly string _numero = Random.Shared.Next(100000, 900000).ToString();

    private static readonly byte[] Jpeg = [0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01];

    private sealed record PerfilResp(Guid Id, List<string> Papeis);
    private sealed record RegistroResp(string? Uf, string? Numero, string Origem, DateTimeOffset? DeclaradoEm);
    private sealed record SituacaoResp(bool VerificacaoExigida, RegistroResp? Registro);
    private sealed record ResultadoResp(string Resultado);
    private sealed record ProblemaResp(string? Type, Dictionary<string, string[]>? Errors);

    private sealed record Usuario(ApiFactory Api, HttpClient Client, string Uid, string Email);

    private Usuario NovoUsuario()
    {
        var api = new ApiFactory(_postgres.ConnectionString) { ExigirCref = true };
        var client = api.CreateClient();
        var uid = $"uid-{Guid.NewGuid():n}";
        var email = $"{uid}@teste.local";
        client.DefaultRequestHeaders.Authorization =
            new AuthenticationHeaderValue("Bearer", api.Tokens.Gerar(uid, email: email, nome: "Pessoa"));
        return new Usuario(api, client, uid, email);
    }

    private static async Task<PerfilResp> Me(Usuario u) => (await u.Client.GetFromJsonAsync<PerfilResp>("/api/v1/me"))!;

    private Task<HttpResponseMessage> Enviar(
        Usuario u, byte[]? foto = null, string uf = "MG", string? numero = null, string permite = "true")
    {
        var form = new MultipartFormDataContent
        {
            { new StringContent(uf), "uf" },
            { new StringContent(numero ?? _numero), "numero" },
            { new StringContent(permite), "permiteUso" },
        };
        if (foto is not null)
        {
            var arquivo = new ByteArrayContent(foto);
            arquivo.Headers.ContentType = new MediaTypeHeaderValue("image/jpeg");
            form.Add(arquivo, "foto", "carteira.jpg");
        }
        return u.Client.PostAsync(Declarar, form);
    }

    [Fact]
    public async Task Envio_valido_habilita_na_hora_e_guarda_a_foto_sem_devolver()
    {
        var u = NovoUsuario();
        await using var _a = u.Api;
        var id = (await Me(u)).Id;

        var r = await Enviar(u, Jpeg, numero: $"00{_numero}");

        Assert.Equal(HttpStatusCode.OK, r.StatusCode);
        Assert.Equal("HABILITADO", (await r.Content.ReadFromJsonAsync<ResultadoResp>())!.Resultado);
        Assert.Contains(Papeis.Educador, (await Me(u)).Papeis);

        var texto = await u.Client.GetStringAsync(Situacao);
        var s = System.Text.Json.JsonSerializer.Deserialize<SituacaoResp>(texto,
            new System.Text.Json.JsonSerializerOptions(System.Text.Json.JsonSerializerDefaults.Web))!;
        Assert.Equal(("MG", _numero, OrigemCref.Declarada), (s.Registro!.Uf, s.Registro.Numero, s.Registro.Origem));
        Assert.NotNull(s.Registro.DeclaradoEm);
        Assert.DoesNotContain("foto", texto, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain(Convert.ToBase64String(Jpeg), texto);

        await using var db = _postgres.CriarContexto();
        var foto = await db.FotosCarteiraCref.SingleAsync(f => f.UsuarioId == id);
        Assert.Equal(Jpeg, foto.Conteudo);
        Assert.Equal(FotoCarteiraCref.Jpeg, foto.TipoConteudo);

        // Habilitado, convida (e-mail que não existe: 404 do convite, não a trava).
        var convite = await u.Client.PostAsJsonAsync("/api/v1/vinculos", new { email = "ninguem@teste.local" });
        Assert.Equal(HttpStatusCode.NotFound, convite.StatusCode);
    }

    [Fact]
    public async Task Foto_que_nao_e_imagem_faltando_ou_grande_demais_da_400_sem_gravar()
    {
        var u = NovoUsuario();
        await using var _a = u.Api;
        var id = (await Me(u)).Id;

        foreach (var foto in new byte[]?[] { null, "%PDF-1.7 nao"u8.ToArray(), [.. Jpeg, .. new byte[FotoCarteiraCref.TamanhoMaximo]] })
        {
            var r = await Enviar(u, foto);
            Assert.Equal(HttpStatusCode.BadRequest, r.StatusCode);
            var problema = await r.Content.ReadFromJsonAsync<ProblemaResp>();
            Assert.Equal(["Envie uma foto JPG ou PNG de até 5 MB."], problema!.Errors!["foto"]);
        }

        await using var db = _postgres.CriarContexto();
        Assert.False(await db.EducadoresCref.AnyAsync(e => e.UsuarioId == id));
        Assert.DoesNotContain(Papeis.Educador, (await Me(u)).Papeis);
    }

    [Fact]
    public async Task Sem_permissao_uf_ou_numero_invalidos_dao_400()
    {
        var u = NovoUsuario();
        await using var _a = u.Api;
        await Me(u);

        Assert.Equal(HttpStatusCode.BadRequest, (await Enviar(u, Jpeg, permite: "false")).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await Enviar(u, Jpeg, uf: "XX")).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await Enviar(u, Jpeg, numero: "MG-12")).StatusCode);
        Assert.DoesNotContain(Papeis.Educador, (await Me(u)).Papeis);
    }

    [Fact]
    public async Task O_mesmo_registro_nao_habilita_duas_contas()
    {
        var a = NovoUsuario();
        var b = NovoUsuario();
        await using var _a = a.Api;
        await using var _b = b.Api;
        await Me(a);
        await Me(b);

        Assert.Equal(HttpStatusCode.OK, (await Enviar(a, Jpeg)).StatusCode);
        Assert.Equal(HttpStatusCode.Conflict, (await Enviar(b, Jpeg, numero: $"0{_numero}")).StatusCode);
        Assert.DoesNotContain(Papeis.Educador, (await Me(b)).Papeis);
    }

    [Fact]
    public async Task Sem_token_responde_401()
    {
        await using var api = new ApiFactory(_postgres.ConnectionString) { ExigirCref = true };
        var r = await api.CreateClient().PostAsync(Declarar, new MultipartFormDataContent());
        Assert.Equal(HttpStatusCode.Unauthorized, r.StatusCode);
    }

    [Fact]
    public async Task Delete_me_apaga_registro_e_foto()
    {
        var u = NovoUsuario();
        await using var _a = u.Api;
        var id = (await Me(u)).Id;
        (await Enviar(u, Jpeg)).EnsureSuccessStatusCode();

        (await u.Client.DeleteAsync("/api/v1/me")).EnsureSuccessStatusCode();

        await using var db = _postgres.CriarContexto();
        Assert.False(await db.EducadoresCref.AnyAsync(e => e.UsuarioId == id));
        Assert.False(await db.FotosCarteiraCref.AnyAsync(f => f.UsuarioId == id));
    }

    [Fact]
    public async Task Os_scripts_listam_tiram_a_foto_e_revogam_sem_apagar_os_alunos()
    {
        var u = NovoUsuario();
        await using var _a = u.Api;
        var id = (await Me(u)).Id;
        (await Enviar(u, Jpeg)).EnsureSuccessStatusCode();

        // Um aluno com vínculo ativo, para ver que revogar não apaga nada dele.
        Guid alunoId;
        await using (var db = _postgres.CriarContexto())
        {
            var aluno = new Domain.Identidade.Usuario
            {
                Id = Guid.NewGuid(), FirebaseUid = $"uid-{Guid.NewGuid():n}", Nome = "Aluno",
                Email = $"{Guid.NewGuid():n}@teste.local", Ativo = true, CriadoEm = DateTimeOffset.UtcNow,
            };
            alunoId = aluno.Id;
            db.Usuarios.Add(aluno);
            db.Vinculos.Add(new Vinculo
            {
                Id = Guid.NewGuid(), EducadorId = id, AlunoId = aluno.Id,
                Status = StatusVinculo.Ativo, Inicio = DateTimeOffset.UtcNow,
            });
            await db.SaveChangesAsync();
        }
        var leitura = $"/api/v1/sessoes?de=2026-01-01&ate=2026-12-31&atletaId={alunoId}";
        Assert.Equal(HttpStatusCode.OK, (await u.Client.GetAsync(leitura)).StatusCode);

        await RodarScript("ver-registros-cref.sql", null);
        var base64 = await ConsultarScript("foto-cref.sql", u.Email);
        Assert.Equal(Jpeg, Convert.FromBase64String(base64!));

        await RodarScript("revogar-educador.sql", u.Email);
        await RodarScript("revogar-educador.sql", u.Email); // de novo: nada

        await using (var db = _postgres.CriarContexto())
        {
            Assert.False(await db.EducadoresCref.AnyAsync(e => e.UsuarioId == id));
            Assert.False(await db.FotosCarteiraCref.AnyAsync(f => f.UsuarioId == id));
            Assert.True(await db.Vinculos.AnyAsync(v => v.EducadorId == id && v.Status == StatusVinculo.Ativo));
        }
        Assert.DoesNotContain(Papeis.Educador, (await Me(u)).Papeis);
        // Sem o papel e sem o registro, o vínculo não abre os dados do aluno.
        Assert.Equal(HttpStatusCode.Forbidden, (await u.Client.GetAsync(leitura)).StatusCode);
    }

    private async Task RodarScript(string arquivo, string? email)
    {
        var sql = (await File.ReadAllTextAsync(CaminhoDoScript(arquivo))).Replace("lower(:'email')", "lower(@email)");
        await using var db = _postgres.CriarContexto();
        await db.Database.ExecuteSqlRawAsync(sql, new NpgsqlParameter("email", (object?)email ?? DBNull.Value));
    }

    private async Task<string?> ConsultarScript(string arquivo, string email)
    {
        var sql = (await File.ReadAllTextAsync(CaminhoDoScript(arquivo))).Replace("lower(:'email')", "lower(@email)");
        await using var conexao = new NpgsqlConnection(_postgres.ConnectionString);
        await conexao.OpenAsync();
        await using var cmd = new NpgsqlCommand(sql, conexao);
        cmd.Parameters.AddWithValue("email", email);
        return (string?)await cmd.ExecuteScalarAsync();
    }

    private static string CaminhoDoScript(string arquivo)
    {
        for (var dir = new DirectoryInfo(AppContext.BaseDirectory); dir is not null; dir = dir.Parent)
        {
            var caminho = Path.Combine(dir.FullName, "docs", "scripts", arquivo);
            if (File.Exists(caminho)) return caminho;
        }
        throw new FileNotFoundException(arquivo);
    }
}
