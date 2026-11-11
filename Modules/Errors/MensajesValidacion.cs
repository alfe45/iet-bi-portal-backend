using System.ComponentModel.DataAnnotations;
using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.ModelBinding.Metadata;

namespace iet_bi_portal_backend.Modules.Errors;

/// <summary>
/// RD-007: mensajes de validación automática (VAERR) en español. Los atributos que ya traen
/// ErrorMessage lo conservan; a los demás ([Required], [MaxLength], [StringLength]...) se les
/// asigna una plantilla en español con la etiqueta legible del campo ("La búsqueda", "nota").
/// También traduce los mensajes de binding de ASP.NET y los de JSON mal formado, que además
/// exponían nombres de tipos internos.
/// </summary>
public static partial class MensajesValidacion
{
    /// <summary>DV-001: [EmailAddress] trae su propio mensaje en inglés y la plantilla no lo reemplaza; se usa este.</summary>
    public const string CorreoInvalido = "El correo electrónico no tiene un formato válido.";

    /// <summary>Palabras que el nombre técnico del campo escribe sin tilde.</summary>
    private static readonly Dictionary<string, string> Palabras = new(StringComparer.OrdinalIgnoreCase)
    {
        ["anio"] = "año", ["busqueda"] = "búsqueda", ["cedula"] = "cédula", ["codigo"] = "código",
        ["contrasena"] = "contraseña", ["descripcion"] = "descripción", ["numero"] = "número",
        ["pagina"] = "página", ["tamano"] = "tamaño", ["electronico"] = "electrónico",
        ["guia"] = "guía", ["monografia"] = "monografía", ["justificacion"] = "justificación",
        ["observacion"] = "observación", ["observaciones"] = "observaciones", ["evaluacion"] = "evaluación",
        ["periodo"] = "periodo", ["telefono"] = "teléfono", ["titulo"] = "título", ["razon"] = "razón",
        ["request"] = "cuerpo de la solicitud", ["email"] = "correo",
    };

    /// <summary>Nombres compuestos cuya etiqueta no sale de unir las palabras.</summary>
    private static readonly Dictionary<string, string> Compuestos = new(StringComparer.OrdinalIgnoreCase)
    {
        ["FechaNacimiento"] = "fecha de nacimiento", ["NumeroCelular"] = "número de celular",
        ["TamanoPagina"] = "tamaño de página", ["FechaRegistro"] = "fecha de registro",
        ["CedulaEstudiante"] = "cédula del estudiante", ["CedulaProfesor"] = "cédula del profesor",
        ["CodigoAsignatura"] = "código de la asignatura", ["FechaInicio"] = "fecha de inicio", ["FechaFin"] = "fecha de fin",
    };

    /// <summary>Convierte el nombre técnico ("FechaNacimiento", "$.cedulaEstudiante") en etiqueta legible.</summary>
    public static string Etiqueta(string? nombre)
    {
        if (string.IsNullOrWhiteSpace(nombre)) return "cuerpo de la solicitud";
        var limpio = nombre.TrimStart('$', '.');
        var ultimo = limpio.Split('.', StringSplitOptions.RemoveEmptyEntries).LastOrDefault() ?? limpio;
        ultimo = IndiceRegex().Replace(ultimo, "");
        if (ultimo.Length == 0) return "cuerpo de la solicitud";
        if (Compuestos.TryGetValue(ultimo, out var compuesto)) return compuesto;
        var palabras = PalabraRegex().Matches(ultimo).Select(m => m.Value.ToLowerInvariant())
            .Select(p => Palabras.TryGetValue(p, out var t) ? t : p);
        var texto = string.Join(' ', palabras);
        return texto.Length == 0 ? ultimo : texto;
    }

    /// <summary>Plantilla en español para un atributo sin mensaje propio ({0} = etiqueta del campo).</summary>
    private static string? Plantilla(ValidationAttribute atributo, bool esTexto) => atributo switch
    {
        RequiredAttribute => "El campo '{0}' es obligatorio.",
        StringLengthAttribute { MinimumLength: > 0 } => "El campo '{0}' debe tener entre {2} y {1} caracteres.",
        StringLengthAttribute => "El campo '{0}' no puede superar {1} caracteres.",
        MaxLengthAttribute => esTexto ? "El campo '{0}' no puede superar {1} caracteres." : "El campo '{0}' no puede tener más de {1} elementos.",
        MinLengthAttribute => esTexto ? "El campo '{0}' debe tener al menos {1} caracteres." : "El campo '{0}' debe tener al menos {1} elementos.",
        RangeAttribute => "El campo '{0}' debe estar entre {1} y {2}.",
        EmailAddressAttribute => "El campo '{0}' no es un correo electrónico válido.",
        RegularExpressionAttribute => "El campo '{0}' no tiene un formato válido.",
        _ => "El campo '{0}' no es válido."
    };

    /// <summary>Registra las plantillas y los mensajes de binding en español.</summary>
    public static void Configurar(MvcOptions opciones)
    {
        opciones.ModelMetadataDetailsProviders.Add(new ProveedorMensajes());

        var m = opciones.ModelBindingMessageProvider;
        m.SetValueMustNotBeNullAccessor(campo => $"El campo '{Etiqueta(campo)}' es obligatorio.");
        m.SetMissingBindRequiredValueAccessor(campo => $"El campo '{Etiqueta(campo)}' es obligatorio.");
        m.SetMissingKeyOrValueAccessor(() => "Falta un valor obligatorio.");
        m.SetMissingRequestBodyRequiredValueAccessor(() => "El cuerpo de la solicitud es obligatorio.");
        m.SetAttemptedValueIsInvalidAccessor((valor, campo) => $"El valor de '{Etiqueta(campo)}' no es válido.");
        m.SetNonPropertyAttemptedValueIsInvalidAccessor(_ => "El valor indicado no es válido.");
        m.SetUnknownValueIsInvalidAccessor(campo => $"El valor de '{Etiqueta(campo)}' no es válido.");
        m.SetNonPropertyUnknownValueIsInvalidAccessor(() => "El valor indicado no es válido.");
        m.SetValueIsInvalidAccessor(_ => "El valor indicado no es válido.");
        m.SetValueMustBeANumberAccessor(campo => $"El campo '{Etiqueta(campo)}' debe ser un número.");
        m.SetNonPropertyValueMustBeANumberAccessor(() => "El valor debe ser un número.");
    }

    /// <summary>
    /// Texto de un error del ModelState. Los de JSON mal formado ("The JSON value could not be
    /// converted to System.Int32. Path: ...") se reemplazan: están en inglés y exponen tipos internos.
    /// </summary>
    public static string Texto(string clave, string? mensaje)
    {
        if (string.IsNullOrWhiteSpace(mensaje) || EsMensajeJson(mensaje))
            return clave.TrimStart('$', '.').Length == 0
                ? "El cuerpo de la solicitud no es un JSON válido."
                : $"El valor de '{Etiqueta(clave)}' no tiene un formato válido.";
        return mensaje;
    }

    public static bool EsMensajeJson(string? mensaje) =>
        mensaje is not null && (mensaje.Contains("LineNumber", StringComparison.Ordinal)
            || mensaje.StartsWith("The JSON", StringComparison.Ordinal)
            || mensaje.StartsWith("'", StringComparison.Ordinal) && mensaje.Contains("is an invalid", StringComparison.Ordinal));

    private sealed class ProveedorMensajes : IValidationMetadataProvider, IDisplayMetadataProvider
    {
        public void CreateValidationMetadata(ValidationMetadataProviderContext context)
        {
            foreach (var atributo in context.ValidationMetadata.ValidatorMetadata.OfType<ValidationAttribute>())
            {
                if (!string.IsNullOrEmpty(atributo.ErrorMessage) || atributo.ErrorMessageResourceType is not null) continue;
                atributo.ErrorMessage = Plantilla(atributo, context.Key.ModelType == typeof(string));
            }
        }

        public void CreateDisplayMetadata(DisplayMetadataProviderContext context)
        {
            // Etiqueta legible para {0} de las plantillas, salvo que el modelo declare [Display(Name)].
            if (context.DisplayMetadata.DisplayName is not null || context.Key.Name is null) return;
            var etiqueta = Etiqueta(context.Key.Name);
            context.DisplayMetadata.DisplayName = () => etiqueta;
        }
    }

    [GeneratedRegex(@"\[\d+\]")]
    private static partial Regex IndiceRegex();

    [GeneratedRegex(@"[A-ZÁÉÍÓÚÑ]?[a-záéíóúñ0-9]+|[A-Z]+(?![a-z])")]
    private static partial Regex PalabraRegex();
}
