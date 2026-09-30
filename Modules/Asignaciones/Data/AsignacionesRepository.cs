using Npgsql;
using iet_bi_portal_backend.Common.Data;
using iet_bi_portal_backend.Common.Models;
using iet_bi_portal_backend.Modules.Asignaciones.Models;

namespace iet_bi_portal_backend.Modules.Asignaciones.Data;

/// <summary>Acceso a las funciones de asignaciones docentes (CU33 a CU36 y mis asignaciones).
/// Todo por claves naturales: (año, nivel, número, código de asignatura, cédula del profesor).</summary>
public class AsignacionesRepository(NpgsqlDataSource db)
{
    private const string Columnas =
        "anio, nivel::int, numero::int, seccion, codigo_asignatura, asignatura, cedula_profesor, nombre_profesor";

    /// <summary>Errores de la DB: AU009, NF002, NF006, NF007, AS005, AD001, AD002.</summary>
    public Task RegistrarAsync(Guid actorId, RegistrarAsignacionRequest r) =>
        db.EjecutarAsync(
            "SELECT academico.fn_admin_registrar_asignacion($1, $2::integer, $3::integer, $4::integer, $5::text, $6::text)",
            actorId, r.Anio, r.Nivel, r.Numero, r.CodigoAsignatura, r.CedulaProfesor);

    public async Task<ResultadoPaginado<Asignacion>> ListarAsync(ConsultaAsignaciones c)
    {
        var elementos = await db.ListarAsync(
            $"SELECT {Columnas} FROM academico.fn_admin_listar_asignaciones($1::integer, $2::integer, $3::integer, $4::text, $5::text, $6, $7)",
            Leer, c.Anio, c.Nivel, c.Numero, c.CodigoAsignatura, c.CedulaProfesor, c.Pagina, c.TamanoPagina);
        var total = await db.EscalarAsync<long>(
            "SELECT academico.fn_admin_contar_asignaciones($1::integer, $2::integer, $3::integer, $4::text, $5::text)",
            c.Anio, c.Nivel, c.Numero, c.CodigoAsignatura, c.CedulaProfesor);
        return new ResultadoPaginado<Asignacion>(elementos, c.Pagina, c.TamanoPagina, total);
    }

    /// <summary>Devuelve OK/SIN_CAMBIOS y el snapshot previo. Errores: NF002, NF006, NF007, NF008, AD001, AD002.</summary>
    public Task<(string Estado, string? Anteriores)> CambiarProfesorAsync(
        Guid actorId, int anio, int nivel, int numero, string codigo, string cedulaActual, string cedulaNueva) =>
        db.PrimeroAsync<(string Estado, string? Anteriores)>(
            "SELECT out_status, out_datos_anteriores::text " +
            "FROM academico.fn_admin_cambiar_profesor_asignacion($1, $2, $3, $4, $5::text, $6::text, $7::text)",
            x => (x.GetString(0), x.IsDBNull(1) ? null : x.GetString(1)),
            actorId, anio, nivel, numero, codigo, cedulaActual, cedulaNueva);

    /// <summary>Elimina la asignación y devuelve el snapshot previo en JSON. Errores: NF002, NF006, NF007, NF008, 23001.</summary>
    public Task<string> EliminarAsync(Guid actorId, int anio, int nivel, int numero, string codigo, string cedula) =>
        db.EscalarAsync<string>(
            "SELECT academico.fn_admin_eliminar_asignacion($1, $2, $3, $4, $5::text, $6::text)::text",
            actorId, anio, nivel, numero, codigo, cedula);

    /// <summary>Asignaciones del profesor autenticado en un año (null = periodo en curso; NF005 si no hay).</summary>
    public Task<List<Asignacion>> ListarMisAsignacionesAsync(Guid idUsuario, int? anio) =>
        db.ListarAsync(
            $"SELECT {Columnas} FROM academico.fn_profesor_listar_mis_asignaciones($1, $2::integer)",
            Leer, idUsuario, anio);

    private static Asignacion Leer(NpgsqlDataReader r) => new(
        r.GetInt32(0),
        r.GetInt32(1),
        r.GetInt32(2),
        r.GetString(3),
        r.GetString(4),
        r.GetString(5),
        r.GetString(6),
        r.GetString(7));
}
