using System.ComponentModel.DataAnnotations;

namespace iet_bi_portal_backend.Modules.Users.Models;

/// <summary>Datos para otorgar o revocar un rol a un usuario.</summary>
public class RoleRequest
{
    [Required, RegularExpression("^(ADMIN|PROFESOR_REGULAR|PROFESOR_CAS|GUIA|COORD_MONOGRAFIA|COORD_CAS)$",
        ErrorMessage = "Rol inválido. Valores permitidos: ADMIN, PROFESOR_REGULAR, PROFESOR_CAS, GUIA, COORD_MONOGRAFIA, COORD_CAS.")]
    public string Role { get; set; } = string.Empty;
}