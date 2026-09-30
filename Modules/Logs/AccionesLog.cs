namespace iet_bi_portal_backend.Modules.Logs;

/// <summary>Catálogo de acciones de auditoría (api.logs.accion). Descripción de cada una en log_codes.md.
/// Todo servicio que registra un log usa estas constantes, nunca strings sueltos.</summary>
public static class AccionesLog
{
    // Sesión
    public const string Login = "LOGIN";
    public const string LoginFallido = "LOGIN_FALLIDO";
    public const string Logout = "LOGOUT";
    public const string SesionReutilizada = "SESION_REUTILIZADA";
    public const string LogoutAll = "LOGOUT_ALL";
    public const string CambiarContrasena = "CAMBIAR_CONTRASENA";
    public const string CrearPrimerAdmin = "CREAR_PRIMER_ADMIN";

    // Usuarios
    public const string RegistrarUsuario = "REGISTRAR_USUARIO";
    public const string ModificarEmailUsuario = "MODIFICAR_EMAIL_USUARIO";
    public const string ResetearContrasena = "RESETEAR_CONTRASENA";
    public const string ActivarUsuario = "ACTIVAR_USUARIO";
    public const string DesactivarUsuario = "DESACTIVAR_USUARIO";
    public const string AsignarRol = "ASIGNAR_ROL";
    public const string RevocarRol = "REVOCAR_ROL";
    public const string EliminarUsuario = "ELIMINAR_USUARIO";

    // Profesores
    public const string RegistrarProfesor = "REGISTRAR_PROFESOR";
    public const string ModificarProfesor = "MODIFICAR_PROFESOR";
    public const string EliminarProfesor = "ELIMINAR_PROFESOR";

    // Estudiantes
    public const string RegistrarEstudiante = "REGISTRAR_ESTUDIANTE";
    public const string ModificarEstudiante = "MODIFICAR_ESTUDIANTE";
    public const string EliminarEstudiante = "ELIMINAR_ESTUDIANTE";

    // Periodos académicos
    public const string RegistrarPeriodo = "REGISTRAR_PERIODO";
    public const string ModificarPeriodo = "MODIFICAR_PERIODO";
    public const string EliminarPeriodo = "ELIMINAR_PERIODO";

    // Secciones
    public const string RegistrarSeccion = "REGISTRAR_SECCION";
    public const string EliminarSeccion = "ELIMINAR_SECCION";
    public const string AsignarGuia = "ASIGNAR_GUIA";
    public const string QuitarGuia = "QUITAR_GUIA";

    // Asignaturas
    public const string RegistrarAsignatura = "REGISTRAR_ASIGNATURA";
    public const string ModificarAsignatura = "MODIFICAR_ASIGNATURA";
    public const string EliminarAsignatura = "ELIMINAR_ASIGNATURA";

    // Asignaciones docentes
    public const string RegistrarAsignacion = "REGISTRAR_ASIGNACION";
    public const string CambiarProfesorAsignacion = "CAMBIAR_PROFESOR_ASIGNACION";
    public const string EliminarAsignacion = "ELIMINAR_ASIGNACION";

    // Matrículas
    public const string RegistrarMatricula = "REGISTRAR_MATRICULA";
    public const string CambiarSeccionMatricula = "CAMBIAR_SECCION_MATRICULA";
    public const string RegistrarRetiroMatricula = "REGISTRAR_RETIRO_MATRICULA";
    public const string AnularRetiroMatricula = "ANULAR_RETIRO_MATRICULA";
    public const string EliminarMatricula = "ELIMINAR_MATRICULA";
    public const string SubirSeccion = "SUBIR_SECCION";

    // Ausentismo
    public const string RegistrarLeccion = "REGISTRAR_LECCION";
    public const string ModificarLeccion = "MODIFICAR_LECCION";
    public const string EliminarLeccion = "ELIMINAR_LECCION";
    public const string JustificarAusencia = "JUSTIFICAR_AUSENCIA";
    public const string AnularJustificacionAusencia = "ANULAR_JUSTIFICACION_AUSENCIA";
}
