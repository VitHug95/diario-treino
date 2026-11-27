using System.Collections.Concurrent;
using System.Net;
using DiarioTreino.Application.Educador;
using DiarioTreino.Domain.Educador;
using DiarioTreino.Infrastructure;
using DiarioTreino.Infrastructure.Educador;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;

namespace DiarioTreino.IntegrationTests;

/// <summary>
/// PBI-106: a consulta do CREF montada como em produção (<c>AddInfrastructure</c>),
/// com um leitor falso e o HTTP falso: nunca chama os sites reais.
/// </summary>
public sealed class ConsultaCrefPorUfTests
{
    private const string Cpf = "52998224725";

    private sealed class HttpFalso : HttpMessageHandler
    {
        public List<HttpRequestMessage> Pedidos { get; } = [];
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken ct)
        {
            Pedidos.Add(request);
            return Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK) { Content = new StringContent("<html/>") });
        }
    }

    /// <summary>Leitor falso: faz um GET com o CPF na URL (o pior caso para log) e responde o combinado.</summary>
    private sealed class LeitorFalso(string sistema) : ILeitorCref
    {
        public string Sistema => sistema;
        public Func<CancellationToken, Task<ResultadoConsultaCref>> Responder { get; set; } =
            _ => Task.FromResult<ResultadoConsultaCref>(new ResultadoConsultaCref.NaoEncontrado());
        public List<(ConsultaDaUf Consulta, string Cpf)> Chamadas { get; } = [];

        public async Task<ResultadoConsultaCref> ConsultarPorCpfAsync(
            HttpClient http, ConsultaDaUf consulta, string cpf, CancellationToken ct)
        {
            lock (Chamadas) Chamadas.Add((consulta, cpf));
            await http.GetAsync(new Uri(consulta.Endereco, $"?cpf={cpf}"), ct);
            return await Responder(ct);
        }
    }

    private sealed class CapturaDeLogs : ILoggerProvider
    {
        public ConcurrentQueue<string> Textos { get; } = new();
        public ILogger CreateLogger(string categoria) => new Logger(this, categoria);
        public void Dispose() { }

        private sealed class Logger(CapturaDeLogs captura, string categoria) : ILogger
        {
            public IDisposable? BeginScope<TState>(TState state) where TState : notnull => null;
            public bool IsEnabled(LogLevel logLevel) => true;
            public void Log<TState>(LogLevel nivel, EventId id, TState estado, Exception? e, Func<TState, Exception?, string> formatar) =>
                captura.Textos.Enqueue($"{categoria} {formatar(estado, e)} {e}");
        }
    }

    private sealed record Montagem(IConsultaCref Consulta, LeitorFalso Leitor, HttpFalso Http, CapturaDeLogs Logs);

    private static Montagem Montar(Dictionary<string, string?> config)
    {
        var configuracao = new ConfigurationBuilder().AddInMemoryCollection(config).Build();
        var http = new HttpFalso();
        var leitor = new LeitorFalso("Spiderware");
        var logs = new CapturaDeLogs();
        var servicos = new ServiceCollection()
            .AddLogging(l => l.SetMinimumLevel(LogLevel.Trace).AddProvider(logs))
            .AddInfrastructure(configuracao);
        servicos.AddHttpClient(OpcoesConsultaCref.NomeDoCliente).ConfigurePrimaryHttpMessageHandler(() => http);
        servicos.AddSingleton<ILeitorCref>(leitor);
        var provedor = servicos.BuildServiceProvider();
        return new Montagem(provedor.GetRequiredService<IConsultaCref>(), leitor, http, logs);
    }

    private static Dictionary<string, string?> Config(string host, int tempoLimite = 10, int concorrencia = 2) => new()
    {
        ["Cref:UserAgent"] = "DiarioTreino/teste",
        ["Cref:TempoLimiteSegundos"] = tempoLimite.ToString(),
        ["Cref:ConcorrenciaPorSite"] = concorrencia.ToString(),
        ["Cref:Consultas:MG:Sistema"] = "Spiderware",
        ["Cref:Consultas:MG:Endereco"] = $"https://{host}/spw/ConsultaCadastral/Tela.aspx",
        ["Cref:Consultas:RJ:Sistema"] = "Implanta",
        ["Cref:Consultas:RJ:Endereco"] = $"https://{host}-rj/Publico/ConsultaInscritos/",
        ["Cref:Consultas:SC:Sistema"] = "Spiderware",
        ["Cref:Consultas:SC:Endereco"] = "http://sem-https.local/",
    };

    private static string HostNovo() => $"cref-{Guid.NewGuid():n}.teste";

    [Fact]
    public void A_configuracao_de_producao_cobre_exatamente_as_ufs_com_consulta()
    {
        var caminho = AcharArquivo(Path.Combine("backend", "src", "DiarioTreino.Api", "appsettings.json"));
        var opcoes = OpcoesConsultaCref.Ler(new ConfigurationBuilder().AddJsonFile(caminho).Build());

        Assert.Equal(RegistroCref.UfsComConsulta.OrderBy(u => u), opcoes.Consultas.Keys.OrderBy(u => u));
        Assert.All(opcoes.Consultas.Values, c =>
        {
            Assert.Equal(Uri.UriSchemeHttps, c.Endereco.Scheme);
            Assert.Contains(c.Sistema, new[] { "Spiderware", "Implanta" });
        });
        Assert.Equal(TimeSpan.FromSeconds(10), opcoes.TempoLimite);
        Assert.Equal(2, opcoes.ConcorrenciaPorSite);
        Assert.Contains("DiarioTreino", opcoes.UserAgent);
    }

    [Fact]
    public async Task Usa_o_leitor_do_sistema_da_uf_com_o_user_agent_do_app()
    {
        var m = Montar(Config(HostNovo()));
        m.Leitor.Responder = _ => Task.FromResult<ResultadoConsultaCref>(
            new ResultadoConsultaCref.Encontrado([new RegistroEncontrado("1", "ATIVO", "BACHAREL")]));

        var r = await m.Consulta.ConsultarPorCpfAsync("mg", Cpf, CancellationToken.None);

        Assert.IsType<ResultadoConsultaCref.Encontrado>(r);
        var (consulta, cpf) = Assert.Single(m.Leitor.Chamadas);
        Assert.Equal(("MG", Cpf), (consulta.Uf, cpf));
        Assert.Equal("DiarioTreino/teste", Assert.Single(m.Http.Pedidos).Headers.UserAgent.ToString());
    }

    [Theory]
    [InlineData("SP")] // UF sem configuração
    [InlineData("RJ")] // sistema (Implanta) sem leitor registrado
    [InlineData("SC")] // endereço sem https: ignorado
    public async Task Sem_configuracao_ou_sem_leitor_fica_indisponivel_sem_chamar_nada(string uf)
    {
        var m = Montar(Config(HostNovo()));

        var r = await m.Consulta.ConsultarPorCpfAsync(uf, Cpf, CancellationToken.None);

        Assert.IsType<ResultadoConsultaCref.Indisponivel>(r);
        Assert.Empty(m.Leitor.Chamadas);
        Assert.Empty(m.Http.Pedidos);
    }

    [Fact]
    public async Task Erro_do_leitor_e_tempo_esgotado_ficam_indisponiveis()
    {
        var m = Montar(Config(HostNovo(), tempoLimite: 1));

        m.Leitor.Responder = _ => throw new InvalidOperationException($"página inesperada para {Cpf}");
        Assert.IsType<ResultadoConsultaCref.Indisponivel>(await m.Consulta.ConsultarPorCpfAsync("MG", Cpf, CancellationToken.None));

        m.Leitor.Responder = async ct =>
        {
            await Task.Delay(TimeSpan.FromSeconds(5), ct);
            return new ResultadoConsultaCref.NaoEncontrado();
        };
        var relogio = System.Diagnostics.Stopwatch.StartNew();
        Assert.IsType<ResultadoConsultaCref.Indisponivel>(await m.Consulta.ConsultarPorCpfAsync("MG", Cpf, CancellationToken.None));
        Assert.True(relogio.Elapsed < TimeSpan.FromSeconds(4), $"demorou {relogio.Elapsed}");
    }

    [Fact]
    public async Task No_maximo_n_consultas_ao_mesmo_site_ao_mesmo_tempo()
    {
        var m = Montar(Config(HostNovo(), tempoLimite: 10, concorrencia: 2));
        var liberar = new TaskCompletionSource();
        m.Leitor.Responder = async ct =>
        {
            await liberar.Task.WaitAsync(ct);
            return new ResultadoConsultaCref.NaoEncontrado();
        };

        var consultas = Enumerable.Range(0, 3)
            .Select(_ => m.Consulta.ConsultarPorCpfAsync("MG", Cpf, CancellationToken.None))
            .ToList();
        await Task.Delay(300);
        Assert.Equal(2, m.Leitor.Chamadas.Count); // a terceira espera a vaga

        liberar.SetResult();
        var resultados = await Task.WhenAll(consultas);
        Assert.Equal(3, m.Leitor.Chamadas.Count);
        Assert.All(resultados, r => Assert.IsType<ResultadoConsultaCref.NaoEncontrado>(r));
    }

    [Fact]
    public async Task Site_ocupado_ate_o_fim_do_prazo_fica_indisponivel()
    {
        var m = Montar(Config(HostNovo(), tempoLimite: 1, concorrencia: 1));
        var liberar = new TaskCompletionSource();
        // O primeiro ignora o prazo (um leitor mal comportado) e segura a vaga.
        m.Leitor.Responder = async _ =>
        {
            await liberar.Task;
            return new ResultadoConsultaCref.NaoEncontrado();
        };

        var primeira = m.Consulta.ConsultarPorCpfAsync("MG", Cpf, CancellationToken.None);
        await Task.Delay(100);
        var segunda = await m.Consulta.ConsultarPorCpfAsync("MG", Cpf, CancellationToken.None);
        liberar.SetResult();
        await primeira;

        Assert.IsType<ResultadoConsultaCref.Indisponivel>(segunda);
        Assert.Single(m.Leitor.Chamadas);
    }

    [Fact]
    public async Task O_cliente_http_nao_loga_a_url_com_o_cpf()
    {
        var m = Montar(Config(HostNovo()));

        await m.Consulta.ConsultarPorCpfAsync("MG", Cpf, CancellationToken.None);

        Assert.Single(m.Http.Pedidos);
        Assert.Contains(Cpf, m.Http.Pedidos[0].RequestUri!.Query); // o leitor falso pôs o CPF na URL
        Assert.All(m.Logs.Textos, t => Assert.DoesNotContain(Cpf, t));
    }

    private static string AcharArquivo(string relativo)
    {
        for (var dir = new DirectoryInfo(AppContext.BaseDirectory); dir is not null; dir = dir.Parent)
        {
            var caminho = Path.Combine(dir.FullName, relativo);
            if (File.Exists(caminho)) return caminho;
        }
        throw new FileNotFoundException(relativo);
    }
}
