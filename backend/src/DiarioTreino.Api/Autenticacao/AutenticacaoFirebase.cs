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

        services
            .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
            .AddJwtBearer(options =>
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
            });

        services.AddAuthorization();
        return services;
    }
}
