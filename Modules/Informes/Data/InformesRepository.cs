using Npgsql;
using iet_bi_portal_backend.Common.Data;
using iet_bi_portal_backend.Common.Models;
using iet_bi_portal_backend.Modules.Informes.Models;

namespace iet_bi_portal_backend.Modules.Informes.Data;

/// <summary>Filas del reporte de bandas (Guía CU08 y CU09). cedula null = toda la sección.</summary>
public class InformesRepository(NpgsqlDataSource db)
{
    /// <summary>Una fila por estudiante y asignación (CodigoAsignatura null si la sección no tiene asignaciones).
    /// Errores: NF006, AD005, NF009.</summary>
    public Task<List<(string Cedula, string Nombre, BandaAsignatura? Banda)>> FilasAsync(Guid idUsuario, ConsultaReporteBandas c, string? cedula) =>
        db.ListarAsync(
            "SELECT cedula_estudiante, nombre_estudiante, codigo_asignatura, asignatura, tipo_asignatura::text, nombre_profesor, " +
            "nota_minima, nota, aprobada, tardias, injustificadas, justificadas, observaciones " +
            "FROM academico.fn_guia_reporte_bandas($1, $2::integer, $3::integer, $4::integer, $5::academico.numero_semestre, $6::text)",
            r => (r.GetString(0), r.GetString(1), r.IsDBNull(2) ? null : new BandaAsignatura(
                r.GetString(2), r.GetString(3), r.GetString(4), r.GetString(5), Texto(r, 6), Texto(r, 7),
                r.IsDBNull(8) ? null : r.GetBoolean(8), r.GetInt32(9), r.GetInt32(10), r.GetInt32(11), Texto(r, 12))),
            idUsuario, c.Anio, c.Nivel, c.Numero, Semestres.Normalizar(c.Semestre), cedula);

    /// <summary>Monografía de cada estudiante con monografía, con el reporte del semestre. Errores: NF006, AD005.</summary>
    public Task<List<(string Cedula, MonografiaReporte Monografia)>> MonografiasAsync(Guid idUsuario, ConsultaReporteBandas c, string? cedula) =>
        db.ListarAsync(
            "SELECT cedula_estudiante, codigo_asignatura, asignatura, nombre_coordinador, estado::text, observaciones " +
            "FROM academico.fn_guia_reportes_monografia($1, $2::integer, $3::integer, $4::integer, $5::academico.numero_semestre, $6::text)",
            r => (r.GetString(0), new MonografiaReporte(r.GetString(1), r.GetString(2), r.GetString(3), r.GetString(4), Texto(r, 5))),
            idUsuario, c.Anio, c.Nivel, c.Numero, Semestres.Normalizar(c.Semestre), cedula);

    private static string? Texto(NpgsqlDataReader r, int i) => r.IsDBNull(i) ? null : r.GetString(i);
}
