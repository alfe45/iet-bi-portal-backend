using Npgsql;
using iet_bi_portal_backend.Common.Data;
using iet_bi_portal_backend.Common.Models;
using iet_bi_portal_backend.Modules.Estudiantes.Models;

namespace iet_bi_portal_backend.Modules.Estudiantes.Data;

/// <summary>Acceso a las funciones de administración de estudiantes (CU10 a CU13). Todo por cédula.</summary>
public class EstudiantesRepository(NpgsqlDataSource db)
{
    private const string Columnas =
        "nombre, primer_apellido, segundo_apellido, cedula, numero_celular, email, fecha_nacimiento, fecha_registro";

    /// <summary>Devuelve la cédula normalizada. Errores de la DB: AU009, ES001, ES002, ES004.</summary>
    public Task<string> RegistrarAsync(Guid actorId, RegistrarEstudianteRequest r) =>
        db.EscalarAsync<string>(
            "SELECT academico.fn_admin_registrar_estudiante(" +
            "$1, $2::text, $3::text, $4::text, $5::text, $6::text, $7::academico.citext, $8::date)",
            actorId, r.Nombre, r.PrimerApellido, r.SegundoApellido, r.Cedula, r.NumeroCelular, r.Email, r.FechaNacimiento);

    public async Task<ResultadoPaginado<EstudianteAdmin>> ListarAsync(ConsultaConBusqueda c)
    {
        var elementos = await db.ListarAsync(
            $"SELECT {Columnas} FROM academico.fn_admin_listar_estudiantes($1::text, $2, $3)",
            Leer, c.Busqueda, c.Pagina, c.TamanoPagina);
        var total = await db.EscalarAsync<long>("SELECT academico.fn_admin_contar_estudiantes($1::text)", c.Busqueda);
        return new ResultadoPaginado<EstudianteAdmin>(elementos, c.Pagina, c.TamanoPagina, total);
    }

    public Task<EstudianteAdmin?> ObtenerAsync(string cedula) =>
        db.PrimeroOpcionalAsync($"SELECT {Columnas} FROM academico.fn_admin_obtener_estudiante($1::text)", Leer, cedula);

    /// <summary>Devuelve OK/SIN_CAMBIOS y el snapshot previo en JSON (null si no hubo cambios).
    /// Errores: NF003, ES002, ES004.</summary>
    public Task<(string Estado, string? Anteriores)> ActualizarAsync(Guid actorId, string cedula, ActualizarEstudianteRequest r) =>
        db.PrimeroAsync<(string Estado, string? Anteriores)>(
            "SELECT out_status, out_datos_anteriores::text " +
            "FROM academico.fn_admin_actualizar_estudiante(" +
            "$1, $2::text, $3::text, $4::text, $5::text, $6::text, $7::academico.citext, $8::date)",
            x => (x.GetString(0), x.IsDBNull(1) ? null : x.GetString(1)),
            actorId, cedula, r.Nombre, r.PrimerApellido, r.SegundoApellido, r.NumeroCelular, r.Email, r.FechaNacimiento);

    /// <summary>Elimina el estudiante y devuelve el snapshot previo en JSON. Error: NF003.</summary>
    public Task<string> EliminarAsync(Guid actorId, string cedula) =>
        db.EscalarAsync<string>("SELECT academico.fn_admin_eliminar_estudiante($1, $2::text)", actorId, cedula);

    private static EstudianteAdmin Leer(NpgsqlDataReader r) => new(
        r.GetString(0),
        r.GetString(1),
        r.IsDBNull(2) ? null : r.GetString(2),
        r.GetString(3),
        r.IsDBNull(4) ? null : r.GetString(4),
        r.GetString(5),
        r.GetFieldValue<DateOnly>(6),
        r.GetDateTime(7));
}
