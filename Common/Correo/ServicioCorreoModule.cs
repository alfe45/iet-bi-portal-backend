using iet_bi_portal_backend.Config;

namespace iet_bi_portal_backend.Common.Correo;

/// <summary>Registra IServicioCorreo con el proveedor de CORREO_PROVEEDOR (RP-61). Para cambiar de proveedor (Resend u
/// otro): crear una clase que implemente IServicioCorreo, agregar su caso aquí con sus variables y documentarlas en
/// .env.example. Falla al arrancar si falta una variable del proveedor elegido (RP-06).</summary>
public static class ServicioCorreoModule
{
    public static IServiceCollection AddServicioCorreo(this IServiceCollection services, IConfiguration config)
    {
        services.AddSingleton(new RemitenteCorreo(
            EnvConfig.Required(config, "CORREO_REMITENTE"),
            EnvConfig.Required(config, "CORREO_REMITENTE_NOMBRE")));

        var proveedor = EnvConfig.Required(config, "CORREO_PROVEEDOR").Trim().ToLowerInvariant();
        switch (proveedor)
        {
            case "brevo":
                var clave = EnvConfig.Required(config, "BREVO_API_KEY");
                services.AddHttpClient<BrevoCorreo>(c =>
                {
                    c.BaseAddress = new Uri("https://api.brevo.com/v3/");
                    c.DefaultRequestHeaders.Add("api-key", clave);
                    c.Timeout = TimeSpan.FromSeconds(20);
                });
                services.AddTransient<IServicioCorreo>(sp => sp.GetRequiredService<BrevoCorreo>());
                break;

            case "carpeta":
                var carpeta = Path.GetFullPath(EnvConfig.Required(config, "CORREO_CARPETA"));
                Directory.CreateDirectory(carpeta);
                services.AddSingleton<IServicioCorreo>(sp => new CarpetaCorreo(carpeta, sp.GetRequiredService<RemitenteCorreo>()));
                break;

            default:
                throw new InvalidOperationException(
                    $"La variable de entorno 'CORREO_PROVEEDOR' no es válida (valor actual: '{proveedor}'): usa brevo o carpeta.");
        }

        return services;
    }
}
