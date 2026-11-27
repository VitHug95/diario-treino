using DiarioTreino.Application.Comum;
using DiarioTreino.Application.Educador;
using DiarioTreino.Application.Identidade;
using DiarioTreino.Domain.Comum;
using DiarioTreino.Domain.Educador;
using DiarioTreino.Domain.Identidade;

namespace DiarioTreino.UnitTests.Educador;

/// <summary>PBI-106: CPF, número, tabela de decisão e o serviço de verificação.</summary>
public sealed class CrefTests
{
    // CPFs de exemplo, válidos na conta e sem dono conhecido (usados em documentação).
    private const string CpfValido = "52998224725";
    private const string OutroCpfValido = "11144477735";

    // ---- CPF ----

    [Theory]
    [InlineData("52998224725")]
    [InlineData("529.982.247-25")]
    [InlineData("111.444.777-35")]
    public void Cpf_valido(string cpf) => Assert.True(Cpf.EhValido(cpf));

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("5299822472")]
    [InlineData("529982247250")]
    [InlineData("52998224726")]
    [InlineData("52998224715")]
    [InlineData("00000000000")]
    [InlineData("11111111111")]
    [InlineData("abc.def.ghi-jk")]
    public void Cpf_invalido(string? cpf) => Assert.False(Cpf.EhValido(cpf));

    // ---- Número ----

    [Theory]
    [InlineData("MG-001234", "1234")]
    [InlineData("001234", "1234")]
    [InlineData("1234", "1234")]
    [InlineData("012345-G/MG", "12345")]
    [InlineData("", "")]
    public void Normaliza_o_numero(string numero, string esperado) =>
        Assert.Equal(esperado, RegistroCref.Normalizar(numero));

    [Fact]
    public void Mesmo_numero_ignora_prefixo_e_zeros_mas_nao_aceita_vazio()
    {
        Assert.True(RegistroCref.MesmoNumero("MG-000123", "123"));
        Assert.False(RegistroCref.MesmoNumero("MG-000123", "1234"));
        Assert.False(RegistroCref.MesmoNumero("", ""));
    }

    [Fact]
    public void Ufs_sao_27_e_as_com_consulta_estao_entre_elas()
    {
        Assert.Equal(27, RegistroCref.Ufs.Count);
        Assert.Equal(19, RegistroCref.UfsComConsulta.Count);
        Assert.All(RegistroCref.UfsComConsulta, uf => Assert.Contains(uf, RegistroCref.Ufs));
        // SP tem consulta, mas sem busca por CPF; as outras ainda sem endereço.
        foreach (var uf in new[] { "SP", "MS", "PE", "PI", "PA", "AP", "AL", "MA" })
        {
            Assert.DoesNotContain(uf, RegistroCref.UfsComConsulta);
        }
    }

    // ---- Tabela de decisão ----

    private static ResultadoConsultaCref Encontrado(params RegistroEncontrado[] r) =>
        new ResultadoConsultaCref.Encontrado(r);

    [Fact]
    public void Numero_certo_e_ativo_habilita_qualquer_categoria()
    {
        var d = DecisaoCref.Decidir("1234", Encontrado(new RegistroEncontrado("MG-001234", "ATIVO", "PROVISIONADO")));
        Assert.Equal(ResultadoCref.Habilitado, d.Resultado);
        Assert.Null(d.Motivo);
        Assert.Equal("ATIVO", d.Situacao);
    }

    [Fact]
    public void Ativo_sem_diferenciar_maiusculas_e_espacos()
    {
        var d = DecisaoCref.Decidir("1234", Encontrado(new RegistroEncontrado("1234", " Ativo ", "BACHAREL")));
        Assert.Equal(ResultadoCref.Habilitado, d.Resultado);
    }

    [Fact]
    public void Situacao_nao_ativa_recusa_e_mostra_a_situacao()
    {
        var d = DecisaoCref.Decidir("1234", Encontrado(new RegistroEncontrado("MG-001234", "CANCELADO", "BACHAREL")));
        Assert.Equal(ResultadoCref.Recusado, d.Resultado);
        Assert.Equal(MotivoCref.SituacaoNaoAtiva, d.Motivo);
        Assert.Equal("CANCELADO", d.Situacao);
    }

    [Fact]
    public void Formatos_vistos_nos_prints_do_po()
    {
        // Spiderware: "MG-" + seis dígitos; Implanta: "000000-G/SP". Números fictícios.
        var spiderware = DecisaoCref.Decidir("12345", Encontrado(new RegistroEncontrado("MG-012345", "ATIVO", "BACHAREL")));
        var implanta = DecisaoCref.Decidir("12345", Encontrado(new RegistroEncontrado("012345-G/SP", "ATIVO", "LICENCIADO/BACHAREL")));
        var baixado = DecisaoCref.Decidir("12345", Encontrado(new RegistroEncontrado("012345-G/SP", "BAIXADO", "BACHAREL")));

        Assert.Equal(ResultadoCref.Habilitado, spiderware.Resultado);
        Assert.Equal(ResultadoCref.Habilitado, implanta.Resultado);
        Assert.Equal((ResultadoCref.Recusado, MotivoCref.SituacaoNaoAtiva, "BAIXADO"),
            (baixado.Resultado, baixado.Motivo, baixado.Situacao));
    }

    [Fact]
    public void Ativo_com_outra_palavra_nao_e_ativo()
    {
        var d = DecisaoCref.Decidir("1234", Encontrado(new RegistroEncontrado("1234", "INATIVO", "BACHAREL")));
        Assert.Equal(MotivoCref.SituacaoNaoAtiva, d.Motivo);
    }

    [Fact]
    public void Cpf_com_registro_de_outro_numero_recusa()
    {
        var d = DecisaoCref.Decidir("9999", Encontrado(new RegistroEncontrado("MG-001234", "ATIVO", "BACHAREL")));
        Assert.Equal(ResultadoCref.Recusado, d.Resultado);
        Assert.Equal(MotivoCref.NumeroNaoConfere, d.Motivo);
        Assert.Null(d.Situacao);
    }

    [Fact]
    public void Com_mais_de_um_registro_vale_o_de_numero_certo()
    {
        var d = DecisaoCref.Decidir("1234", Encontrado(
            new RegistroEncontrado("MG-000777", "CANCELADO", "BACHAREL"),
            new RegistroEncontrado("MG-001234", "ATIVO", "LICENCIADO")));
        Assert.Equal(ResultadoCref.Habilitado, d.Resultado);
        Assert.Equal("LICENCIADO", d.Registro!.Categoria);
    }

    [Fact]
    public void Sem_registro_e_lista_vazia_sao_nao_encontrado()
    {
        Assert.Equal(ResultadoCref.NaoEncontrado,
            DecisaoCref.Decidir("1234", new ResultadoConsultaCref.NaoEncontrado()).Resultado);
        Assert.Equal(ResultadoCref.NaoEncontrado, DecisaoCref.Decidir("1234", Encontrado()).Resultado);
    }

    [Fact]
    public void Indisponivel_nunca_recusa()
    {
        var d = DecisaoCref.Decidir("1234", new ResultadoConsultaCref.Indisponivel());
        Assert.Equal(ResultadoCref.Indisponivel, d.Resultado);
        Assert.Null(d.Motivo);
    }

    [Fact]
    public void A_consulta_so_sabe_buscar_por_cpf()
    {
        // Regra da PBI-105: nunca por nome, nunca Pessoa Jurídica.
        var metodos = typeof(IConsultaCref).GetMethods();
        var unico = Assert.Single(metodos);
        Assert.Equal(nameof(IConsultaCref.ConsultarPorCpfAsync), unico.Name);
        Assert.Equal(["uf", "cpf", "ct"], unico.GetParameters().Select(p => p.Name));
    }

    [Fact]
    public void O_pedido_nao_mostra_o_cpf_no_texto()
    {
        var texto = new VerificarCrefRequest("MG", "1234", CpfValido).ToString();
        Assert.DoesNotContain(CpfValido, texto);
    }

    // ---- Validação ----

    [Fact]
    public void Validador_recusa_formatos_e_nao_repete_o_valor()
    {
        var v = new VerificarCrefValidator();
        Assert.True(v.Validate(new VerificarCrefRequest("mg", "001234", "529.982.247-25", true)).IsValid);

        var r = v.Validate(new VerificarCrefRequest("XX", "MG-12", "52998224726", true));
        Assert.Equal(3, r.Errors.Count);
        Assert.All(r.Errors, e => Assert.DoesNotContain("5299822472", e.ErrorMessage));
        Assert.False(v.Validate(new VerificarCrefRequest("MG", "0000", CpfValido, true)).IsValid);
        Assert.False(v.Validate(new VerificarCrefRequest(null, null, null)).IsValid);

        // "Eu não permito" (ou nada marcado): só esse erro, os dados estão certos.
        foreach (bool? permite in new bool?[] { false, null })
        {
            var semPermissao = v.Validate(new VerificarCrefRequest("MG", "1234", CpfValido, permite));
            var erro = Assert.Single(semPermissao.Errors);
            Assert.Equal(nameof(VerificarCrefRequest.PermiteConsulta), erro.PropertyName);
        }
    }

    // ---- Serviço ----

    private sealed class ConsultaFalsa : IConsultaCref
    {
        public ResultadoConsultaCref Resposta { get; set; } = new ResultadoConsultaCref.NaoEncontrado();
        public Exception? Erro { get; set; }
        public List<(string Uf, string Cpf)> Chamadas { get; } = [];

        public Task<ResultadoConsultaCref> ConsultarPorCpfAsync(string uf, string cpf, CancellationToken ct)
        {
            Chamadas.Add((uf, cpf));
            if (Erro is not null) throw Erro;
            return Task.FromResult(Resposta);
        }
    }

    private sealed class UsuariosFake : IRepositorioUsuario
    {
        public Dictionary<Guid, Usuario> PorId { get; } = [];
        public Task<Usuario?> ObterPorIdAsync(Guid id, CancellationToken ct) => Task.FromResult(PorId.GetValueOrDefault(id));
        public Task<Usuario?> ObterPorFirebaseUidAsync(string firebaseUid, CancellationToken ct) => Task.FromResult<Usuario?>(null);
        public Task<Usuario?> ObterPorEmailAsync(string email, CancellationToken ct) => Task.FromResult<Usuario?>(null);
        public void Adicionar(Usuario usuario) { }
        public Task SalvarAsync(CancellationToken ct) => Task.CompletedTask;
        public Task<bool> TentarInserirUsuarioAsync(Usuario usuario, CancellationToken ct) => Task.FromResult(true);
        public Task ExcluirContaAsync(Guid usuarioId, CancellationToken ct) => Task.CompletedTask;
    }

    private sealed class RelogioFixo(DateTimeOffset agora) : TimeProvider
    {
        public override DateTimeOffset GetUtcNow() => agora;
    }

    private static readonly DateTimeOffset Agora = new(2026, 11, 26, 15, 0, 0, TimeSpan.Zero);

    private sealed record Cenario(ServicoCref Servico, RepositorioEducadorCrefFake Cref, ConsultaFalsa Consulta, Usuario Usuario);

    private static Cenario Montar()
    {
        var usuario = new Usuario { Id = Guid.NewGuid(), Nome = "Ana", Email = "a@x.dev", FirebaseUid = "a" };
        usuario.Papeis.Add(new UsuarioPapel { UsuarioId = usuario.Id, Papel = Papeis.Atleta });
        var usuarios = new UsuariosFake();
        usuarios.PorId[usuario.Id] = usuario;
        var cref = new RepositorioEducadorCrefFake();
        var consulta = new ConsultaFalsa();
        var servico = new ServicoCref(cref, usuarios, consulta, new ConfiguracaoEducador(true), new RelogioFixo(Agora));
        return new(servico, cref, consulta, usuario);
    }

    [Fact]
    public async Task Habilitado_grava_a_evidencia_e_concede_o_papel_juntos()
    {
        var c = Montar();
        c.Consulta.Resposta = Encontrado(new RegistroEncontrado("MG-001234", "ATIVO", "Bacharel"));

        var r = await c.Servico.VerificarAsync(c.Usuario.Id, "mg", "001234", "529.982.247-25", CancellationToken.None);

        Assert.Equal(new VerificarCrefResposta(ResultadoCref.Habilitado, null, "ATIVO"), r);
        var e = Assert.Single(c.Cref.Habilitados);
        Assert.Equal(("MG", "1234", "ATIVO", "BACHAREL", OrigemCref.Automatica, (DateTimeOffset?)Agora),
            (e.Uf, e.Numero, e.Situacao, e.Categoria, e.Origem, e.ConsultadoEm));
        Assert.Contains(c.Usuario.Papeis, p => p.Papel == Papeis.Educador);
        Assert.Equal(1, c.Cref.Salvamentos);
        // A consulta recebe só os dígitos do CPF, e a UF em maiúsculas.
        Assert.Equal(("MG", CpfValido), Assert.Single(c.Consulta.Chamadas));
    }

    [Fact]
    public async Task Recusado_conta_tentativa_e_nao_concede()
    {
        var c = Montar();
        c.Consulta.Resposta = Encontrado(new RegistroEncontrado("1234", "SUSPENSO", "BACHAREL"));

        var r = await c.Servico.VerificarAsync(c.Usuario.Id, "MG", "1234", CpfValido, CancellationToken.None);

        Assert.Equal(new VerificarCrefResposta(ResultadoCref.Recusado, MotivoCref.SituacaoNaoAtiva, "SUSPENSO"), r);
        Assert.Empty(c.Cref.Habilitados);
        Assert.Equal(ResultadoCref.Recusado, Assert.Single(c.Cref.Tentativas).Resultado);
        Assert.DoesNotContain(c.Usuario.Papeis, p => p.Papel == Papeis.Educador);
    }

    [Fact]
    public async Task Indisponivel_e_erro_da_consulta_nao_gastam_tentativa()
    {
        var c = Montar();
        c.Consulta.Resposta = new ResultadoConsultaCref.Indisponivel();
        var r1 = await c.Servico.VerificarAsync(c.Usuario.Id, "MG", "1234", CpfValido, CancellationToken.None);

        c.Consulta.Erro = new HttpRequestException($"falhou com {CpfValido}");
        var r2 = await c.Servico.VerificarAsync(c.Usuario.Id, "MG", "1234", CpfValido, CancellationToken.None);

        Assert.Equal(ResultadoCref.Indisponivel, r1.Resultado);
        Assert.Equal(ResultadoCref.Indisponivel, r2.Resultado);
        Assert.Empty(c.Cref.Tentativas);
        Assert.Equal(0, c.Cref.Salvamentos);
    }

    [Fact]
    public async Task Uf_sem_consulta_nao_consulta_nem_gasta_tentativa()
    {
        var c = Montar();

        var r = await c.Servico.VerificarAsync(c.Usuario.Id, "SP", "1234", CpfValido, CancellationToken.None);

        Assert.Equal(new VerificarCrefResposta(ResultadoCref.Indisponivel, MotivoCref.UfSemConsulta, null), r);
        Assert.Empty(c.Consulta.Chamadas);
        Assert.Empty(c.Cref.Tentativas);
    }

    [Fact]
    public async Task Cinco_tentativas_em_24h_barram_a_sexta_sem_consultar()
    {
        var c = Montar();
        for (var i = 0; i < 5; i++)
        {
            c.Cref.Tentativas.Add(new TentativaCref
            {
                Id = Guid.NewGuid(), UsuarioId = c.Usuario.Id, Em = Agora.AddHours(-23), Resultado = ResultadoCref.NaoEncontrado,
            });
        }
        // Indisponível e as de mais de 24 h não contam.
        c.Cref.Tentativas.Add(new TentativaCref { Id = Guid.NewGuid(), UsuarioId = c.Usuario.Id, Em = Agora, Resultado = ResultadoCref.Indisponivel });

        await Assert.ThrowsAsync<LimiteTentativasCrefException>(() =>
            c.Servico.VerificarAsync(c.Usuario.Id, "MG", "1234", CpfValido, CancellationToken.None));
        Assert.Empty(c.Consulta.Chamadas);

        foreach (var t in c.Cref.Tentativas) t.Em = Agora.AddHours(-25);
        var r = await c.Servico.VerificarAsync(c.Usuario.Id, "MG", "1234", CpfValido, CancellationToken.None);
        Assert.Equal(ResultadoCref.NaoEncontrado, r.Resultado);
    }

    [Fact]
    public async Task Registro_de_outra_conta_da_409_sem_consultar()
    {
        var c = Montar();
        c.Cref.Habilitados.Add(new EducadorCref
        {
            UsuarioId = Guid.NewGuid(), Uf = "MG", Numero = "1234", Situacao = "ATIVO", Categoria = "BACHAREL",
            Origem = OrigemCref.Automatica, ConsultadoEm = Agora,
        });

        await Assert.ThrowsAsync<ConflitoException>(() =>
            c.Servico.VerificarAsync(c.Usuario.Id, "MG", "MG-001234", OutroCpfValido, CancellationToken.None));
        Assert.Empty(c.Consulta.Chamadas);
    }

    [Fact]
    public async Task Colisao_ao_salvar_vira_409_e_nao_concede_o_papel_no_banco()
    {
        var c = Montar();
        c.Consulta.Resposta = Encontrado(new RegistroEncontrado("1234", "ATIVO", "BACHAREL"));
        c.Cref.ColidirAoSalvar = true;

        await Assert.ThrowsAsync<ConflitoException>(() =>
            c.Servico.VerificarAsync(c.Usuario.Id, "MG", "1234", CpfValido, CancellationToken.None));
        Assert.Empty(c.Cref.Habilitados);
    }

    [Fact]
    public async Task Ja_habilitado_nao_consulta_de_novo()
    {
        var c = Montar();
        c.Cref.Habilitados.Add(new EducadorCref { UsuarioId = c.Usuario.Id, Origem = OrigemCref.Legado });

        var r = await c.Servico.VerificarAsync(c.Usuario.Id, "MG", "1234", CpfValido, CancellationToken.None);

        Assert.Equal(ResultadoCref.Habilitado, r.Resultado);
        Assert.Empty(c.Consulta.Chamadas);
    }
}
