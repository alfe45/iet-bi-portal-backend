namespace iet_bi_portal_backend.Modules.Users.Models;

/// <summary>Registro de usuario tal como lo devuelve auth.fn_listar_usuarios_admin /
/// auth.fn_obtener_usuario_admin_por_id. Nunca incluye password_hash: el módulo Users no
/// necesita conocerlo para nada de lo que hace.</summary>
public record UserAdminRecord(
    Guid Id,
    string Email,
    bool Activo,
    DateTime? BloqueadoHasta,
    DateTime? UltimoLogin,
    DateTime CreadoEn,
    IReadOnlyList<string> Roles,
    long CantidadSesiones);

/// <summary>Forma de respuesta HTTP para el detalle/listado de usuarios (CU03).</summary>
public record UserAdminResponse(
    Guid Id,
    string Email,
    bool Activo,
    DateTime? BloqueadoHasta,
    DateTime? UltimoLogin,
    DateTime CreadoEn,
    IReadOnlyList<string> Roles,
    long CantidadSesiones);