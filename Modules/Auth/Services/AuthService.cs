using Microsoft.Extensions.Options;
using iet_bi_portal_backend.Common.Models;
using iet_bi_portal_backend.Common.Security;
using iet_bi_portal_backend.Common.Texto;
using iet_bi_portal_backend.Modules.Auth.Data;
using iet_bi_portal_backend.Modules.Auth.Models;
using iet_bi_portal_backend.Modules.Auth.Security;
using iet_bi_portal_backend.Modules.Auth.Settings;
using iet_bi_portal_backend.Modules.Logs;
using iet_bi_portal_backend.Modules.Logs.Services;

namespace iet_bi_portal_backend.Modules.Auth.Services;

public class AuthService(
    AuthRepository repo,
    IContrasenaService contrasenas,
    ITokenService tokens,
    IOptions<JwtOptions> jwtOptions,
    IOptions<AuthPolicyOptions> politicaOptions,
    ILogsService logs)
{
    private const string TablaUsuarios = "api.usuarios";

    private readonly JwtOptions _jwt = jwtOptions.Value;
    private readonly AuthPolicyOptions _politica = politicaOptions.Value;

    public async Task<ResultadoLogin> LoginAsync(string email, string contrasena, InfoCliente cliente)
    {
        email = email.NormalizarEmail();
        var usuario = await repo.ObtenerPorEmailAsync(email);

        // Correo inexistente: gasta el mismo tiempo que una verificación real (RP-24).
        if (usuario is null)
        {
            contrasenas.VerificarDummy(contrasena);
            return await FalloLoginAsync(null, email, "CORREO_INEXISTENTE", "AU006", cliente);
        }

        var bloqueado = usuario.BloqueadoHasta > DateTime.UtcNow;

        // Contraseña incorrecta: siempre genérico. Solo cuenta como intento fallido si la cuenta
        // está activa y no bloqueada.
        if (!contrasenas.Verificar(contrasena, usuario.ContrasenaHash))
        {
            var cuentaBloqueada = usuario.Activo && !bloqueado &&
                await repo.RegistrarLoginFallidoAsync(usuario.Id, _politica.MaxIntentosFallidos, _politica.MinutosBloqueo);
            return await FalloLoginAsync(usuario.Id, email, "CONTRASENA_INCORRECTA", "AU006", cliente, cuentaBloqueada);
        }

        // Contraseña correcta: recién aquí es seguro explicar el estado de la cuenta.
        if (!usuario.Activo) return await FalloLoginAsync(usuario.Id, email, "CUENTA_DESACTIVADA", "AU014", cliente);
        if (bloqueado) return await FalloLoginAsync(usuario.Id, email, "CUENTA_BLOQUEADA", "AU015", cliente);

        // Sin roles (solo por edición manual de la DB): fail-closed, sin filtrar el motivo.
        if (usuario.Roles.Count == 0) return await FalloLoginAsync(usuario.Id, email, "SIN_ROLES", "AU006", cliente);

        await repo.RegistrarLoginExitosoAsync(usuario.Id);
        await logs.RegistrarAsync(usuario.Id, AccionesLog.Login, ip: cliente.Ip, userAgent: cliente.UserAgent);
        return ResultadoLogin.Exito(await EmitirSesionAsync(usuario.Id, usuario.Email, usuario.Roles, cliente));
    }

    /// <summary>Audita el intento fallido (nunca la contraseña) y devuelve el código de error para el cliente.
    /// El motivo queda solo en el log: al cliente se le sigue respondiendo genérico donde corresponde.</summary>
    private async Task<ResultadoLogin> FalloLoginAsync(
        Guid? idUsuario, string email, string motivo, string codigoError, InfoCliente cliente, bool cuentaBloqueada = false)
    {
        await logs.RegistrarAsync(idUsuario, AccionesLog.LoginFallido, TablaUsuarios, idUsuario?.ToString(),
            datosNuevos: new { email, motivo, cuentaBloqueada }, ip: cliente.Ip, userAgent: cliente.UserAgent);
        return ResultadoLogin.Fallo(codigoError);
    }

    public async Task LogoutAsync(string refreshToken, InfoCliente cliente)
    {
        var idUsuario = await repo.LogoutAsync(tokens.Hashear(refreshToken));

        // Token inexistente: no se registra nada (evita ruido/abuso del endpoint anónimo).
        if (idUsuario is null) return;

        await logs.RegistrarAsync(idUsuario, AccionesLog.Logout, TablaUsuarios, idUsuario.Value.ToString(),
            ip: cliente.Ip, userAgent: cliente.UserAgent);
    }

    public async Task<AuthResponse?> RefreshAsync(string refreshToken, InfoCliente cliente)
    {
        var nuevoRefreshToken = tokens.GenerarRefreshToken();

        var resultado = await repo.RotarSesionAsync(
            tokens.Hashear(refreshToken),
            tokens.Hashear(nuevoRefreshToken),
            DateTime.UtcNow.AddDays(_jwt.RefreshTokenDays),
            cliente.Ip,
            cliente.UserAgent);

        // Reutilización de un refresh token ya rotado: la DB ya revocó todo el acceso; se audita.
        if (resultado.Estado == "reused" && resultado.IdUsuario is { } idReutilizado)
            await logs.RegistrarAsync(idReutilizado, AccionesLog.SesionReutilizada, TablaUsuarios, idReutilizado.ToString(),
                ip: cliente.Ip, userAgent: cliente.UserAgent);

        if (resultado.Estado != "ok" || resultado.Usuario is not { Roles.Count: > 0 } usuario) return null;

        var access = tokens.CrearAccessToken(usuario.Id, usuario.Email, usuario.Roles);
        return new AuthResponse(access.Token, access.ExpiresAt, nuevoRefreshToken);
    }

    public async Task LogoutAllAsync(Guid idUsuario)
    {
        await repo.LogoutAllAsync(idUsuario);
        await logs.RegistrarAsync(idUsuario, AccionesLog.LogoutAll, TablaUsuarios, idUsuario.ToString());
    }

    /// <summary>Cambia la contraseña propia. false si la actual es incorrecta o el usuario no está activo.</summary>
    public async Task<bool> CambiarContrasenaAsync(Guid idUsuario, string contrasenaActual, string contrasenaNueva)
    {
        var usuario = await repo.ObtenerPorIdAsync(idUsuario);
        if (usuario is null || !usuario.Activo || !contrasenas.Verificar(contrasenaActual, usuario.ContrasenaHash))
            return false;

        await repo.EstablecerContrasenaAsync(idUsuario, contrasenas.Hashear(contrasenaNueva));
        await logs.RegistrarAsync(idUsuario, AccionesLog.CambiarContrasena, TablaUsuarios, idUsuario.ToString());   // nunca el hash
        return true;
    }

    /// <summary>Crea el primer administrador. Si ya existe o el correo está en uso, la excepción
    /// de Postgres (AU001/TA001) sube tal cual y la traduce GlobalExceptionHandler.</summary>
    public async Task<(Guid Id, string Email)> CrearPrimerAdminAsync(string email, string contrasena)
    {
        email = email.NormalizarEmail();
        var id = await repo.CrearPrimerAdminAsync(email, contrasenas.Hashear(contrasena));
        await logs.RegistrarAsync(id, AccionesLog.CrearPrimerAdmin, TablaUsuarios, id.ToString());
        return (id, email);
    }

    private async Task<AuthResponse> EmitirSesionAsync(
        Guid idUsuario, string email, IReadOnlyList<string> roles, InfoCliente cliente)
    {
        var refreshToken = tokens.GenerarRefreshToken();

        await repo.CrearSesionAsync(
            idUsuario,
            tokens.Hashear(refreshToken),
            DateTime.UtcNow.AddDays(_jwt.RefreshTokenDays),
            cliente.Ip,
            cliente.UserAgent);

        var access = tokens.CrearAccessToken(idUsuario, email, roles);
        return new AuthResponse(access.Token, access.ExpiresAt, refreshToken);
    }
}
