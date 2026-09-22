using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.JsonWebTokens;
using Microsoft.IdentityModel.Tokens;
using iet_bi_portal_backend.Modules.Auth.Settings;

namespace iet_bi_portal_backend.Modules.Auth.Security;

public record AccessToken(string Token, DateTime ExpiresAt);

/// <summary> Servicio para crear y validar tokens JWT y refresh tokens. </summary>
public interface ITokenService
{
    AccessToken CreateAccessToken(Guid userId, string email, IEnumerable<string> roles);
    string GenerateRefreshToken();
    string Hash(string token);
}

/// <summary> Servicio para crear y validar tokens JWT y refresh tokens. </summary>
public class TokenService : ITokenService
{
    private readonly JwtOptions _jwt;
    private readonly SigningCredentials _credentials;
    private readonly JsonWebTokenHandler _handler = new();

    /// <summary> Crea un servicio para crear y validar tokens JWT y refresh tokens. </summary>
    public TokenService(IOptions<JwtOptions> options)
    {
        _jwt = options.Value;
        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_jwt.SecretKey));
        _credentials = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);
    }

    /// <summary> Crea un access token JWT para un usuario autenticado. </summary>
    public AccessToken CreateAccessToken(Guid userId, string email, IEnumerable<string> roles)
    {
        var expires = DateTime.UtcNow.AddMinutes(_jwt.AccessTokenMinutes);

        var claims = new List<Claim>
        {
            new(JwtRegisteredClaimNames.Sub, userId.ToString()),
            new(JwtRegisteredClaimNames.Email, email),
            new(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString())
        };
        // Un claim "role" por cada rol. [Authorize(Roles = "A,B")] valida
        // con OR contra todos los claims que compartan RoleClaimType, así que
        // esto funciona con [Authorize] sin ningún cambio adicional.
        claims.AddRange(roles.Select(r => new Claim(AuthClaims.Role, r)));

        var descriptor = new SecurityTokenDescriptor
        {
            Subject = new ClaimsIdentity(claims),
            Issuer = _jwt.Issuer,
            Audience = _jwt.Audience,
            Expires = expires,
            SigningCredentials = _credentials
        };

        return new AccessToken(_handler.CreateToken(descriptor), expires);
    }

    /// <summary> Genera un refresh token aleatorio de 32 bytes codificado en hexadecimal. </summary>
    public string GenerateRefreshToken() => Convert.ToHexString(RandomNumberGenerator.GetBytes(32));

    /// <summary> Calcula el hash SHA256 de un refresh token. </summary>
    public string Hash(string token) => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(token)));
}