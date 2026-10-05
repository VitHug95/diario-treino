using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;
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
                ["ConnectionStrings:DiarioTreino"] = _connectionString,
                ["Firebase:ProjectId"] = TokenFalsoFirebase.ProjectId,
            });
        });

        builder.ConfigureTestServices(services =>
        {
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
