using DiarioTreino.Application.Educador;
using DiarioTreino.Infrastructure.Persistencia;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Microsoft.IdentityModel.Tokens;
using Serilog.Core;

namespace DiarioTreino.IntegrationTests.Infraestrutura;

/// <summary>
/// Sobe a API em memória (WebApplicationFactory) apontando para o Postgres do
/// container e com a validação do token trocada para a chave de teste
/// (<see cref="TokenFalsoFirebase"/>), sem acesso de rede ao Google.
/// </summary>
public sealed class ApiFactory : WebApplicationFactory<Program>
{
    private readonly string _connectionString;

    public TokenFalsoFirebase Tokens { get; } = new();

    /// <summary>Chave <c>Educador:ExigirCref</c> (PBI-106). Desligada por padrão, como em produção hoje.</summary>
    public bool ExigirCref { get; init; }

    /// <summary>Consulta do CREF falsa (PBI-106). Os testes nunca chamam o site real.</summary>
    public IConsultaCref? ConsultaCref { get; init; }

    /// <summary>Captura todos os eventos de log, para procurar dado que não pode vazar (o CPF).</summary>
    public ILogEventSink? Logs { get; init; }

    public ApiFactory(string connectionString)
    {
        _connectionString = connectionString;
    }

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Testing");

        builder.ConfigureAppConfiguration((_, config) =>
        {
            config.AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["Firebase:ProjectId"] = TokenFalsoFirebase.ProjectId,
            });
            if (Logs is not null)
            {
                // Tudo, inclusive o que o ASP.NET Core e o EF logam por dentro.
                config.AddInMemoryCollection(new Dictionary<string, string?>
                {
                    ["Serilog:MinimumLevel:Default"] = "Verbose",
                    ["Serilog:MinimumLevel:Override:Microsoft.AspNetCore"] = "Verbose",
                    ["Serilog:MinimumLevel:Override:Microsoft.EntityFrameworkCore"] = "Verbose",
                });
            }
        });

        builder.ConfigureTestServices(services =>
        {
            // Troca o DbContext para apontar ao Postgres do container de teste.
            // Fazemos pela DI (não por config) para não depender da ordem de
            // precedência das fontes de configuração — o appsettings.json tem a
            // connection string vazia e venceria o AddInMemoryCollection.
            services.RemoveAll<ConfiguracaoEducador>();
            services.AddSingleton(new ConfiguracaoEducador(ExigirCref));
            services.RemoveAll<IConsultaCref>();
            services.AddSingleton(ConsultaCref ?? new ConsultaCrefQueNaoDeveSerChamada());
            if (Logs is not null)
            {
                // O UseSerilog lê os sinks do DI (ReadFrom.Services).
                services.AddSingleton(Logs);
            }

            services.RemoveAll<DbContextOptions<DiarioTreinoDbContext>>();
            services.AddDbContext<DiarioTreinoDbContext>(options =>
                options.UseNpgsql(_connectionString));

            // Troca a validação do token para a chave pública de teste e desliga
            // a busca de metadados (Authority) na rede. PostConfigure roda depois
            // da configuração padrão do JwtBearer, então nossa versão prevalece.
            services.PostConfigure<JwtBearerOptions>(
                JwtBearerDefaults.AuthenticationScheme,
                options =>
                {
                    options.Authority = null;
                    options.MetadataAddress = null!;
                    options.RequireHttpsMetadata = false;
                    options.TokenValidationParameters = new TokenValidationParameters
                    {
                        ValidateIssuer = true,
                        ValidIssuer = TokenFalsoFirebase.Issuer,
                        ValidateAudience = true,
                        ValidAudience = TokenFalsoFirebase.ProjectId,
                        ValidateLifetime = true,
                        ValidateIssuerSigningKey = true,
                        IssuerSigningKey = Tokens.ChavePublica,
                    };
                });
        });
    }
}

/// <summary>Padrão dos testes: nenhuma consulta ao CREF é esperada.</summary>
internal sealed class ConsultaCrefQueNaoDeveSerChamada : IConsultaCref
{
    public Task<ResultadoConsultaCref> ConsultarPorCpfAsync(string uf, string cpf, CancellationToken ct) =>
        throw new InvalidOperationException("Consulta ao CREF inesperada neste teste.");
}
