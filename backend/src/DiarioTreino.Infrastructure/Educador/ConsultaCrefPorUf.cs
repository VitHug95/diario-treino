using System.Collections.Concurrent;
using DiarioTreino.Application.Educador;
using Microsoft.Extensions.Configuration;

namespace DiarioTreino.Infrastructure.Educador;

/// <summary>Onde e como consultar o CREF de uma UF (seção <c>Cref:Consultas</c> da configuração).</summary>
public sealed record ConsultaDaUf(string Uf, string Sistema, Uri Endereco);

/// <summary>
/// Regras de uso da consulta (PBI-105, seção 5): tempo limite curto, nenhuma
/// nova tentativa automática, no máximo <see cref="ConcorrenciaPorSite"/>
/// consultas ao mesmo site ao mesmo tempo e um <c>User-Agent</c> que identifica o app.
/// </summary>
public sealed record OpcoesConsultaCref(
    IReadOnlyDictionary<string, ConsultaDaUf> Consultas,
    string UserAgent,
    TimeSpan TempoLimite,
    int ConcorrenciaPorSite)
{
    public const string NomeDoCliente = "cref";

    /// <summary>
    /// Lê <c>Cref:Consultas:{UF}:Sistema</c> e <c>:Endereco</c>, além de
    /// <c>Cref:UserAgent</c>, <c>Cref:TempoLimiteSegundos</c> e
    /// <c>Cref:ConcorrenciaPorSite</c>. UF com endereço inválido é ignorada.
    /// </summary>
    public static OpcoesConsultaCref Ler(IConfiguration configuracao)
    {
        var secao = configuracao.GetSection("Cref");
        var consultas = new Dictionary<string, ConsultaDaUf>(StringComparer.OrdinalIgnoreCase);
        foreach (var uf in secao.GetSection("Consultas").GetChildren())
        {
            var sistema = uf["Sistema"];
            if (string.IsNullOrWhiteSpace(sistema)
                || !Uri.TryCreate(uf["Endereco"], UriKind.Absolute, out var endereco)
                || endereco.Scheme != Uri.UriSchemeHttps)
            {
                continue;
            }
            var sigla = uf.Key.ToUpperInvariant();
            consultas[sigla] = new ConsultaDaUf(sigla, sistema.Trim(), endereco);
        }

        var segundos = int.TryParse(secao["TempoLimiteSegundos"], out var s) && s is > 0 and <= 30 ? s : 10;
        var concorrencia = int.TryParse(secao["ConcorrenciaPorSite"], out var c) && c is > 0 and <= 5 ? c : 2;
        var userAgent = string.IsNullOrWhiteSpace(secao["UserAgent"]) ? "DiarioTreino/1.0" : secao["UserAgent"]!.Trim();
        return new OpcoesConsultaCref(consultas, userAgent, TimeSpan.FromSeconds(segundos), concorrencia);
    }
}

/// <summary>
/// Lê a página de um sistema de consulta (Spiderware, Implanta). Só busca
/// Profissional por CPF. Não guarda nem loga o CPF, o HTML ou o nome.
/// </summary>
public interface ILeitorCref
{
    /// <summary>Nome do sistema na configuração (<c>Cref:Consultas:{UF}:Sistema</c>).</summary>
    public string Sistema { get; }

    public Task<ResultadoConsultaCref> ConsultarPorCpfAsync(
        HttpClient http, ConsultaDaUf consulta, string cpf, CancellationToken ct);
}

/// <summary>
/// A consulta real do CREF (PBI-106): acha a configuração da UF, o leitor do
/// sistema dela e aplica as regras de uso. Qualquer falta (UF sem
/// configuração, sistema sem leitor, site ocupado, erro, tempo esgotado) vira
/// <see cref="ResultadoConsultaCref.Indisponivel"/>, que nunca recusa.
/// </summary>
public sealed class ConsultaCrefPorUf : IConsultaCref
{
    // Um limite por site, compartilhado entre as requisições desta instância.
    private static readonly ConcurrentDictionary<string, SemaphoreSlim> Vagas = new(StringComparer.OrdinalIgnoreCase);

    private readonly OpcoesConsultaCref _opcoes;
    private readonly IHttpClientFactory _clientes;
    private readonly IReadOnlyDictionary<string, ILeitorCref> _leitores;

    public ConsultaCrefPorUf(OpcoesConsultaCref opcoes, IHttpClientFactory clientes, IEnumerable<ILeitorCref> leitores)
    {
        _opcoes = opcoes;
        _clientes = clientes;
        _leitores = leitores.ToDictionary(l => l.Sistema, StringComparer.OrdinalIgnoreCase);
    }

    public async Task<ResultadoConsultaCref> ConsultarPorCpfAsync(string uf, string cpf, CancellationToken ct)
    {
        if (!_opcoes.Consultas.TryGetValue(uf, out var consulta)
            || !_leitores.TryGetValue(consulta.Sistema, out var leitor))
        {
            return new ResultadoConsultaCref.Indisponivel();
        }

        var vaga = Vagas.GetOrAdd(consulta.Endereco.Host, _ => new SemaphoreSlim(_opcoes.ConcorrenciaPorSite));

        // Um prazo só para esperar a vaga e consultar: o usuário nunca espera
        // mais que o tempo limite.
        using var prazo = CancellationTokenSource.CreateLinkedTokenSource(ct);
        prazo.CancelAfter(_opcoes.TempoLimite);
        try
        {
            await vaga.WaitAsync(prazo.Token);
        }
        catch (OperationCanceledException) when (!ct.IsCancellationRequested)
        {
            // Site ocupado até o fim do prazo.
            return new ResultadoConsultaCref.Indisponivel();
        }

        try
        {
            var http = _clientes.CreateClient(OpcoesConsultaCref.NomeDoCliente);
            return await leitor.ConsultarPorCpfAsync(http, consulta, cpf, prazo.Token);
        }
        catch (Exception e) when (e is not OperationCanceledException || !ct.IsCancellationRequested)
        {
            // A exceção não é repassada nem logada: a mensagem dela poderia
            // carregar o que foi enviado.
            return new ResultadoConsultaCref.Indisponivel();
        }
        finally
        {
            vaga.Release();
        }
    }
}
