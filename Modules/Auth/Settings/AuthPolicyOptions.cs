namespace iet_bi_portal_backend.Modules.Auth.Settings;

/// <summary>Política de login: intentos fallidos y bloqueo de cuenta (RN-21).</summary>
public class AuthPolicyOptions
{
    public int MaxIntentosFallidos { get; set; } = 5;
    public int MinutosBloqueo { get; set; } = 15;
}
