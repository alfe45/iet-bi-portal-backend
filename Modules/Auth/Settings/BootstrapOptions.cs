namespace iet_bi_portal_backend.Modules.Auth.Settings;

// Token compartido requerido para poder llamar al endpoint de inicialización
// del primer administrador (POST /api/setup/admin). Es una capa adicional a
// la protección que ya da la base de datos (solo permite crear un admin
// inicial una única vez, de forma segura ante condiciones de carrera).
public class BootstrapOptions
{
    public string Secret { get; set; } = string.Empty;
}
