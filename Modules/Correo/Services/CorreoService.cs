using System.Threading.RateLimiting;
using Microsoft.AspNetCore.StaticFiles;
using iet_bi_portal_backend.Common.Correo;
using iet_bi_portal_backend.Modules.Correo.Data;
using iet_bi_portal_backend.Modules.Correo.Models;
using iet_bi_portal_backend.Modules.Logs;
using iet_bi_portal_backend.Modules.Logs.Services;

namespace iet_bi_portal_backend.Modules.Correo.Services;

public class CorreoService(CorreoRepository repo, IServicioCorreo correo, LimiteEnviosCorreo limite, ILogsService logs,
    ILogger<CorreoService> logger)
{
    public const int MaxAdjuntos = 10;
    public const long MaxBytesAdjuntos = 10 * 1024 * 1024;

    /// <summary>Extensiones permitidas (RP-61): documentos, hojas de cálculo, presentaciones, imágenes y zip.</summary>
    private static readonly HashSet<string> Extensiones =
    [
        ".pdf", ".doc", ".docx", ".odt", ".rtf", ".txt",
        ".xls", ".xlsx", ".ods", ".csv",
        ".ppt", ".pptx", ".odp",
        ".jpg", ".jpeg", ".png", ".gif", ".webp", ".bmp",
        ".zip"
    ];

    private static readonly FileExtensionContentTypeProvider TiposMime = new();

    /// <summary>Profesor Regular CU12: envía el correo a cada estudiante por separado, con el profesor en "responder a"
    /// (RN-92). Errores de la DB: NF006, AD003, NF009, CO003. Se audita con los enviados y los fallidos (también si
    /// fallaron todos: CO004).</summary>
    public async Task<ResultadoEnvioCorreo> EnviarSeccionAsync(Guid actorId, int anio, int nivel, int numero, EnvioCorreoSeccion envio)
    {
        var archivos = envio.Adjuntos ?? [];
        if (archivos.Count > MaxAdjuntos || archivos.Sum(a => a.Length) > MaxBytesAdjuntos || archivos.Any(a => a.Length == 0))
            return new(null, "CO002");
        if (archivos.Any(a => !Extensiones.Contains(Path.GetExtension(a.FileName).ToLowerInvariant())))
            return new(null, "CO001");

        var destinatarios = await repo.DestinatariosAsync(actorId, anio, nivel, numero, envio.Cedulas);

        using var permiso = limite.Intentar(actorId);
        if (!permiso.IsAcquired)
            return new(null, "CO005");

        var adjuntos = new List<AdjuntoCorreo>();
        foreach (var archivo in archivos)
        {
            using var contenido = new MemoryStream();
            await archivo.CopyToAsync(contenido);
            var nombre = NombreSeguro(archivo.FileName);
            adjuntos.Add(new AdjuntoCorreo(nombre,
                TiposMime.TryGetContentType(nombre, out var tipo) ? tipo : "application/octet-stream", contenido.ToArray()));
        }

        var seccion = $"{nivel}-{numero}";
        var asunto = envio.Asunto.Trim();
        var profesor = new DireccionCorreo(destinatarios[0].EmailProfesor, destinatarios[0].NombreProfesor);
        var texto = $"{envio.Mensaje.Trim()}\n\n--\n{profesor.Nombre}\nSección {seccion} ({anio}), Instituto Dr. Clodomiro Picado Twight.\n" +
                    "Si respondes este correo, la respuesta le llega al profesor.";

        // Cada estudiante recibe su propio correo (no ven los correos de los demás). Hasta 5 envíos a la vez para no pasar
        // el timeout de la transacción de la petición (RP-58). Sin cancelación: lo enviado no se deshace y se audita.
        var enviado = new bool[destinatarios.Count];
        await Parallel.ForEachAsync(Enumerable.Range(0, destinatarios.Count), new ParallelOptions { MaxDegreeOfParallelism = 5 },
            async (i, ct) =>
            {
                var d = destinatarios[i];
                try
                {
                    await correo.EnviarAsync(new MensajeCorreo(new DireccionCorreo(d.Email, d.Nombre), profesor,
                        $"[IET-BI {seccion}] {asunto}", texto, adjuntos), ct);
                    enviado[i] = true;
                }
                catch (Exception ex)
                {
                    logger.LogWarning(ex, "No se pudo enviar el correo de la sección {Seccion} al estudiante {Cedula}", seccion, d.Cedula);
                }
            });

        var enviados = destinatarios.Where((_, i) => enviado[i]).Select(d => new EstudianteCorreo(d.Cedula, d.Nombre)).ToList();
        var fallidos = destinatarios.Where((_, i) => !enviado[i]).Select(d => new EstudianteCorreo(d.Cedula, d.Nombre)).ToList();

        await logs.RegistrarAsync(actorId, AccionesLog.EnviarCorreoSeccion, "academico.matriculas", $"{anio}/{seccion}",
            datosNuevos: new
            {
                asunto,
                adjuntos = adjuntos.Select(a => new { nombre = a.Nombre, bytes = a.Contenido.Length }),
                enviados = enviados.Select(e => e.Cedula),
                fallidos = fallidos.Select(e => e.Cedula)
            });

        return enviados.Count == 0
            ? new(null, "CO004")
            : new(new EnvioCorreo(anio, seccion, asunto, enviados, fallidos), null);
    }

    /// <summary>Solo el nombre del archivo (sin ruta), sin caracteres de control y con 150 caracteres como máximo
    /// conservando la extensión.</summary>
    private static string NombreSeguro(string nombreArchivo)
    {
        var nombre = new string(Path.GetFileName(nombreArchivo.Replace('\\', '/')).Where(c => !char.IsControl(c)).ToArray()).Trim();
        var extension = Path.GetExtension(nombre);
        if (nombre.Length > 150)
            nombre = nombre[..(150 - extension.Length)] + extension;
        return nombre.Length > extension.Length ? nombre : "adjunto" + extension;
    }
}

/// <summary>Máximo de envíos de correo por usuario (RP-61: 10 por hora, CO005). En memoria: se reinicia con la API.</summary>
public sealed class LimiteEnviosCorreo : IDisposable
{
    private readonly PartitionedRateLimiter<Guid> limitador = PartitionedRateLimiter.Create<Guid, Guid>(idUsuario =>
        RateLimitPartition.GetFixedWindowLimiter(idUsuario, _ => new FixedWindowRateLimiterOptions
        {
            PermitLimit = 10,
            Window = TimeSpan.FromHours(1),
            QueueLimit = 0
        }));

    public RateLimitLease Intentar(Guid idUsuario) => limitador.AttemptAcquire(idUsuario);

    public void Dispose() => limitador.Dispose();
}
