using Npgsql;
using iet_bi_portal_backend.Common.Data;
using iet_bi_portal_backend.Common.Models;
using iet_bi_portal_backend.Modules.Periodos.Models;

namespace iet_bi_portal_backend.Modules.Periodos.Data;

/// <summary>Acceso a las funciones de periodos académicos (CU14 a CU17 y periodo actual). Todo por año.</summary>
public class PeriodosRepository(NpgsqlDataSource db)
{
    private const string Columnas =
        "anio, inicio_semestre_i, fin_semestre_i, inicio_semestre_ii, fin_semestre_ii, estado::text, semestre_actual::text";

    /// <summary>Devuelve el año registrado. Errores de la DB: AU009, PA001, PA002.</summary>
    public Task<int> RegistrarAsync(Guid actorId, RegistrarPeriodoRequest r) =>
        db.EscalarAsync<int>(
            "SELECT academico.fn_admin_registrar_periodo($1, $2::integer, $3::date, $4::date, $5::date, $6::date)",
            actorId, r.Anio, r.InicioSemestreI, r.FinSemestreI, r.InicioSemestreII, r.FinSemestreII);

    public async Task<ResultadoPaginado<PeriodoAcademico>> ListarAsync(Guid actorId, int pagina, int tamanoPagina)
    {
        var elementos = await db.ListarAsync(
            $"SELECT {Columnas} FROM academico.fn_admin_listar_periodos($1, $2, $3)", Leer, actorId, pagina, tamanoPagina);
        var total = await db.EscalarAsync<long>("SELECT academico.fn_admin_contar_periodos($1)", actorId);
        return new ResultadoPaginado<PeriodoAcademico>(elementos, pagina, tamanoPagina, total);
    }

    public Task<PeriodoAcademico?> ObtenerAsync(Guid actorId, int anio) =>
        db.PrimeroOpcionalAsync($"SELECT {Columnas} FROM academico.fn_admin_obtener_periodo($1, $2)", Leer, actorId, anio);

    /// <summary>Periodo que contiene la fecha de hoy, o null si no hay ninguno en curso.</summary>
    public Task<PeriodoAcademico?> ObtenerActualAsync() =>
        db.PrimeroOpcionalAsync($"SELECT {Columnas} FROM academico.fn_periodo_actual()", Leer);

    /// <summary>Devuelve OK/SIN_CAMBIOS y el snapshot previo en JSON. Errores: NF004, PA002, PA004, PA005, PA007, PA008, PA009.</summary>
    public Task<(string Estado, string? Anteriores)> ActualizarAsync(Guid actorId, int anio, ActualizarPeriodoRequest r) =>
        db.PrimeroAsync<(string Estado, string? Anteriores)>(
            "SELECT out_status, out_datos_anteriores::text " +
            "FROM academico.fn_admin_actualizar_periodo($1, $2, $3::date, $4::date, $5::date, $6::date)",
            x => (x.GetString(0), x.IsDBNull(1) ? null : x.GetString(1)),
            actorId, anio, r.InicioSemestreI, r.FinSemestreI, r.InicioSemestreII, r.FinSemestreII);

    /// <summary>Elimina el periodo y devuelve el snapshot previo en JSON. Errores: NF004, PA006.</summary>
    public Task<string> EliminarAsync(Guid actorId, int anio) =>
        db.EscalarAsync<string>("SELECT academico.fn_admin_eliminar_periodo($1, $2)::text", actorId, anio);

    private static PeriodoAcademico Leer(NpgsqlDataReader r) => new(
        r.GetInt32(0),
        r.GetFieldValue<DateOnly>(1),
        r.GetFieldValue<DateOnly>(2),
        r.GetFieldValue<DateOnly>(3),
        r.GetFieldValue<DateOnly>(4),
        r.GetString(5),
        r.IsDBNull(6) ? null : r.GetString(6));
}
