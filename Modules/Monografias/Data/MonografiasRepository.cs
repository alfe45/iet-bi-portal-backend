using Npgsql;
using iet_bi_portal_backend.Common.Data;
using iet_bi_portal_backend.Common.Models;
using iet_bi_portal_backend.Modules.Monografias.Models;

namespace iet_bi_portal_backend.Modules.Monografias.Data;

/// <summary>Acceso a las funciones de monografías (Administrador CU34 a CU37, Coordinador de Monografía CU01 a CU05, Guía
/// CU06 y CU07). Las monografías se operan por la cédula del estudiante; los seguimientos, por id.</summary>
public class MonografiasRepository(NpgsqlDataSource db)
{
    private const string ColumnasMonografia =
        "cedula_estudiante, nombre_estudiante, anio_inicio, anio_actual, seccion_actual, cedula_coordinador, nombre_coordinador, " +
        "codigo_asignatura, asignatura, estado::text, seguimientos, ultimo_seguimiento";

    private const string ColumnasSeguimiento = "id_seguimiento, cedula_estudiante, fecha, observacion";

    /// <summary>Errores: AU009, NF004, NF003, NF009, NF002, NF007, MO001 a MO005.</summary>
    public Task RegistrarAsync(Guid actorId, RegistrarMonografiaRequest r) =>
        db.EjecutarAsync("SELECT academico.fn_admin_registrar_monografia($1, $2::integer, $3::text, $4::text, $5::text)",
            actorId, r.Anio, r.CedulaEstudiante, r.CedulaCoordinador, r.CodigoAsignatura);

    public async Task<ResultadoPaginado<Monografia>> ListarAsync(Guid actorId, ConsultaMonografias c)
    {
        var estado = c.Estado?.ToUpperInvariant();
        var elementos = await db.ListarAsync(
            $"SELECT {ColumnasMonografia} FROM academico.fn_admin_listar_monografias(" +
            "$1, $2::integer, $3::text, $4::text, $5::academico.estado_monografia, $6, $7)",
            LeerMonografia, actorId, c.AnioInicio, c.CedulaCoordinador, c.CodigoAsignatura, estado, c.Pagina, c.TamanoPagina);
        var total = await db.EscalarAsync<long>(
            "SELECT academico.fn_admin_contar_monografias($1, $2::integer, $3::text, $4::text, $5::academico.estado_monografia)",
            actorId, c.AnioInicio, c.CedulaCoordinador, c.CodigoAsignatura, estado);
        return new ResultadoPaginado<Monografia>(elementos, c.Pagina, c.TamanoPagina, total);
    }

    /// <summary>Errores: NF003, NF013.</summary>
    public Task<Monografia> ObtenerAsync(Guid actorId, string cedula) =>
        db.PrimeroAsync($"SELECT {ColumnasMonografia} FROM academico.fn_admin_obtener_monografia($1, $2::text)", LeerMonografia, actorId, cedula);

    /// <summary>Devuelve OK/SIN_CAMBIOS y el snapshot previo. Errores: AU009, NF003, NF013, NF002, NF007, MO002, MO003, MO005.</summary>
    public Task<(string Estado, string? Anteriores)> ModificarAsync(Guid actorId, string cedula, ModificarMonografiaRequest r) =>
        db.PrimeroAsync<(string Estado, string? Anteriores)>(
            "SELECT out_status, out_datos_anteriores::text FROM academico.fn_admin_modificar_monografia($1, $2::text, $3::text, $4::text)",
            LeerEstado, actorId, cedula, r.CedulaCoordinador, r.CodigoAsignatura);

    /// <summary>Devuelve el snapshot previo. Errores: AU009, NF003, NF013, 23001 (tiene seguimiento o reportes).</summary>
    public Task<string> EliminarAsync(Guid actorId, string cedula) =>
        db.EscalarAsync<string>("SELECT academico.fn_admin_eliminar_monografia($1, $2::text)::text", actorId, cedula);

    public Task<List<Monografia>> ListarMiasAsync(Guid idUsuario, ConsultaMisMonografias c) =>
        db.ListarAsync(
            $"SELECT {ColumnasMonografia} FROM academico.fn_coordinador_listar_monografias($1, $2::integer, $3::academico.estado_monografia)",
            LeerMonografia, idUsuario, c.AnioInicio, c.Estado?.ToUpperInvariant());

    /// <summary>Errores: NF003, NF013, AD006.</summary>
    public async Task<DetalleMonografia> ObtenerMiaAsync(Guid idUsuario, string cedula)
    {
        var monografia = await db.PrimeroAsync(
            $"SELECT {ColumnasMonografia} FROM academico.fn_coordinador_obtener_monografia($1, $2::text)", LeerMonografia, idUsuario, cedula);
        var seguimientos = await db.ListarAsync(
            $"SELECT {ColumnasSeguimiento} FROM academico.fn_coordinador_listar_seguimientos($1, $2::text)", LeerSeguimiento, idUsuario, cedula);
        var reportes = await db.ListarAsync(
            "SELECT cedula_estudiante, anio, semestre::text, observaciones, enviado_en FROM academico.fn_coordinador_listar_reportes($1, $2::text)",
            r => new ReporteMonografia(r.GetString(0), r.GetInt32(1), r.GetString(2), r.GetString(3), r.GetDateTime(4)),
            idUsuario, cedula);
        return new DetalleMonografia(monografia, seguimientos, reportes);
    }

    /// <summary>Errores: NF003, NF013, AD006.</summary>
    public Task<(string Estado, string? Anteriores)> CambiarEstadoAsync(Guid idUsuario, string cedula, string estado) =>
        db.PrimeroAsync<(string Estado, string? Anteriores)>(
            "SELECT out_status, out_datos_anteriores::text " +
            "FROM academico.fn_coordinador_cambiar_estado_monografia($1, $2::text, $3::academico.estado_monografia)",
            LeerEstado, idUsuario, cedula, estado.ToUpperInvariant());

    /// <summary>Devuelve el id. Errores: NF003, NF013, AD006, MO006.</summary>
    public Task<long> RegistrarSeguimientoAsync(Guid idUsuario, string cedula, RegistrarSeguimientoRequest r) =>
        db.EscalarAsync<long>("SELECT academico.fn_coordinador_registrar_seguimiento($1, $2::text, $3::date, $4::text)",
            idUsuario, cedula, r.Fecha, r.Observacion);

    /// <summary>Errores: NF014, AD006, MO006.</summary>
    public Task<(string Estado, string? Anteriores)> ModificarSeguimientoAsync(Guid idUsuario, long idSeguimiento, ModificarSeguimientoRequest r) =>
        db.PrimeroAsync<(string Estado, string? Anteriores)>(
            "SELECT out_status, out_datos_anteriores::text FROM academico.fn_coordinador_modificar_seguimiento($1, $2, $3::date, $4::text)",
            LeerEstado, idUsuario, idSeguimiento, r.Fecha, r.Observacion);

    /// <summary>Devuelve el snapshot previo. Errores: NF014, AD006.</summary>
    public Task<string> EliminarSeguimientoAsync(Guid idUsuario, long idSeguimiento) =>
        db.EscalarAsync<string>("SELECT academico.fn_coordinador_eliminar_seguimiento($1, $2)::text", idUsuario, idSeguimiento);

    /// <summary>Errores: NF003, NF013, AD006, NF004, NF009, EV002, EV003.</summary>
    public Task<(string Estado, string? Anteriores)> EnviarReporteAsync(Guid idUsuario, string cedula, int anio, string semestre, string observaciones) =>
        db.PrimeroAsync<(string Estado, string? Anteriores)>(
            "SELECT out_status, out_datos_anteriores::text " +
            "FROM academico.fn_coordinador_enviar_reporte_monografia($1, $2::text, $3, $4::academico.numero_semestre, $5::text)",
            LeerEstado, idUsuario, cedula, anio, Semestres.Normalizar(semestre), observaciones);

    /// <summary>Devuelve el reporte previo. Errores: NF003, NF013, AD006, NF004, NF017, EV002, EV003.</summary>
    public Task<string> EliminarReporteAsync(Guid idUsuario, string cedula, int anio, string semestre) =>
        db.EscalarAsync<string>(
            "SELECT academico.fn_coordinador_eliminar_reporte_monografia($1, $2::text, $3, $4::academico.numero_semestre)::text",
            idUsuario, cedula, anio, Semestres.Normalizar(semestre));

    /// <summary>Guía CU07. Errores: NF006, AD005.</summary>
    public async Task<List<MonografiaConSeguimiento>> ListarSeccionGuiaAsync(Guid idUsuario, ConsultaSeccionGuia c)
    {
        var monografias = await db.ListarAsync(
            $"SELECT {ColumnasMonografia} FROM academico.fn_guia_listar_monografias($1, $2::integer, $3::integer, $4::integer)",
            LeerMonografia, idUsuario, c.Anio, c.Nivel, c.Numero);
        var seguimientos = await db.ListarAsync(
            $"SELECT {ColumnasSeguimiento} FROM academico.fn_guia_listar_seguimientos($1, $2::integer, $3::integer, $4::integer)",
            LeerSeguimiento, idUsuario, c.Anio, c.Nivel, c.Numero);
        return monografias
            .Select(m => new MonografiaConSeguimiento(m, seguimientos.Where(s => s.CedulaEstudiante == m.CedulaEstudiante).ToList()))
            .ToList();
    }

    /// <summary>Guía CU06. Errores: NF006, AD005.</summary>
    public Task<List<ReporteMonografiaSeccion>> ReportesSeccionGuiaAsync(Guid idUsuario, ConsultaReportesGuia c) =>
        db.ListarAsync(
            "SELECT cedula_estudiante, nombre_estudiante, codigo_asignatura, asignatura, nombre_coordinador, estado::text, observaciones, enviado_en " +
            "FROM academico.fn_guia_reportes_monografia($1, $2::integer, $3::integer, $4::integer, $5::academico.numero_semestre, NULL)",
            r => new ReporteMonografiaSeccion(r.GetString(0), r.GetString(1), r.GetString(2), r.GetString(3), r.GetString(4), r.GetString(5),
                r.IsDBNull(6) ? null : r.GetString(6), r.IsDBNull(7) ? null : r.GetDateTime(7)),
            idUsuario, c.Anio, c.Nivel, c.Numero, Semestres.Normalizar(c.Semestre));

    private static (string, string?) LeerEstado(NpgsqlDataReader x) => (x.GetString(0), x.IsDBNull(1) ? null : x.GetString(1));

    private static Monografia LeerMonografia(NpgsqlDataReader r) => new(
        r.GetString(0),
        r.GetString(1),
        r.GetInt32(2),
        r.GetInt32(3),
        r.GetString(4),
        r.GetString(5),
        r.GetString(6),
        r.GetString(7),
        r.GetString(8),
        r.GetString(9),
        r.GetInt32(10),
        r.IsDBNull(11) ? null : r.GetFieldValue<DateOnly>(11));

    private static Seguimiento LeerSeguimiento(NpgsqlDataReader r) =>
        new(r.GetInt64(0), r.GetString(1), r.GetFieldValue<DateOnly>(2), r.GetString(3));
}
