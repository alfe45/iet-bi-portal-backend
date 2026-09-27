
using System.ComponentModel.DataAnnotations;

namespace iet_bi_portal_backend.Modules.Users.Models;

/// <summary> Datos para registrar un nuevo usuario. </summary>
public class RegisterRequest
{
    [Required, EmailAddress, MaxLength(254)]
    public string Email { get; set; } = string.Empty;

    [Required, MinLength(8), MaxLength(128)]
    public string Password { get; set; } = string.Empty;
}