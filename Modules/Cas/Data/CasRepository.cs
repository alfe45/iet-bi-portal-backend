using System.Text.Json;
using Npgsql;
using iet_bi_portal_backend.Common.Data;
using iet_bi_portal_backend.Common.Models;
using iet_bi_portal_backend.Modules.Cas.Models;

namespace iet_bi_portal_backend.Modules.Cas.Data;

/// <summary>Acceso a las funciones de CAS (Profesor CAS CU01 a CU04, Coordinador de CAS CU01 y CU02). Un informe se
/// identifica por (año, semestre, cédula del estudiante); el profesor CAS solo opera los de su sección CAS (AD004).</summary>
public class CasRepository(NpgsqlDataSource db)
{
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);

    private const string ColumnasInforme =
        "anio, semestre::text, seccion, cedula_estudiante, nombre_estudiante, email_estudiante, cedula_profesor, nombre_profesor, " +
        "perfil, entrevista_1, entrevista_2, entrevista_final, observaciones, nota, nota_enviada, modificado_en, experiencias::text";

    private const string ColumnasProgreso =
        "anio, seccion, cedula_estudiante, nombre_estudiante, nombre_profesor, semestre::text, tiene_informe, experiencias, perfil, " +
        "entrevistas, nota, nota_enviada";

    /// <summary>Devuelve OK/SIN_CAMBIOS y el informe previo (null si es nuevo). Errores: NF004, NF003, NF009, AD004, EV002,
    /// EV003, EV004, CA001.</summary>
    public Task<(string Estado, string? Anteriores)> GuardarInformeAsync(Guid idUsuario, int anio, string semestre, string cedula, GuardarInformeCasRequest r) =>
        db.PrimeroAsync<(string Estado, string? Anteriores)>(
            "SELECT out_status, out_datos_anteriores::text FROM academico.fn_profesor_cas_guardar_informe(" +
            "$1, $2, $3::academico.numero_semestre, $4::text, $5, $6, $7, $8, $9::text, $10::jsonb)",
            x => (x.GetString(0), x.IsDBNull(1) ? null : x.GetString(1)),
            idUsuario, anio, Semestres.Normalizar(semestre), cedula, r.Perfil, r.Entrevista1, r.Entrevista2, r.EntrevistaFinal,
            r.Observaciones, JsonSerializer.Serialize(r.Experiencias, Json));

    /// <summary>Devuelve el snapshot previo. Errores: NF004, NF003, NF009, AD004, EV002, EV003, NF015.</summary>
    public Task<string> EliminarInformeAsync(Guid idUsuario, int anio, string semestre, string cedula) =>
        db.EscalarAsync<string>(
            "SELECT academico.fn_profesor_cas_eliminar_informe($1, $2, $3::academico.numero_semestre, $4::text)::text",
            idUsuario, anio, Semestres.Normalizar(semestre), cedula);

    /// <summary>Errores: NF004, NF003, NF009, AD004, NF015.</summary>
    public Task<InformeCas> ObtenerInformeAsync(Guid idUsuario, int anio, string semestre, string cedula) =>
        db.PrimeroAsync(
            $"SELECT {ColumnasInforme} FROM academico.fn_profesor_cas_obtener_informe($1, $2, $3::academico.numero_semestre, $4::text)",
            LeerInforme, idUsuario, anio, Semestres.Normalizar(semestre), cedula);

    /// <summary>Errores: NF006, NF007, AD004.</summary>
    public Task<List<ProgresoCas>> ProgresoSeccionAsync(Guid idUsuario, ConsultaProgresoSeccion c) =>
        db.ListarAsync(
            $"SELECT {ColumnasProgreso} FROM academico.fn_profesor_cas_progreso($1, $2::integer, $3::integer, $4::integer, $5::academico.numero_semestre)",
            LeerProgreso, idUsuario, c.Anio, c.Nivel, c.Numero, Semestres.Normalizar(c.Semestre));

    public Task<List<ProgresoCas>> ProgresoGeneralAsync(ConsultaProgresoGeneral c) =>
        db.ListarAsync(
            $"SELECT {ColumnasProgreso} FROM academico.fn_coordinador_cas_progreso($1::integer, $2::integer, $3::integer, $4::academico.numero_semestre)",
            LeerProgreso, c.Anio, c.Nivel, c.Numero, Semestres.Normalizar(c.Semestre));

    /// <summary>Errores: NF004, NF003, NF009, NF015.</summary>
    public Task<List<InformeCas>> InformesEstudianteAsync(int anio, string semestre, string cedula) =>
        db.ListarAsync(
            $"SELECT {ColumnasInforme} FROM academico.fn_coordinador_cas_informes($1, $2::academico.numero_semestre, $3::text)",
            LeerInforme, anio, Semestres.Normalizar(semestre), cedula);

    private static InformeCas LeerInforme(NpgsqlDataReader r) => new(
        r.GetInt32(0),
        r.GetString(1),
        r.GetString(2),
        r.GetString(3),
        r.GetString(4),
        r.GetString(5),
        r.GetString(6),
        r.GetString(7),
        r.GetBoolean(8),
        r.GetBoolean(9),
        r.GetBoolean(10),
        r.GetBoolean(11),
        r.IsDBNull(12) ? null : r.GetString(12),
        r.IsDBNull(13) ? null : r.GetString(13),
        r.GetBoolean(14),
        r.GetDateTime(15),
        JsonSerializer.Deserialize<List<ExperienciaCas>>(r.GetString(16), Json) ?? []);

    private static ProgresoCas LeerProgreso(NpgsqlDataReader r) => new(
        r.GetInt32(0),
        r.GetString(1),
        r.GetString(2),
        r.GetString(3),
        r.GetString(4),
        r.GetString(5),
        r.GetBoolean(6),
        r.GetInt32(7),
        r.GetBoolean(8),
        r.GetInt32(9),
        r.IsDBNull(10) ? null : r.GetString(10),
        r.GetBoolean(11));
}
