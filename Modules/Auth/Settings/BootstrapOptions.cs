namespace iet_bi_portal_backend.Modules.Auth.Settings;

// Token compartido requerido para llamar a POST /api/setup/primer-admin (creación del primer
// administrador). Es una capa adicional a la garantía de la base de datos, que solo permite
// crear un admin inicial una única vez, de forma segura ante condiciones de carrera.
public class BootstrapOptions
{
    public string Secret { get; set; } = string.Empty;
}
