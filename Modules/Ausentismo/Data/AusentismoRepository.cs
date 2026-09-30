using Npgsql;
using iet_bi_portal_backend.Common.Data;
using iet_bi_portal_backend.Common.Models;
using iet_bi_portal_backend.Modules.Ausentismo.Models;

namespace iet_bi_portal_backend.Modules.Ausentismo.Data;

/// <summary>Acceso a las funciones de ausentismo (Profesor Regular CU10 a CU12, Guía CU05). Las lecciones se
/// identifican por id (RP-53); el actor siempre es el profesor autenticado (AD004 si la lección o la asignación
/// no son suyas).</summary>
public class AusentismoRepository(NpgsqlDataSource db)
{
    private const string ColumnasLeccion =
        "id_leccion, anio, nivel::int, numero::int, seccion, codigo_asignatura, asignatura, fecha, hora, tema, semestre::text, ausentes, justificadas";

    private const string ColumnasResumen =
        "cedula_estudiante, nombre_estudiante, estado_matricula::text, codigo_asignatura, asignatura, nombre_profesor, " +
        "lecciones, ausencias, justificadas, injustificadas, porcentaje_ausentismo";

    /// <summary>Devuelve el id de la lección. Errores: NF006, NF007, AD004, LE001, LE002, LE003, PA004.</summary>
    public Task<long> RegistrarLeccionAsync(Guid idUsuario, RegistrarLeccionRequest r) =>
        db.EscalarAsync<long>(
            "SELECT academico.fn_profesor_registrar_leccion($1, $2::integer, $3::integer, $4::integer, $5::text, $6::date, $7::time, $8::text, $9::text[])",
            idUsuario, r.Anio, r.Nivel, r.Numero, r.CodigoAsignatura, r.Fecha, r.Hora, r.Tema, r.Ausentes.ToArray());

    /// <summary>Devuelve OK/SIN_CAMBIOS y el snapshot previo. Errores: NF010, AD004, LE001, LE002, LE003, PA004.</summary>
    public Task<(string Estado, string? Anteriores)> ModificarLeccionAsync(Guid idUsuario, long idLeccion, ModificarLeccionRequest r) =>
        db.PrimeroAsync<(string Estado, string? Anteriores)>(
            "SELECT out_status, out_datos_anteriores::text " +
            "FROM academico.fn_profesor_modificar_leccion($1, $2, $3::date, $4::time, $5::text, $6::text[])",
            LeerEstado, idUsuario, idLeccion, r.Fecha, r.Hora, r.Tema, r.Ausentes.ToArray());

    /// <summary>Elimina la lección con sus ausencias y devuelve el snapshot previo. Errores: NF010, AD004, PA004.</summary>
    public Task<string> EliminarLeccionAsync(Guid idUsuario, long idLeccion) =>
        db.EscalarAsync<string>("SELECT academico.fn_profesor_eliminar_leccion($1, $2)::text", idUsuario, idLeccion);

    /// <summary>Justifica (justificacion no nula) o anula la justificación (null). Devuelve OK/SIN_CAMBIOS y la
    /// ausencia previa. Errores: NF010, AD004, NF003, NF011, PA004.</summary>
    public Task<(string Estado, string? Anteriores)> JustificarAusenciaAsync(Guid idUsuario, long idLeccion, string cedula, string? justificacion) =>
        db.PrimeroAsync<(string Estado, string? Anteriores)>(
            "SELECT out_status, out_datos_anteriores::text FROM academico.fn_profesor_justificar_ausencia($1, $2, $3::text, $4::text)",
            LeerEstado, idUsuario, idLeccion, cedula, justificacion);

    /// <summary>Errores: NF006, NF007, AD004.</summary>
    public async Task<ResultadoPaginado<Leccion>> ListarLeccionesAsync(Guid idUsuario, ConsultaLecciones c)
    {
        var semestre = c.Semestre?.ToUpperInvariant();
        var elementos = await db.ListarAsync(
            $"SELECT {ColumnasLeccion} FROM academico.fn_profesor_listar_lecciones(" +
            "$1, $2::integer, $3::integer, $4::integer, $5::text, $6::academico.numero_semestre, $7, $8)",
            LeerLeccion, idUsuario, c.Anio, c.Nivel, c.Numero, c.CodigoAsignatura, semestre, c.Pagina, c.TamanoPagina);
        var total = await db.EscalarAsync<long>(
            "SELECT academico.fn_profesor_contar_lecciones($1, $2::integer, $3::integer, $4::integer, $5::text, $6::academico.numero_semestre)",
            idUsuario, c.Anio, c.Nivel, c.Numero, c.CodigoAsignatura, semestre);
        return new ResultadoPaginado<Leccion>(elementos, c.Pagina, c.TamanoPagina, total);
    }

    /// <summary>Errores: NF010, AD004.</summary>
    public async Task<LeccionConAusentes> ObtenerLeccionAsync(Guid idUsuario, long idLeccion)
    {
        var leccion = await db.PrimeroAsync(
            $"SELECT {ColumnasLeccion} FROM academico.fn_profesor_obtener_leccion($1, $2)", LeerLeccion, idUsuario, idLeccion);
        var ausentes = await db.ListarAsync(
            "SELECT cedula_estudiante, nombre_estudiante, justificada, justificacion FROM academico.fn_profesor_listar_ausencias_leccion($1, $2)",
            r => new Ausencia(r.GetString(0), r.GetString(1), r.GetBoolean(2), r.IsDBNull(3) ? null : r.GetString(3)),
            idUsuario, idLeccion);
        return new LeccionConAusentes(leccion, ausentes);
    }

    /// <summary>Resumen por estudiante de la asignación del profesor. Errores: NF006, NF007, AD004.</summary>
    public Task<List<ResumenAusentismo>> ResumenProfesorAsync(Guid idUsuario, ConsultaAusentismo c) =>
        db.ListarAsync(
            $"SELECT {ColumnasResumen} FROM academico.fn_profesor_resumen_ausentismo(" +
            "$1, $2::integer, $3::integer, $4::integer, $5::text, $6::academico.numero_semestre)",
            LeerResumen, idUsuario, c.Anio, c.Nivel, c.Numero, c.CodigoAsignatura, c.Semestre?.ToUpperInvariant());

    /// <summary>Resumen por estudiante y asignatura de la sección guía. Errores: NF006, AD005.</summary>
    public Task<List<ResumenAusentismo>> ResumenGuiaAsync(Guid idUsuario, ConsultaAusentismoGuia c) =>
        db.ListarAsync(
            $"SELECT {ColumnasResumen} FROM academico.fn_guia_resumen_ausentismo(" +
            "$1, $2::integer, $3::integer, $4::integer, $5::academico.numero_semestre)",
            LeerResumen, idUsuario, c.Anio, c.Nivel, c.Numero, c.Semestre?.ToUpperInvariant());

    private static (string, string?) LeerEstado(NpgsqlDataReader x) => (x.GetString(0), x.IsDBNull(1) ? null : x.GetString(1));

    private static Leccion LeerLeccion(NpgsqlDataReader r) => new(
        r.GetInt64(0),
        r.GetInt32(1),
        r.GetInt32(2),
        r.GetInt32(3),
        r.GetString(4),
        r.GetString(5),
        r.GetString(6),
        r.GetFieldValue<DateOnly>(7),
        r.GetFieldValue<TimeOnly>(8),
        r.IsDBNull(9) ? null : r.GetString(9),
        r.GetString(10),
        r.GetInt32(11),
        r.GetInt32(12));

    private static ResumenAusentismo LeerResumen(NpgsqlDataReader r) => new(
        r.GetString(0),
        r.GetString(1),
        r.GetString(2),
        r.GetString(3),
        r.GetString(4),
        r.GetString(5),
        r.GetInt32(6),
        r.GetInt32(7),
        r.GetInt32(8),
        r.GetInt32(9),
        r.IsDBNull(10) ? null : r.GetDecimal(10));
}
