using System.IdentityModel.Tokens.Jwt;
using System.Security.Cryptography;
using System.Security.Claims;
using Microsoft.IdentityModel.Tokens;

namespace DiarioTreino.IntegrationTests.Infraestrutura;

/// <summary>
/// Emite tokens assinados localmente com uma chave RSA de teste, imitando o
/// formato do Firebase (issuer securetoken, audience = projectId). A fábrica de
/// teste configura o JwtBearer para validar com a chave pública daqui, sem rede.
/// </summary>
public sealed class TokenFalsoFirebase
{
    public const string ProjectId = "diario-treino-teste";
    public static string Issuer => $"https://securetoken.google.com/{ProjectId}";

    private readonly RSA _rsa = RSA.Create(2048);

    public SecurityKey ChavePublica => new RsaSecurityKey(_rsa.ExportParameters(false));

    public string Gerar(string uid, string? email = null, string? nome = null)
    {
        var chaveAssinatura = new RsaSecurityKey(_rsa);
        var credenciais = new SigningCredentials(chaveAssinatura, SecurityAlgorithms.RsaSha256);

        var claims = new List<Claim>
        {
            new("user_id", uid),
            new(JwtRegisteredClaimNames.Sub, uid),
        };
        if (!string.IsNullOrWhiteSpace(email))
        {
            claims.Add(new Claim("email", email));
        }
        if (!string.IsNullOrWhiteSpace(nome))
        {
            claims.Add(new Claim("name", nome));
        }

        var agora = DateTime.UtcNow;
        var token = new JwtSecurityToken(
            issuer: Issuer,
            audience: ProjectId,
            claims: claims,
            notBefore: agora,
            expires: agora.AddHours(1),
            signingCredentials: credenciais);

        return new JwtSecurityTokenHandler().WriteToken(token);
    }
}
