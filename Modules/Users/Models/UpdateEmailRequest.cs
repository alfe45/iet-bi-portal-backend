using System.ComponentModel.DataAnnotations;

namespace iet_bi_portal_backend.Modules.Users.Models;

/// <summary>Datos para que un administrador modifique el email de otro usuario (CU04).</summary>
public class UpdateEmailRequest
{
    [Required, EmailAddress, MaxLength(254)]
    public string Email { get; set; } = string.Empty;
}