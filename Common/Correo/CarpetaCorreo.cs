using System.Net.Mail;
using System.Text;

namespace iet_bi_portal_backend.Common.Correo;

/// <summary>No envía: guarda cada correo como archivo .eml en una carpeta (CORREO_CARPETA), con sus adjuntos. Para
/// desarrollo local y pruebas; el .eml se abre con cualquier cliente de correo.</summary>
public sealed class CarpetaCorreo(string carpeta, RemitenteCorreo remitente) : IServicioCorreo
{
    public async Task EnviarAsync(MensajeCorreo m, CancellationToken ct = default)
    {
        using var correo = new MailMessage(new MailAddress(remitente.Email, remitente.Nombre), new MailAddress(m.Para.Email, m.Para.Nombre))
        {
            Subject = m.Asunto,
            Body = m.Texto,
            IsBodyHtml = false,
            SubjectEncoding = Encoding.UTF8,
            BodyEncoding = Encoding.UTF8
        };
        if (m.ResponderA is not null)
            correo.ReplyToList.Add(new MailAddress(m.ResponderA.Email, m.ResponderA.Nombre));
        foreach (var a in m.Adjuntos)
            correo.Attachments.Add(new Attachment(new MemoryStream(a.Contenido), a.Nombre, a.TipoContenido));

        using var smtp = new SmtpClient
        {
            DeliveryMethod = SmtpDeliveryMethod.SpecifiedPickupDirectory,
            PickupDirectoryLocation = carpeta
        };
        await smtp.SendMailAsync(correo, ct);
    }
}
