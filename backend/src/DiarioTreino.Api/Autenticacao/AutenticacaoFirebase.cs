using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
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
                        // O Firebase Auth Emulator emite ID tokens com cabeçalho
                        // "alg": "none" e SEM assinatura (firebase-tools #2813). O
                        // JsonWebTokenHandler recusa tokens não assinados ANTES de
                        // chegar no SignatureValidator, a menos que RequireSignedTokens
                        // seja falso. Sem isto, todo token do emulador vira 401.
                        RequireSignedTokens = false,
                        SignatureValidator = (token, _) =>
                            new Microsoft.IdentityModel.JsonWebTokens.JsonWebToken(token),
                        ClockSkew = TimeSpan.FromSeconds(30),
                    };

                    // SOMENTE no modo emulador (E2E): loga o motivo exato de um
                    // 401, para diagnosticar a validação do token do emulador no
                    // CI sem precisar ligar o log interno do JwtBearer. Em
                    // produção este ramo não roda, então nada é logado.
                    options.Events = new JwtBearerEvents
                    {
                        OnMessageReceived = context =>
                        {
                            var temAuth = !string.IsNullOrEmpty(
                                context.Request.Headers.Authorization.ToString());
                            context.HttpContext.RequestServices
                                .GetRequiredService<ILoggerFactory>()
                                .CreateLogger("AutenticacaoEmulador")
                                .LogInformation(
                                    "E2E auth: Authorization header presente? {TemAuth}", temAuth);
                            return Task.CompletedTask;
                        },
                        OnAuthenticationFailed = context =>
                        {
                            context.HttpContext.RequestServices
                                .GetRequiredService<ILoggerFactory>()
                                .CreateLogger("AutenticacaoEmulador")
                                .LogWarning(context.Exception,
                                    "E2E auth: falha ao validar token: {Erro}",
                                    context.Exception.Message);
                            return Task.CompletedTask;
                        },
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
