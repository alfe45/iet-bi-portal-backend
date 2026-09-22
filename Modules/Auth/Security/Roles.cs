namespace iet_bi_portal_backend.Modules.Auth.Security;

/// <summary> Clase con las constantes de los roles de usuario. </summary>
public static class Roles
{
    public const string Admin  = "ADMIN";
    public const string Profesor = "PROFESOR";
    public const string Guia = "GUIA";
    public const string CordinadorMonografia = "COORD_MONOGRAFIA";
    public const string CordinadorCAS = "COORD_CAS";
}

/// <summary> Clase con las constantes de los claims de usuario. </summary>
public static class AuthClaims
{
    public const string Role = "role";
}
