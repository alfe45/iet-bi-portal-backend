using Npgsql;
using iet_bi_portal_backend.Common.Data;
using iet_bi_portal_backend.Common.Models;
using iet_bi_portal_backend.Modules.Matriculas.Models;

namespace iet_bi_portal_backend.Modules.Matriculas.Data;

/// <summary>Acceso a las funciones de matrículas (CU22 a CU25, estudiantes de una sección y ficha del estudiante).
/// Una matrícula se identifica por (año, cédula del estudiante).</summary>
public class MatriculasRepository(NpgsqlDataSource db)
{
    private const string Columnas =
        "anio, nivel::int, numero::int, seccion, cedula_estudiante, nombre_estudiante, fecha_matricula, estado::text, fecha_retiro, motivo_retiro";

    /// <summary>Errores de la DB: AU009, NF003, NF006, ES003, MA001, MA002, MA004, MA005.</summary>
    public Task RegistrarAsync(Guid actorId, RegistrarMatriculaRequest r) =>
        db.EjecutarAsync(
            "SELECT academico.fn_admin_registrar_matricula($1, $2::integer, $3::integer, $4::integer, $5::text, $6::date)",
            actorId, r.Anio, r.Nivel, r.Numero, r.CedulaEstudiante, r.FechaMatricula);

    /// <summary>Sube la sección 10-N del año anterior a 11-N de r.Anio. Errores: AU009, NF004, NF006, MA002.</summary>
    public Task<SeccionSubida> SubirSeccionAsync(Guid actorId, SubirSeccionRequest r) =>
        db.PrimeroAsync(
            "SELECT seccion_creada, matriculados, omitidos FROM academico.fn_admin_subir_seccion($1, $2::integer, $3::integer, $4::date)",
            x => new SeccionSubida(x.GetBoolean(0), x.GetFieldValue<string[]>(1), x.GetFieldValue<string[]>(2)),
            actorId, r.Anio, r.Numero, r.FechaMatricula);

    public async Task<ResultadoPaginado<Matricula>> ListarAsync(Guid actorId, ConsultaMatriculas c)
    {
        var estado = c.Estado?.ToUpperInvariant();
        var elementos = await db.ListarAsync(
            $"SELECT {Columnas} FROM academico.fn_admin_listar_matriculas(" +
            "$1, $2::integer, $3::integer, $4::integer, $5::text, $6::academico.estado_matricula, $7::text, $8, $9)",
            Leer, actorId, c.Anio, c.Nivel, c.Numero, c.CedulaEstudiante, estado, c.Busqueda, c.Pagina, c.TamanoPagina);
        var total = await db.EscalarAsync<long>(
            "SELECT academico.fn_admin_contar_matriculas($1, $2::integer, $3::integer, $4::integer, $5::text, $6::academico.estado_matricula, $7::text)",
            actorId, c.Anio, c.Nivel, c.Numero, c.CedulaEstudiante, estado, c.Busqueda);
        return new ResultadoPaginado<Matricula>(elementos, c.Pagina, c.TamanoPagina, total);
    }

    public Task<Matricula?> ObtenerAsync(Guid actorId, int anio, string cedula) =>
        db.PrimeroOpcionalAsync($"SELECT {Columnas} FROM academico.fn_admin_obtener_matricula($1, $2, $3::text)", Leer, actorId, anio, cedula);

    /// <summary>Devuelve OK/SIN_CAMBIOS y el snapshot previo. Errores: NF003, NF004, NF006, NF009, MA006, MA008.</summary>
    public Task<(string Estado, string? Anteriores)> CambiarSeccionAsync(Guid actorId, int anio, string cedula, CambiarSeccionRequest r) =>
        db.PrimeroAsync<(string Estado, string? Anteriores)>(
            "SELECT out_status, out_datos_anteriores::text " +
            "FROM academico.fn_admin_cambiar_seccion_matricula($1, $2, $3::text, $4::integer, $5::integer)",
            LeerEstado, actorId, anio, cedula, r.Nivel, r.Numero);

    /// <summary>Devuelve OK/SIN_CAMBIOS y el snapshot previo. Errores: NF003, NF004, NF009, MA003, MA007, MA009.</summary>
    public Task<(string Estado, string? Anteriores)> RegistrarRetiroAsync(Guid actorId, int anio, string cedula, RegistrarRetiroRequest r) =>
        db.PrimeroAsync<(string Estado, string? Anteriores)>(
            "SELECT out_status, out_datos_anteriores::text " +
            "FROM academico.fn_admin_registrar_retiro_matricula($1, $2, $3::text, $4::date, $5::text)",
            LeerEstado, actorId, anio, cedula, r.FechaRetiro, r.Motivo);

    /// <summary>Devuelve OK/SIN_CAMBIOS (no tenía retiro) y el snapshot previo. Errores: NF003, NF004, NF009.</summary>
    public Task<(string Estado, string? Anteriores)> AnularRetiroAsync(Guid actorId, int anio, string cedula) =>
        db.PrimeroAsync<(string Estado, string? Anteriores)>(
            "SELECT out_status, out_datos_anteriores::text FROM academico.fn_admin_anular_retiro_matricula($1, $2, $3::text)",
            LeerEstado, actorId, anio, cedula);

    /// <summary>Elimina la matrícula y devuelve el snapshot previo. Errores: NF003, NF004, NF009, 23001.</summary>
    public Task<string> EliminarAsync(Guid actorId, int anio, string cedula) =>
        db.EscalarAsync<string>("SELECT academico.fn_admin_eliminar_matricula($1, $2, $3::text)::text", actorId, anio, cedula);

    /// <summary>Estudiantes de una sección para un profesor que imparte en ella o es su guía. Errores: NF006, AD003.</summary>
    public Task<List<Matricula>> ListarEstudiantesSeccionAsync(Guid idUsuario, int anio, int nivel, int numero) =>
        db.ListarAsync(
            $"SELECT {Columnas} FROM academico.fn_profesor_listar_estudiantes_seccion($1, $2, $3, $4)",
            Leer, idUsuario, anio, nivel, numero);

    /// <summary>Ficha de un estudiante de la sección (Profesor Regular CU05). Errores: NF006, AD003, NF009.</summary>
    public Task<FichaEstudiante> ObtenerEstudianteSeccionAsync(Guid idUsuario, int anio, int nivel, int numero, string cedula) =>
        db.PrimeroAsync(
            "SELECT cedula, nombre, primer_apellido, segundo_apellido, numero_celular, email::text, fecha_nacimiento, " +
            "anio, seccion, fecha_matricula, estado::text, fecha_retiro, motivo_retiro " +
            "FROM academico.fn_profesor_obtener_estudiante_seccion($1, $2, $3, $4, $5::text)",
            r => new FichaEstudiante(
                r.GetString(0), r.GetString(1), r.GetString(2),
                r.IsDBNull(3) ? null : r.GetString(3),
                r.IsDBNull(4) ? null : r.GetString(4),
                r.GetString(5),
                r.GetFieldValue<DateOnly>(6),
                r.GetInt32(7), r.GetString(8),
                r.GetFieldValue<DateOnly>(9), r.GetString(10),
                r.IsDBNull(11) ? null : r.GetFieldValue<DateOnly>(11),
                r.IsDBNull(12) ? null : r.GetString(12)),
            idUsuario, anio, nivel, numero, cedula);

    private static (string, string?) LeerEstado(NpgsqlDataReader x) => (x.GetString(0), x.IsDBNull(1) ? null : x.GetString(1));

    private static Matricula Leer(NpgsqlDataReader r) => new(
        r.GetInt32(0),
        r.GetInt32(1),
        r.GetInt32(2),
        r.GetString(3),
        r.GetString(4),
        r.GetString(5),
        r.GetFieldValue<DateOnly>(6),
        r.GetString(7),
        r.IsDBNull(8) ? null : r.GetFieldValue<DateOnly>(8),
        r.IsDBNull(9) ? null : r.GetString(9));
}
