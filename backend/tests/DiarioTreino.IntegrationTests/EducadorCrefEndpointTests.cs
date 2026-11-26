using System.Collections.Concurrent;
using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using DiarioTreino.Application.Educador;
using DiarioTreino.Domain.Comum;
using DiarioTreino.Domain.Educador;
using DiarioTreino.Domain.Identidade;
using DiarioTreino.Domain.Vinculos;
using DiarioTreino.IntegrationTests.Infraestrutura;
using Microsoft.EntityFrameworkCore;
using Npgsql;
using Serilog.Core;
using Serilog.Events;

namespace DiarioTreino.IntegrationTests;

/// <summary>
/// PBI-106: habilitação do educador pela consulta do CREF, com a chave
/// <c>Educador:ExigirCref</c> ligada e uma consulta falsa (nunca o site real).
/// Cobre a tabela de decisão, o limite, o 409, a rota antiga, a trava do
/// educador sem habilitação, o script do legado, <c>DELETE /me</c> e o CPF fora
/// de logs, tabelas e respostas.
/// </summary>
[Collection(PostgresCollection.Nome)]
public sealed class EducadorCrefEndpointTests
{
    private readonly PostgresFixture _postgres;

    public EducadorCrefEndpointTests(PostgresFixture postgres)
    {
        _postgres = postgres;
    }

    /// <summary>Número de registro deste teste: o banco é compartilhado e o mesmo registro não habilita duas contas.</summary>
    private readonly string _numero = Random.Shared.Next(100000, 900000).ToString();

    private const string Verificar = "/api/v1/me/educador/cref/verificar";
    private const string Situacao = "/api/v1/me/educador/cref";

    // Válidos na conta e sem dono conhecido.
    private const string Cpf = "52998224725";
    private const string CpfFormatado = "529.982.247-25";
    private const string OutroCpf = "11144477735";

    private sealed record VerificarResp(string Resultado, string? Motivo, string? Situacao);
    private sealed record RegistroResp(string? Uf, string? Numero, string? Situacao, string? Categoria, string Origem, DateTimeOffset? ConsultadoEm);
    private sealed record SituacaoResp(bool VerificacaoExigida, RegistroResp? Registro);
    private sealed record PerfilResp(Guid Id, List<string> Papeis);
    private sealed record ProblemaResp(string? Type, string? Detail);

    /// <summary>Consulta falsa: responde o que o teste mandar e conta as chamadas.</summary>
    private sealed class ConsultaFalsa : IConsultaCref
    {
        public Func<string, string, ResultadoConsultaCref> Responder { get; set; } =
            (_, _) => new ResultadoConsultaCref.NaoEncontrado();
        public int Chamadas;

        public Task<ResultadoConsultaCref> ConsultarPorCpfAsync(string uf, string cpf, CancellationToken ct)
        {
            Interlocked.Increment(ref Chamadas);
            return Task.FromResult(Responder(uf, cpf));
        }
    }

    private sealed class CapturaDeLogs : ILogEventSink
    {
        public ConcurrentQueue<string> Textos { get; } = new();

        public void Emit(LogEvent e) => Textos.Enqueue(
            $"{e.RenderMessage()} {string.Join(" ", e.Properties.Select(p => $"{p.Key}={p.Value}"))} {e.Exception}");
    }

    private sealed record Usuario(ApiFactory Api, HttpClient Client, string Uid, string Email);

    private Usuario NovoUsuario(ConsultaFalsa? consulta = null, CapturaDeLogs? logs = null, bool exigirCref = true)
    {
        var api = new ApiFactory(_postgres.ConnectionString)
        {
            ExigirCref = exigirCref,
            ConsultaCref = consulta,
            Logs = logs,
        };
        var client = api.CreateClient();
        var uid = $"uid-{Guid.NewGuid():n}";
        var email = $"{uid}@teste.local";
        client.DefaultRequestHeaders.Authorization =
            new AuthenticationHeaderValue("Bearer", api.Tokens.Gerar(uid, email: email, nome: "Pessoa"));
        return new Usuario(api, client, uid, email);
    }

    private static async Task<PerfilResp> Me(Usuario u) => (await u.Client.GetFromJsonAsync<PerfilResp>("/api/v1/me"))!;

    private Task<HttpResponseMessage> PedirVerificacao(Usuario u, string uf = "MG", string? numero = null, string cpf = CpfFormatado) =>
        u.Client.PostAsJsonAsync(Verificar, new { uf, numero = numero ?? _numero, cpf, permiteConsulta = true });

    private async Task<VerificarResp> Verificado(Usuario u, string uf = "MG", string? numero = null, string cpf = CpfFormatado)
    {
        var r = await PedirVerificacao(u, uf, numero, cpf);
        Assert.True(r.StatusCode == HttpStatusCode.OK, $"{(int)r.StatusCode}: {await r.Content.ReadAsStringAsync()}");
        return (await r.Content.ReadFromJsonAsync<VerificarResp>())!;
    }

    private ResultadoConsultaCref Ativo(string? numero = null) =>
        new ResultadoConsultaCref.Encontrado([new RegistroEncontrado(numero ?? $"MG-00{_numero}", "ATIVO", "BACHAREL")]);

    // ---- Habilitar e as respostas da tabela ----

    [Fact]
    public async Task Registro_ativo_habilita_na_hora_grava_a_evidencia_e_libera_o_convite()
    {
        var consulta = new ConsultaFalsa { Responder = (_, _) => Ativo() };
        var u = NovoUsuario(consulta);
        await using var _a = u.Api;
        var id = (await Me(u)).Id;

        var antes = await u.Client.GetFromJsonAsync<SituacaoResp>(Situacao);
        Assert.True(antes!.VerificacaoExigida);
        Assert.Null(antes.Registro);

        Assert.Equal(new VerificarResp("HABILITADO", null, "ATIVO"), await Verificado(u, "mg", $"00{_numero}"));

        Assert.Contains(Papeis.Educador, (await Me(u)).Papeis);
        var depois = await u.Client.GetFromJsonAsync<SituacaoResp>(Situacao);
        Assert.Equal(("MG", _numero, "ATIVO", "BACHAREL", OrigemCref.Automatica),
            (depois!.Registro!.Uf, depois.Registro.Numero, depois.Registro.Situacao, depois.Registro.Categoria, depois.Registro.Origem));

        // Habilitado convida (o e-mail não existe: 404 do convite, não 403).
        var convite = await u.Client.PostAsJsonAsync("/api/v1/vinculos", new { email = "ninguem@teste.local" });
        Assert.Equal(HttpStatusCode.NotFound, convite.StatusCode);

        await using var db = _postgres.CriarContexto();
        Assert.Equal(ResultadoCref.Habilitado, (await db.TentativasCref.SingleAsync(t => t.UsuarioId == id)).Resultado);
    }

    [Fact]
    public async Task Situacao_nao_ativa_recusa_mostra_a_situacao_e_deixa_tentar_de_novo()
    {
        var situacao = "CANCELADO";
        var consulta = new ConsultaFalsa
        {
            Responder = (_, _) => new ResultadoConsultaCref.Encontrado([new RegistroEncontrado($"MG-00{_numero}", situacao, "BACHAREL")]),
        };
        var u = NovoUsuario(consulta);
        await using var _a = u.Api;

        Assert.Equal(new VerificarResp("RECUSADO", MotivoCref.SituacaoNaoAtiva, "CANCELADO"), await Verificado(u));
        Assert.DoesNotContain(Papeis.Educador, (await Me(u)).Papeis);

        situacao = "ATIVO"; // regularizou
        Assert.Equal("HABILITADO", (await Verificado(u)).Resultado);
    }

    [Fact]
    public async Task Numero_que_nao_confere_e_cpf_sem_registro()
    {
        var consulta = new ConsultaFalsa { Responder = (_, _) => Ativo("MG-0099") };
        var u = NovoUsuario(consulta);
        await using var _a = u.Api;

        Assert.Equal(new VerificarResp("RECUSADO", MotivoCref.NumeroNaoConfere, null), await Verificado(u));

        consulta.Responder = (_, _) => new ResultadoConsultaCref.NaoEncontrado();
        Assert.Equal(new VerificarResp("NAO_ENCONTRADO", null, null), await Verificado(u));
        Assert.Null((await u.Client.GetFromJsonAsync<SituacaoResp>(Situacao))!.Registro);
    }

    [Fact]
    public async Task Indisponivel_nao_recusa_nem_gasta_tentativa_e_uf_sem_consulta_nem_consulta()
    {
        var consulta = new ConsultaFalsa { Responder = (_, _) => new ResultadoConsultaCref.Indisponivel() };
        var u = NovoUsuario(consulta);
        await using var _a = u.Api;
        var id = (await Me(u)).Id;

        for (var i = 0; i < 7; i++)
        {
            Assert.Equal("INDISPONIVEL", (await Verificado(u)).Resultado);
        }
        Assert.Equal(new VerificarResp("INDISPONIVEL", MotivoCref.UfSemConsulta, null), await Verificado(u, uf: "SP"));
        Assert.Equal(7, consulta.Chamadas);

        await using var db = _postgres.CriarContexto();
        Assert.False(await db.TentativasCref.AnyAsync(t => t.UsuarioId == id));

        consulta.Responder = (_, _) => Ativo();
        Assert.Equal("HABILITADO", (await Verificado(u)).Resultado);
    }

    [Fact]
    public async Task A_sexta_tentativa_em_24h_responde_429_sem_consultar()
    {
        var consulta = new ConsultaFalsa();
        var u = NovoUsuario(consulta);
        await using var _a = u.Api;

        for (var i = 0; i < ServicoCref.LimiteTentativas; i++)
        {
            Assert.Equal("NAO_ENCONTRADO", (await Verificado(u)).Resultado);
        }

        var sexta = await PedirVerificacao(u);
        Assert.Equal(HttpStatusCode.TooManyRequests, sexta.StatusCode);
        var problema = await sexta.Content.ReadFromJsonAsync<ProblemaResp>();
        Assert.Equal("limite-tentativas-cref", problema!.Type);
        Assert.Equal("Você já tentou 5 vezes hoje. Tente amanhã.", problema.Detail);
        Assert.Equal(ServicoCref.LimiteTentativas, consulta.Chamadas);
    }

    [Fact]
    public async Task O_mesmo_registro_nao_habilita_duas_contas()
    {
        var consulta = new ConsultaFalsa { Responder = (_, _) => Ativo() };
        var a = NovoUsuario(consulta);
        var b = NovoUsuario(consulta);
        await using var _a = a.Api;
        await using var _b = b.Api;

        Assert.Equal("HABILITADO", (await Verificado(a)).Resultado);

        var r = await PedirVerificacao(b, numero: $"00{_numero}", cpf: OutroCpf);
        Assert.Equal(HttpStatusCode.Conflict, r.StatusCode);
        Assert.DoesNotContain(Papeis.Educador, (await Me(b)).Papeis);
        Assert.Equal(1, consulta.Chamadas);
    }

    [Fact]
    public async Task Formato_invalido_responde_400_sem_consultar()
    {
        var consulta = new ConsultaFalsa();
        var u = NovoUsuario(consulta);
        await using var _a = u.Api;

        Assert.Equal(HttpStatusCode.BadRequest, (await PedirVerificacao(u, cpf: "529.982.247-26")).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await PedirVerificacao(u, uf: "XX")).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await PedirVerificacao(u, numero: "MG-12")).StatusCode);
        // "Eu não permito" ou sem a resposta: 400, nada consultado, nada habilitado.
        foreach (bool? permite in new bool?[] { false, null })
        {
            var semPermissao = await u.Client.PostAsJsonAsync(Verificar, new { uf = "MG", numero = _numero, cpf = Cpf, permiteConsulta = permite });
            Assert.Equal(HttpStatusCode.BadRequest, semPermissao.StatusCode);
        }
        Assert.DoesNotContain(Papeis.Educador, (await Me(u)).Papeis);
        Assert.Equal(0, consulta.Chamadas);
    }

    [Fact]
    public async Task Sem_token_responde_401()
    {
        await using var api = new ApiFactory(_postgres.ConnectionString) { ExigirCref = true };
        var anonimo = api.CreateClient();
        Assert.Equal(HttpStatusCode.Unauthorized, (await anonimo.GetAsync(Situacao)).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized,
            (await anonimo.PostAsJsonAsync(Verificar, new { uf = "MG", numero = "1", cpf = Cpf })).StatusCode);
    }

    // ---- Rota antiga e trava ----

    [Fact]
    public async Task Rota_antiga_nao_concede_o_papel_com_a_chave_ligada_e_continua_igual_desligada()
    {
        var ligada = NovoUsuario();
        var desligada = NovoUsuario(exigirCref: false);
        await using var _l = ligada.Api;
        await using var _d = desligada.Api;
        await Me(ligada);

        var r = await ligada.Client.PostAsync("/api/v1/me/papeis/educador", null);
        Assert.Equal(HttpStatusCode.Forbidden, r.StatusCode);
        Assert.DoesNotContain(Papeis.Educador, (await Me(ligada)).Papeis);

        (await desligada.Client.PostAsync("/api/v1/me/papeis/educador", null)).EnsureSuccessStatusCode();
        Assert.Contains(Papeis.Educador, (await Me(desligada)).Papeis);
        Assert.False((await desligada.Client.GetFromJsonAsync<SituacaoResp>(Situacao))!.VerificacaoExigida);
    }

    /// <summary>Educador antigo (papel sem habilitação) com um aluno de vínculo ativo, semeados no banco.</summary>
    private async Task<(Usuario Educador, Guid EducadorId, Guid AlunoId)> EducadorAntigoComAluno(ConsultaFalsa? consulta = null)
    {
        var educador = NovoUsuario(consulta);
        var educadorId = (await Me(educador)).Id;
        await using var db = _postgres.CriarContexto();
        var aluno = new Domain.Identidade.Usuario
        {
            Id = Guid.NewGuid(), FirebaseUid = $"uid-{Guid.NewGuid():n}", Nome = "Aluno",
            Email = $"{Guid.NewGuid():n}@teste.local", Ativo = true, CriadoEm = DateTimeOffset.UtcNow,
        };
        db.Usuarios.Add(aluno);
        db.UsuarioPapeis.Add(new UsuarioPapel { UsuarioId = educadorId, Papel = Papeis.Educador });
        db.Vinculos.Add(new Vinculo
        {
            Id = Guid.NewGuid(), EducadorId = educadorId, AlunoId = aluno.Id,
            Status = StatusVinculo.Ativo, Inicio = DateTimeOffset.UtcNow,
        });
        await db.SaveChangesAsync();
        return (educador, educadorId, aluno.Id);
    }

    private static string LeituraDoAluno(Guid alunoId) => $"/api/v1/sessoes?de=2026-01-01&ate=2026-12-31&atletaId={alunoId}";

    private static async Task AssertTravado(HttpResponseMessage r)
    {
        Assert.Equal(HttpStatusCode.Forbidden, r.StatusCode);
        var problema = await r.Content.ReadFromJsonAsync<ProblemaResp>();
        Assert.Equal("educador-nao-habilitado", problema!.Type);
        Assert.Equal("Confirme seu registro no CREF para continuar.", problema.Detail);
    }

    [Fact]
    public async Task Educador_antigo_fica_travado_sem_perder_nada_e_volta_ao_verificar()
    {
        var consulta = new ConsultaFalsa { Responder = (_, _) => Ativo() };
        var (educador, educadorId, alunoId) = await EducadorAntigoComAluno(consulta);
        await using var _e = educador.Api;

        await AssertTravado(await educador.Client.GetAsync(LeituraDoAluno(alunoId)));
        await AssertTravado(await educador.Client.GetAsync("/api/v1/alunos"));
        await AssertTravado(await educador.Client.PostAsJsonAsync("/api/v1/vinculos", new { email = "x@teste.local" }));
        // Quem não é parte do vínculo continua 404, antes da trava.
        Assert.Equal(HttpStatusCode.NotFound, (await educador.Client.GetAsync(LeituraDoAluno(Guid.NewGuid()))).StatusCode);

        await using (var db = _postgres.CriarContexto())
        {
            Assert.True(await db.Vinculos.AnyAsync(v => v.EducadorId == educadorId && v.Status == StatusVinculo.Ativo));
        }

        Assert.Equal("HABILITADO", (await Verificado(educador)).Resultado);
        Assert.Equal(HttpStatusCode.OK, (await educador.Client.GetAsync(LeituraDoAluno(alunoId))).StatusCode);
        Assert.Single((await educador.Client.GetFromJsonAsync<List<JsonElement>>("/api/v1/alunos"))!);
    }

    [Fact]
    public async Task O_script_do_legado_libera_so_quem_foi_informado()
    {
        var (vinicius, _, alunoDele) = await EducadorAntigoComAluno();
        var (outro, outroId, alunoDoOutro) = await EducadorAntigoComAluno();
        await using var _v = vinicius.Api;
        await using var _o = outro.Api;

        await RodarScriptDoLegado(vinicius.Email.ToUpperInvariant());
        await RodarScriptDoLegado(vinicius.Email); // de novo: não duplica

        Assert.Equal(HttpStatusCode.OK, (await vinicius.Client.GetAsync(LeituraDoAluno(alunoDele))).StatusCode);
        var registro = (await vinicius.Client.GetFromJsonAsync<SituacaoResp>(Situacao))!.Registro!;
        Assert.Equal((OrigemCref.Legado, (string?)null, (string?)null), (registro.Origem, registro.Uf, registro.Numero));

        await AssertTravado(await outro.Client.GetAsync(LeituraDoAluno(alunoDoOutro)));
        await using var db = _postgres.CriarContexto();
        Assert.False(await db.EducadoresCref.AnyAsync(e => e.UsuarioId == outroId));
    }

    private async Task RodarScriptDoLegado(string email)
    {
        var sql = await File.ReadAllTextAsync(CaminhoDoScript());
        await using var db = _postgres.CriarContexto();
        await db.Database.ExecuteSqlRawAsync(
            sql.Replace("lower(:'email')", "lower(@email)"), new NpgsqlParameter("email", email));
    }

    private static string CaminhoDoScript()
    {
        for (var dir = new DirectoryInfo(AppContext.BaseDirectory); dir is not null; dir = dir.Parent)
        {
            var caminho = Path.Combine(dir.FullName, "docs", "scripts", "habilitar-educador-legado.sql");
            if (File.Exists(caminho)) return caminho;
        }
        throw new FileNotFoundException("docs/scripts/habilitar-educador-legado.sql");
    }

    [Fact]
    public async Task Delete_me_apaga_a_habilitacao_e_as_tentativas()
    {
        var consulta = new ConsultaFalsa { Responder = (_, _) => Ativo($"MG-00{_numero}") };
        var u = NovoUsuario(consulta);
        await using var _a = u.Api;
        var id = (await Me(u)).Id;
        await Verificado(u);

        (await u.Client.DeleteAsync("/api/v1/me")).EnsureSuccessStatusCode();

        await using var db = _postgres.CriarContexto();
        Assert.False(await db.EducadoresCref.AnyAsync(e => e.UsuarioId == id));
        Assert.False(await db.TentativasCref.AnyAsync(t => t.UsuarioId == id));
    }

    // ---- CPF ----

    [Fact]
    public async Task O_cpf_nao_aparece_em_log_tabela_nem_resposta()
    {
        var logs = new CapturaDeLogs();
        var consulta = new ConsultaFalsa();
        var u = NovoUsuario(consulta, logs);
        await using var _a = u.Api;
        var id = (await Me(u)).Id;
        var respostas = new List<string>();

        async Task Pedir(string numero, string cpf, ResultadoConsultaCref resposta)
        {
            consulta.Responder = (_, _) => resposta;
            var r = await PedirVerificacao(u, numero: numero, cpf: cpf);
            respostas.Add(await r.Content.ReadAsStringAsync());
        }

        await Pedir(_numero, CpfFormatado, new ResultadoConsultaCref.Indisponivel());
        await Pedir(_numero, Cpf, new ResultadoConsultaCref.NaoEncontrado());
        await Pedir(_numero, "529.982.247-26", new ResultadoConsultaCref.NaoEncontrado()); // 400
        await Pedir(_numero, CpfFormatado, new ResultadoConsultaCref.Encontrado([new RegistroEncontrado($"MG-{_numero}", "SUSPENSO", "BACHAREL")]));
        await Pedir(_numero, CpfFormatado, new ResultadoConsultaCref.Encontrado([new RegistroEncontrado($"MG-{_numero}", "ATIVO", "BACHAREL")]));
        respostas.Add(await u.Client.GetStringAsync(Situacao));

        await using var db = _postgres.CriarContexto();
        var linhas = JsonSerializer.Serialize(new
        {
            habilitacao = await db.EducadoresCref.Where(e => e.UsuarioId == id).ToListAsync(),
            tentativas = await db.TentativasCref.Where(t => t.UsuarioId == id).ToListAsync(),
        });

        Assert.NotEmpty(logs.Textos);
        Assert.Contains("HABILITADO", respostas[^2]);
        foreach (var texto in logs.Textos.Concat(respostas).Append(linhas))
        {
            Assert.DoesNotContain(Cpf, texto);
            Assert.DoesNotContain(CpfFormatado, texto);
            Assert.DoesNotContain("52998224726", texto);
        }
    }
}
