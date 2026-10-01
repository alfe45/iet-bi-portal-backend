using System.Text.Json;
using Npgsql;
using iet_bi_portal_backend.Common.Data;
using iet_bi_portal_backend.Common.Models;
using iet_bi_portal_backend.Modules.Evaluaciones.Models;

namespace iet_bi_portal_backend.Modules.Evaluaciones.Data;

/// <summary>Acceso a las funciones de evaluaciones (Profesor Regular CU01, CU06 a CU09 y CU14; Guía CU03/CU04;
/// prórrogas del ADMIN). El actor de las funciones de profesor es el profesor de la asignación (AD004).</summary>
public class EvaluacionesRepository(NpgsqlDataSource db)
{
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);

    private const string Asignacion = "$1, $2::integer, $3::integer, $4::integer, $5::text, $6::academico.numero_semestre";

    /// <summary>Devuelve OK/SIN_CAMBIOS y los valores previos de lo que cambió. Errores: NF006, NF007, AD004, EV001 a EV005.</summary>
    public Task<(string Estado, string? Anteriores)> RegistrarNotasAsync(Guid idUsuario, RegistrarNotasRequest r) =>
        db.PrimeroAsync<(string Estado, string? Anteriores)>(
            $"SELECT out_status, out_datos_anteriores::text FROM academico.fn_profesor_registrar_notas({Asignacion}, $7::jsonb)",
            x => (x.GetString(0), x.IsDBNull(1) ? null : x.GetString(1)),
            idUsuario, r.Anio, r.Nivel, r.Numero, r.CodigoAsignatura, Semestres.Normalizar(r.Semestre),
            JsonSerializer.Serialize(r.Notas, Json));

    /// <summary>Devuelve la nota previa y si se anuló el envío. Errores: NF006, NF007, AD004, NF004, NF003, NF009, NF016, EV002, EV003.</summary>
    public Task<string> EliminarNotaAsync(Guid idUsuario, ConsultaNotasAsignacion c, string cedula) =>
        db.EscalarAsync<string>(
            $"SELECT academico.fn_profesor_eliminar_nota({Asignacion}, $7::text)::text",
            idUsuario, c.Anio, c.Nivel, c.Numero, c.CodigoAsignatura, Semestres.Normalizar(c.Semestre), cedula);

    /// <summary>Errores: NF006, NF007, AD004.</summary>
    public async Task<NotasAsignacion> ListarNotasAsync(Guid idUsuario, ConsultaNotasAsignacion c)
    {
        object?[] args = [idUsuario, c.Anio, c.Nivel, c.Numero, c.CodigoAsignatura, Semestres.Normalizar(c.Semestre)];
        var estado = await db.PrimeroAsync(
            "SELECT anio, seccion, codigo_asignatura, asignatura, tipo_asignatura::text, semestre::text, fecha_cierre, enviado_en, " +
            $"estudiantes, sin_nota FROM academico.fn_profesor_estado_notas({Asignacion})",
            r => new EstadoNotas(r.GetInt32(0), r.GetString(1), r.GetString(2), r.GetString(3), r.GetString(4), r.GetString(5),
                r.GetFieldValue<DateOnly>(6), r.IsDBNull(7) ? null : r.GetDateTime(7), r.GetInt32(8), r.GetInt32(9)),
            args);
        var notas = await db.ListarAsync(
            "SELECT cedula_estudiante, nombre_estudiante, estado_matricula::text, nota, nota_minima, aprobada, observaciones " +
            $"FROM academico.fn_profesor_listar_notas({Asignacion})",
            r => new NotaEstudiante(r.GetString(0), r.GetString(1), r.GetString(2), Texto(r, 3), Texto(r, 4),
                r.IsDBNull(5) ? null : r.GetBoolean(5), Texto(r, 6)),
            args);
        return new NotasAsignacion(estado, notas);
    }

    /// <summary>Devuelve OK, o SIN_CAMBIOS si ya estaban enviadas. Errores: NF006, NF007, AD004, EV002, EV003, EV006.</summary>
    public Task<string> EnviarNotasAsync(Guid idUsuario, ConsultaNotasAsignacion c) =>
        db.EscalarAsync<string>(
            $"SELECT academico.fn_profesor_enviar_notas({Asignacion})",
            idUsuario, c.Anio, c.Nivel, c.Numero, c.CodigoAsignatura, Semestres.Normalizar(c.Semestre));

    public Task<List<AvisoNotas>> AvisosAsync(Guid idUsuario) =>
        db.ListarAsync(
            "SELECT anio, nivel::int, numero::int, seccion, codigo_asignatura, asignatura, semestre::text, fecha_cierre, " +
            "dias_para_cierre, estudiantes, sin_nota, enviada, aviso FROM academico.fn_profesor_avisos_notas($1)",
            r => new AvisoNotas(r.GetInt32(0), r.GetInt32(1), r.GetInt32(2), r.GetString(3), r.GetString(4), r.GetString(5),
                r.GetString(6), r.GetFieldValue<DateOnly>(7), r.GetInt32(8), r.GetInt32(9), r.GetInt32(10), r.GetBoolean(11),
                r.GetString(12)),
            idUsuario);

    /// <summary>Errores: NF006.</summary>
    public Task<List<NotaSeccion>> NotasSeccionAsync(ConsultaNotasSeccion c) =>
        db.ListarAsync(
            "SELECT cedula_estudiante, nombre_estudiante, estado_matricula::text, codigo_asignatura, asignatura, tipo_asignatura::text, " +
            "nombre_profesor, enviada, nota, nota_minima, aprobada, observaciones " +
            "FROM academico.fn_guia_notas_seccion($1::integer, $2::integer, $3::integer, $4::academico.numero_semestre)",
            r => new NotaSeccion(r.GetString(0), r.GetString(1), r.GetString(2), r.GetString(3), r.GetString(4), r.GetString(5),
                r.GetString(6), r.GetBoolean(7), Texto(r, 8), Texto(r, 9), r.IsDBNull(10) ? null : r.GetBoolean(10), Texto(r, 11)),
            c.Anio, c.Nivel, c.Numero, Semestres.Normalizar(c.Semestre));

    /// <summary>Devuelve OK/SIN_CAMBIOS y la prórroga previa. Errores: AU009, NF004, NF002, EV007.</summary>
    public Task<(string Estado, string? Anteriores)> OtorgarProrrogaAsync(Guid actorId, int anio, string semestre, string cedula, DateOnly? fechaLimite) =>
        db.PrimeroAsync<(string Estado, string? Anteriores)>(
            "SELECT out_status, out_datos_anteriores::text " +
            "FROM academico.fn_admin_otorgar_prorroga($1, $2, $3::academico.numero_semestre, $4::text, $5::date)",
            x => (x.GetString(0), x.IsDBNull(1) ? null : x.GetString(1)),
            actorId, anio, Semestres.Normalizar(semestre), cedula, fechaLimite);

    /// <summary>Devuelve el snapshot previo. Errores: AU009, NF002, NF012.</summary>
    public Task<string> QuitarProrrogaAsync(Guid actorId, int anio, string semestre, string cedula) =>
        db.EscalarAsync<string>(
            "SELECT academico.fn_admin_quitar_prorroga($1, $2, $3::academico.numero_semestre, $4::text)::text",
            actorId, anio, Semestres.Normalizar(semestre), cedula);

    public Task<List<Prorroga>> ListarProrrogasAsync(Guid actorId, ConsultaProrrogas c) =>
        db.ListarAsync(
            "SELECT anio, semestre::text, cedula_profesor, nombre_profesor, fin_semestre, fecha_limite " +
            "FROM academico.fn_admin_listar_prorrogas($1, $2::integer, $3::text)",
            r => new Prorroga(r.GetInt32(0), r.GetString(1), r.GetString(2), r.GetString(3),
                r.GetFieldValue<DateOnly>(4), r.GetFieldValue<DateOnly>(5)),
            actorId, c.Anio, c.CedulaProfesor);

    private static string? Texto(NpgsqlDataReader r, int i) => r.IsDBNull(i) ? null : r.GetString(i);
}
