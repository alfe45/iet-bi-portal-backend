using iet_bi_portal_backend.Common.Data;
using iet_bi_portal_backend.Common.Models;
using iet_bi_portal_backend.Modules.Informes.Data;
using iet_bi_portal_backend.Modules.Informes.Models;
using iet_bi_portal_backend.Modules.Logs;
using iet_bi_portal_backend.Modules.Logs.Services;

namespace iet_bi_portal_backend.Modules.Informes.Services;

public class InformesService(InformesRepository repo, ILogsService logs)
{
    /// <summary>Guía CU09: un reporte por estudiante de la sección (RN-85).</summary>
    public Task<List<ReporteBandas>> ReportesSeccionAsync(Guid idUsuario, ConsultaReporteBandas consulta) =>
        ArmarAsync(idUsuario, consulta, null);

    /// <summary>Guía CU08: reporte de un estudiante (RN-85).</summary>
    public async Task<ReporteBandas> ReporteEstudianteAsync(Guid idUsuario, ConsultaReporteBandas consulta, string cedula) =>
        (await ArmarAsync(idUsuario, consulta, cedula)).Single();

    /// <summary>Guía: reactiva la edición de las notas de la sección en el semestre (RN-75). Registra log solo si había
    /// notas confirmadas.</summary>
    public async Task ReactivarBandasSeccionAsync(Guid actorId, ConsultaReporteBandas consulta)
    {
        var reactivadas = await repo.ReactivarBandasSeccionAsync(actorId, consulta);
        if (reactivadas is not null)
            await logs.RegistrarAsync(actorId, AccionesLog.ReactivarBandasSeccion, "academico.confirmaciones_notas",
                $"{consulta.Anio}/{consulta.Nivel}-{consulta.Numero}/{Semestres.Normalizar(consulta.Semestre)}",
                datosAnteriores: reactivadas.ComoJson());
    }

    private async Task<List<ReporteBandas>> ArmarAsync(Guid idUsuario, ConsultaReporteBandas c, string? cedula)
    {
        var filas = await repo.FilasAsync(idUsuario, c, cedula);
        var monografias = (await repo.MonografiasAsync(idUsuario, c, cedula)).ToDictionary(m => m.Cedula, m => m.Monografia);
        var semestre = Semestres.Normalizar(c.Semestre)!;
        var seccion = $"{c.Nivel}-{c.Numero}";

        return filas
            .GroupBy(f => (f.Cedula, f.Nombre))
            .Select(g => new ReporteBandas(c.Anio!.Value, semestre, c.Nivel!.Value, seccion, g.Key.Cedula, g.Key.Nombre,
                g.First().NombreGuia,
                g.Where(f => f.Banda is not null).Select(f => f.Banda!).ToList(),
                monografias.GetValueOrDefault(g.Key.Cedula)))
            .ToList();
    }
}
