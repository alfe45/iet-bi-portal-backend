using Npgsql;
using iet_bi_portal_backend.Common.Data;
using iet_bi_portal_backend.Modules.Auth.Models;

namespace iet_bi_portal_backend.Modules.Auth.Data;

/// <summary>Acceso a las funciones auth.* (RP-32: solo llama funciones SQL).</summary>
public class AuthRepository(NpgsqlDataSource db)
{
    private const string ColumnasUsuario = "id_usuario, email, password_hash, activo, bloqueado_hasta, roles::text[]";

    /// <summary>Crea el primer administrador. La función serializa con advisory lock y lanza AU001 si ya existe.</summary>
    public Task<Guid> CrearPrimerAdminAsync(string email, string contrasenaHash) =>
        db.EscalarAsync<Guid>("SELECT auth.fn_crear_primer_admin($1::academico.citext, $2)", email, contrasenaHash);

    public Task<UsuarioAuth?> ObtenerPorEmailAsync(string email) =>
        db.PrimeroOpcionalAsync(
            $"SELECT {ColumnasUsuario} FROM auth.fn_obtener_usuario_por_email($1::academico.citext)", LeerUsuario, email);

    public Task<UsuarioAuth?> ObtenerPorIdAsync(Guid id) =>
        db.PrimeroOpcionalAsync($"SELECT {ColumnasUsuario} FROM auth.fn_obtener_usuario_por_id($1)", LeerUsuario, id);

    /// <summary>Suma un intento fallido. Devuelve true si este intento bloqueó la cuenta.</summary>
    public Task<bool> RegistrarLoginFallidoAsync(Guid idUsuario, int intentosMaximos, int minutosBloqueo) =>
        db.EscalarAsync<bool>("SELECT auth.fn_registrar_login_fallido($1, $2, $3)", idUsuario, intentosMaximos, minutosBloqueo);

    public Task RegistrarLoginExitosoAsync(Guid idUsuario) =>
        db.EjecutarAsync("CALL auth.sp_registrar_login_exitoso($1)", idUsuario);

    /// <summary>Establece una contraseña nueva ya hasheada y revoca todo el acceso del usuario.</summary>
    public Task EstablecerContrasenaAsync(Guid idUsuario, string contrasenaHash) =>
        db.EjecutarAsync("CALL auth.sp_establecer_contrasena($1, $2)", idUsuario, contrasenaHash);

    public Task CrearSesionAsync(Guid idUsuario, string tokenHash, DateTime expiraUtc, string? ip, string? userAgent) =>
        db.EjecutarAsync("CALL auth.sp_crear_sesion($1, $2, $3, $4::text, $5::text)",
            idUsuario, tokenHash, expiraUtc, ip, userAgent);

    /// <summary>Rota el refresh token: invalida el anterior y crea uno nuevo.</summary>
    public Task<ResultadoRefresh> RotarSesionAsync(
        string tokenHashAnterior, string tokenHashNuevo, DateTime expiraUtc, string? ip, string? userAgent) =>
        db.PrimeroAsync(
            "SELECT out_status, out_user_id, out_email, out_roles::text[] " +
            "FROM auth.fn_rotar_sesion($1, $2, $3, $4::text, $5::text)",
            r => new ResultadoRefresh(
                r.GetString(0),
                r.IsDBNull(1) ? null : r.GetGuid(1),
                r.IsDBNull(2)
                    ? null
                    : new UsuarioAutenticado(r.GetGuid(1), r.GetString(2), r.GetFieldValue<string[]>(3))),
            tokenHashAnterior, tokenHashNuevo, expiraUtc, ip, userAgent);

    /// <summary>Cierra la sesión del refresh token dado. Devuelve el dueño, o null si el token no existía.</summary>
    public Task<Guid?> LogoutAsync(string tokenHash) =>
        db.EscalarOpcionalAsync<Guid>("SELECT auth.fn_logout($1)", tokenHash);

    public Task LogoutAllAsync(Guid idUsuario) => db.EjecutarAsync("CALL auth.sp_logout_all($1)", idUsuario);

    public Task PurgarSesionesExpiradasAsync() => db.EjecutarAsync("CALL auth.sp_purgar_sesiones_expiradas()");

    /// <summary>Existe=false: el usuario fue eliminado (sus access tokens se rechazan). Desde: los tokens
    /// emitidos antes de esa fecha están revocados (logout-all, cambio de contraseña/roles, desactivación).</summary>
    public async Task<(bool Existe, DateTime? Desde)> ObtenerMarcaInvalidacionAsync(Guid idUsuario)
    {
        var filas = await db.ListarAsync<DateTime?>(
            "SELECT * FROM auth.fn_obtener_marca_invalidacion($1)",
            r => r.IsDBNull(0) ? null : r.GetDateTime(0),
            idUsuario);

        return filas.Count == 0 ? (false, null) : (true, filas[0]);
    }

    private static UsuarioAuth LeerUsuario(NpgsqlDataReader r) => new(
        r.GetGuid(0),
        r.GetString(1),
        r.GetString(2),
        r.GetBoolean(3),
        r.IsDBNull(4) ? null : r.GetDateTime(4),
        r.GetFieldValue<string[]>(5));
}
