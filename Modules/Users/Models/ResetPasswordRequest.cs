using System.ComponentModel.DataAnnotations;

namespace iet_bi_portal_backend.Modules.Users.Models;

/// <summary>Datos para que un administrador resetee la contraseña de otro usuario (CU04).
/// A diferencia de ChangePasswordRequest (self-service), no requiere la contraseña actual:
/// la autoridad para esta acción es ser ADMIN, no conocer la contraseña vieja.</summary>
public class ResetPasswordRequest
{
    [Required, MinLength(8), MaxLength(128)]
    public string NewPassword { get; set; } = string.Empty;
}