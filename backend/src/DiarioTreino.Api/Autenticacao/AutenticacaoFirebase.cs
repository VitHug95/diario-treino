using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;

namespace DiarioTreino.Api.Autenticacao;

/// <summary>
/// Configura a validação do ID token do Firebase (MAS 11.2):
/// <list type="bullet">
/// <item>Authority/Issuer: <c>https://securetoken.google.com/&lt;projectId&gt;</c></item>
/// <item>Audience: o id do projeto</item>
/// <item>Chaves públicas do Google obtidas automaticamente (sem segredo na API)</item>
/// </list>
/// O id do projeto vem de <c>Firebase:ProjectId</c> (variável de ambiente em
/// produção).
/// </summary>
public static class AutenticacaoFirebase
{
    public static IServiceCollection AddAutenticacaoFirebase(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        var projectId = configuration["Firebase:ProjectId"];
        if (string.IsNullOrWhiteSpace(projectId))
        {
            throw new InvalidOperationException(
                "Firebase:ProjectId não configurado. Defina em appsettings ou na variável " +
                "de ambiente FIREBASE__PROJECTID.");
        }

        var issuer = $"https://securetoken.google.com/{projectId}";

        // Modo emulador (SOMENTE para o E2E no CI): quando
        // Firebase:AuthEmulatorHost está definido, a API aceita tokens emitidos
        // pelo Firebase Auth Emulator. O emulador não assina os tokens com as
        // chaves do Google, então a validação da assinatura é dispensada; as
        // demais checagens (emissor, audiência, validade) continuam valendo.
        // Em produção a variável fica vazia e nada disto é ativado.
        var emulatorHost = configuration["Firebase:AuthEmulatorHost"];
        var usandoEmulador = !string.IsNullOrWhiteSpace(emulatorHost);

        services
            .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
            .AddJwtBearer(options =>
            {
                if (usandoEmulador)
                {
                    // O emulador emite com o mesmo issuer; sem metadados HTTPS e
                    // sem validar a chave de assinatura (tokens de teste).
                    options.RequireHttpsMetadata = false;
                    options.TokenValidationParameters = new TokenValidationParameters
                    {
                        ValidateIssuer = true,
                        ValidIssuer = issuer,
                        ValidateAudience = true,
                        ValidAudience = projectId,
                        ValidateLifetime = true,
                        ValidateIssuerSigningKey = false,
                        SignatureValidator = (token, _) =>
                            new Microsoft.IdentityModel.JsonWebTokens.JsonWebToken(token),
                        ClockSkew = TimeSpan.FromSeconds(30),
                    };
                }
                else
                {
                    options.Authority = issuer;
                    options.TokenValidationParameters = new TokenValidationParameters
                    {
                        ValidateIssuer = true,
                        ValidIssuer = issuer,
                        ValidateAudience = true,
                        ValidAudience = projectId,
                        ValidateLifetime = true,
                        ValidateIssuerSigningKey = true,
                        ClockSkew = TimeSpan.FromSeconds(30),
                    };
                }
            });

        services.AddAuthorization();
        return services;
    }
}
