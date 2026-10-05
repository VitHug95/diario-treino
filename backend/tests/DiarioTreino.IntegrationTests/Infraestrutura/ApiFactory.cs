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
        });

        builder.ConfigureTestServices(services =>
        {
            // Troca o DbContext para apontar ao Postgres do container de teste.
            // Fazemos pela DI (não por config) para não depender da ordem de
            // precedência das fontes de configuração — o appsettings.json tem a
            // connection string vazia e venceria o AddInMemoryCollection.
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
