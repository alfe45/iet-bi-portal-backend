using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.JsonWebTokens;
using Microsoft.IdentityModel.Tokens;
using iet_bi_portal_backend.Common.Security;
using iet_bi_portal_backend.Modules.Auth.Settings;

namespace iet_bi_portal_backend.Modules.Auth.Security;

public record AccessToken(string Token, DateTime ExpiresAt);

/// <summary>Crea access tokens JWT y refresh tokens.</summary>
public interface ITokenService
{
    AccessToken CrearAccessToken(Guid idUsuario, string email, IEnumerable<string> roles);
    string GenerarRefreshToken();
    string Hashear(string token);
}

public class TokenService : ITokenService
{
    private readonly JwtOptions _jwt;
    private readonly SigningCredentials _credenciales;
    private readonly JsonWebTokenHandler _handler = new();

    public TokenService(IOptions<JwtOptions> options)
    {
        _jwt = options.Value;
        var clave = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_jwt.SecretKey));
        _credenciales = new SigningCredentials(clave, SecurityAlgorithms.HmacSha256);
    }

    public AccessToken CrearAccessToken(Guid idUsuario, string email, IEnumerable<string> roles)
    {
        var ahora = DateTime.UtcNow;
        var expira = ahora.AddMinutes(_jwt.AccessTokenMinutes);

        var claims = new List<Claim>
        {
            new(JwtRegisteredClaimNames.Sub, idUsuario.ToString()),
            new(JwtRegisteredClaimNames.Email, email),
            new(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString())
        };
        claims.AddRange(roles.Select(r => new Claim(AuthClaims.Role, r)));

        var descriptor = new SecurityTokenDescriptor
        {
            Subject = new ClaimsIdentity(claims),
            Issuer = _jwt.Issuer,
            Audience = _jwt.Audience,
            IssuedAt = ahora,   // explícito: lo usa la revocación (iat vs tokens_invalidados_desde)
            Expires = expira,
            SigningCredentials = _credenciales
        };

        return new AccessToken(_handler.CreateToken(descriptor), expira);
    }

    /// <summary>Refresh token aleatorio de 32 bytes en hexadecimal.</summary>
    public string GenerarRefreshToken() => Convert.ToHexString(RandomNumberGenerator.GetBytes(32));

    /// <summary>SHA256 del token (en la base solo se guarda el hash).</summary>
    public string Hashear(string token) => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(token)));
}
