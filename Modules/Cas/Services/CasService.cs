using iet_bi_portal_backend.Common.Data;
using iet_bi_portal_backend.Common.Models;
using iet_bi_portal_backend.Modules.Cas.Data;
using iet_bi_portal_backend.Modules.Cas.Models;
using iet_bi_portal_backend.Modules.Logs;
using iet_bi_portal_backend.Modules.Logs.Services;

namespace iet_bi_portal_backend.Modules.Cas.Services;

public class CasService(CasRepository repo, ILogsService logs)
{
    private const string TablaInformes = "academico.informes_cas";

    /// <summary>Profesor CAS CU01 / CU02: registra (sin informe previo) o modifica el informe. Registra log solo si hubo cambios.</summary>
    public async Task GuardarInformeAsync(Guid actorId, int anio, string semestre, string cedula, GuardarInformeCasRequest request)
    {
        var (estado, anteriores) = await repo.GuardarInformeAsync(actorId, anio, semestre, cedula, request);
        if (estado != EstadoOperacion.Ok) return;

        var accion = anteriores is null ? AccionesLog.RegistrarInformeCas : AccionesLog.ModificarInformeCas;
        await logs.RegistrarAsync(actorId, accion, TablaInformes, IdInforme(anio, semestre, cedula),
            datosAnteriores: anteriores.ComoJson(), datosNuevos: request);
    }

    /// <summary>Profesor CAS CU04.</summary>
    public async Task EliminarInformeAsync(Guid actorId, int anio, string semestre, string cedula)
    {
        var anteriores = await repo.EliminarInformeAsync(actorId, anio, semestre, cedula);
        await logs.RegistrarAsync(actorId, AccionesLog.EliminarInformeCas, TablaInformes, IdInforme(anio, semestre, cedula),
            datosAnteriores: anteriores.ComoJson());
    }

    /// <summary>Profesor CAS CU03.</summary>
    public Task<InformeCas> ObtenerInformeAsync(Guid idUsuario, int anio, string semestre, string cedula) =>
        repo.ObtenerInformeAsync(idUsuario, anio, semestre, cedula);

    /// <summary>Profesor CAS CU03.</summary>
    public Task<List<ProgresoCas>> ProgresoSeccionAsync(Guid idUsuario, ConsultaProgresoSeccion consulta) =>
        repo.ProgresoSeccionAsync(idUsuario, consulta);

    /// <summary>Coordinador de CAS CU01 (RN-84).</summary>
    public Task<List<ProgresoCas>> ProgresoGeneralAsync(ConsultaProgresoGeneral consulta) => repo.ProgresoGeneralAsync(consulta);

    /// <summary>Coordinador de CAS CU02 (RN-84).</summary>
    public Task<List<InformeCas>> InformesEstudianteAsync(int anio, string semestre, string cedula) =>
        repo.InformesEstudianteAsync(anio, semestre, cedula);

    private static string IdInforme(int anio, string semestre, string cedula) =>
        $"{anio}/{Semestres.Normalizar(semestre)}/{cedula.Trim()}";
}
