using System.ComponentModel.DataAnnotations;

namespace iet_bi_portal_backend.Modules.Correo.Models;

/// <summary>Profesor Regular CU12: correo a estudiantes de una sección (multipart/form-data). Cedulas vacío = todos los
/// estudiantes sin retiro. Adjuntos: de 0 a 10 archivos, 10 MB en total (RP-61).</summary>
public class EnvioCorreoSeccion
{
    [Required, StringLength(150, MinimumLength = 3, ErrorMessage = "El asunto debe tener entre 3 y 150 caracteres.")]
    [RegularExpression(@"^[^\r\n]*$", ErrorMessage = "El asunto no puede tener saltos de línea.")]
    public string Asunto { get; set; } = string.Empty;

    [Required, StringLength(5000, MinimumLength = 1, ErrorMessage = "El mensaje debe tener entre 1 y 5000 caracteres.")]
    public string Mensaje { get; set; } = string.Empty;

    public List<string>? Cedulas { get; set; }

    public List<IFormFile>? Adjuntos { get; set; }
}

/// <summary>Estudiante destinatario, con el profesor que envía (para responderle).</summary>
public record DestinatarioCorreo(string Cedula, string Nombre, string Email, string NombreProfesor, string EmailProfesor);

/// <summary>Estudiante en la respuesta del envío (sin su correo).</summary>
public record EstudianteCorreo(string Cedula, string Nombre);

/// <summary>Resultado del envío: a quiénes se envió y a quiénes no se pudo (el proveedor rechazó o no respondió).</summary>
public record EnvioCorreo(int Anio, string Seccion, string Asunto, List<EstudianteCorreo> Enviados, List<EstudianteCorreo> Fallidos);

/// <summary>Envio, o el código de error si no se envió (CO001, CO002, CO004, CO005).</summary>
public record ResultadoEnvioCorreo(EnvioCorreo? Envio, string? CodigoError);
