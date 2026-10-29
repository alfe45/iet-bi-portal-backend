using System.Text.Json;
using System.Text.Json.Serialization;

namespace iet_bi_portal_backend.Common.Correo;

/// <summary>Brevo por su API HTTP (POST /v3/smtp/email). Se usa en producción porque Render free bloquea los puertos
/// SMTP. El HttpClient trae la dirección base, la clave (cabecera api-key) y el timeout desde ServicioCorreoModule.</summary>
public sealed class BrevoCorreo(HttpClient http, RemitenteCorreo remitente) : IServicioCorreo
{
    private static readonly JsonSerializerOptions Json = new() { DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull };

    public async Task EnviarAsync(MensajeCorreo m, CancellationToken ct = default)
    {
        var cuerpo = new
        {
            sender = new { email = remitente.Email, name = remitente.Nombre },
            to = new[] { new { email = m.Para.Email, name = m.Para.Nombre } },
            replyTo = m.ResponderA is null ? null : new { email = m.ResponderA.Email, name = m.ResponderA.Nombre },
            subject = m.Asunto,
            textContent = m.Texto,
            attachment = m.Adjuntos.Count == 0
                ? null
                : m.Adjuntos.Select(a => new { name = a.Nombre, content = Convert.ToBase64String(a.Contenido) }).ToArray()
        };

        using var respuesta = await http.PostAsJsonAsync("smtp/email", cuerpo, Json, ct);
        if (!respuesta.IsSuccessStatusCode)
            throw new HttpRequestException($"Brevo respondió {(int)respuesta.StatusCode}.", null, respuesta.StatusCode);
    }
}
