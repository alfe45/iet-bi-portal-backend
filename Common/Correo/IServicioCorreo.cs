namespace iet_bi_portal_backend.Common.Correo;

/// <summary>Dirección de correo con el nombre visible.</summary>
public record DireccionCorreo(string Email, string Nombre);

/// <summary>Archivo adjunto: nombre visible, tipo MIME y contenido.</summary>
public record AdjuntoCorreo(string Nombre, string TipoContenido, byte[] Contenido);

/// <summary>Un correo en texto plano a un solo destinatario. ResponderA: a quién le llega la respuesta.</summary>
public record MensajeCorreo(DireccionCorreo Para, DireccionCorreo? ResponderA, string Asunto, string Texto, IReadOnlyList<AdjuntoCorreo> Adjuntos);

/// <summary>Remitente de todos los correos (CORREO_REMITENTE, CORREO_REMITENTE_NOMBRE).</summary>
public record RemitenteCorreo(string Email, string Nombre);

/// <summary>Envío de correo (RP-61). Cada proveedor es una implementación, elegida con CORREO_PROVEEDOR en
/// ServicioCorreoModule; el resto del código solo conoce esta interfaz. Lanza una excepción si el proveedor no
/// acepta el mensaje.</summary>
public interface IServicioCorreo
{
    Task EnviarAsync(MensajeCorreo mensaje, CancellationToken ct = default);
}
