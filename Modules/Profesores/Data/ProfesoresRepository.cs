using Npgsql;
using iet_bi_portal_backend.Common.Data;
using iet_bi_portal_backend.Common.Models;
using iet_bi_portal_backend.Modules.Profesores.Models;

namespace iet_bi_portal_backend.Modules.Profesores.Data;

/// <summary>Acceso a las funciones de administración de profesores (CU06 a CU09). Todo por cédula.</summary>
public class ProfesoresRepository(NpgsqlDataSource db)
{
    private const string Columnas =
        "nombre, primer_apellido, segundo_apellido, cedula, numero_celular, fecha_nacimiento, id_usuario, email, activo, roles::text[]";

    /// <summary>Devuelve la cédula normalizada. <paramref name="hash"/> es la contraseña de la cuenta nueva ya hasheada.
    /// Errores de la DB: AU009, PR002, PR005 y los de la cuenta (NF001, PR001, PR006, NU001, NU002, TA001).</summary>
    public Task<string> RegistrarAsync(Guid actorId, RegistrarProfesorRequest r, string? hash) =>
        db.EscalarAsync<string>(
            "SELECT academico.fn_admin_registrar_profesor($1, $2::text, $3::text, $4::text, $5::text, $6::text, $7::date, " +
            "$8::uuid, $9::text, $10::text, $11::text[])",
            actorId, r.Nombre, r.PrimerApellido, r.SegundoApellido, r.Cedula, r.NumeroCelular, r.FechaNacimiento,
            r.Cuenta?.IdUsuario, r.Cuenta?.Email, hash, r.Cuenta?.Roles?.ToArray());

    /// <summary>Crea o vincula la cuenta y devuelve el id del usuario. Errores: NF002, PR007, NF001, PR001, PR006, NU001, NU002, TA001.</summary>
    public Task<Guid> CrearCuentaAsync(Guid actorId, string cedula, CuentaProfesorRequest c, string? hash) =>
        db.EscalarAsync<Guid>(
            "SELECT academico.fn_admin_crear_cuenta_profesor($1, $2::text, $3::uuid, $4::text, $5::text, $6::text[])",
            actorId, cedula, c.IdUsuario, c.Email, hash, c.Roles?.ToArray());

    /// <summary>Quita (elimina) la cuenta y devuelve id, correo y roles previos. Errores: NF002, PR008, AU012, AU013, AU020.</summary>
    public Task<(Guid IdUsuario, string Email, string[] Roles)> QuitarCuentaAsync(Guid actorId, string cedula) =>
        db.PrimeroAsync<(Guid, string, string[])>(
            "SELECT out_id_usuario, out_email::text, out_roles::text[] FROM academico.fn_admin_quitar_cuenta_profesor($1, $2::text)",
            x => (x.GetGuid(0), x.GetString(1), x.GetFieldValue<string[]>(2)),
            actorId, cedula);

    public async Task<ResultadoPaginado<ProfesorAdmin>> ListarAsync(Guid actorId, ConsultaConBusqueda c)
    {
        var elementos = await db.ListarAsync(
            $"SELECT {Columnas} FROM academico.fn_admin_listar_profesores($1, $2::text, $3, $4)",
            Leer, actorId, c.Busqueda, c.Pagina, c.TamanoPagina);
        var total = await db.EscalarAsync<long>("SELECT academico.fn_admin_contar_profesores($1, $2::text)", actorId, c.Busqueda);
        return new ResultadoPaginado<ProfesorAdmin>(elementos, c.Pagina, c.TamanoPagina, total);
    }

    public Task<ProfesorAdmin?> ObtenerAsync(Guid actorId, string cedula) =>
        db.PrimeroOpcionalAsync($"SELECT {Columnas} FROM academico.fn_admin_obtener_profesor($1, $2::text)", Leer, actorId, cedula);

    /// <summary>Devuelve OK/SIN_CAMBIOS y el snapshot previo en JSON (null si no hubo cambios). Error: NF002.</summary>
    public Task<(string Estado, string? Anteriores)> ActualizarAsync(Guid actorId, string cedula, ActualizarProfesorRequest r) =>
        db.PrimeroAsync<(string Estado, string? Anteriores)>(
            "SELECT out_status, out_datos_anteriores::text " +
            "FROM academico.fn_admin_actualizar_profesor($1, $2::text, $3::text, $4::text, $5::text, $6::text, $7::date)",
            x => (x.GetString(0), x.IsDBNull(1) ? null : x.GetString(1)),
            actorId, cedula, r.Nombre, r.PrimerApellido, r.SegundoApellido, r.NumeroCelular, r.FechaNacimiento);

    /// <summary>Elimina el perfil y devuelve el snapshot previo en JSON. Error: NF002.</summary>
    public Task<string> EliminarAsync(Guid actorId, string cedula) =>
        db.EscalarAsync<string>("SELECT academico.fn_admin_eliminar_profesor($1, $2::text)", actorId, cedula);

    private static ProfesorAdmin Leer(NpgsqlDataReader r) => new(
        r.GetString(0),
        r.GetString(1),
        r.IsDBNull(2) ? null : r.GetString(2),
        r.GetString(3),
        r.IsDBNull(4) ? null : r.GetString(4),
        r.GetFieldValue<DateOnly>(5),
        r.IsDBNull(6) ? null : r.GetGuid(6),
        r.IsDBNull(7) ? null : r.GetString(7),
        r.IsDBNull(8) ? null : r.GetBoolean(8),
        r.GetFieldValue<string[]>(9));
}
