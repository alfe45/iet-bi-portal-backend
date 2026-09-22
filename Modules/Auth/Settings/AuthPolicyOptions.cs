namespace iet_bi_portal_backend.Modules.Auth.Settings;

public class AuthPolicyOptions
{
    public int MaxFailedAttempts { get; set; } = 5;
    public int LockoutMinutes { get; set; } = 15;
}