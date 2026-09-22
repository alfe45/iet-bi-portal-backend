using iet_bi_portal_backend.Modules.Auth.Errors;

/// <summary>
/// Diccionario central: para cada código (propio o nativo de Postgres) define
/// el status HTTP y el mensaje seguro para el cliente. Un código que no está
/// acá nunca se expone tal cual — GlobalExceptionHandler responde 500 genérico.
/// </summary>
public sealed record ApiErrorInfo(int Status, string Mensaje);

public static class ApiErrorCatalog
{
    public static readonly IReadOnlyDictionary<string, ApiErrorInfo> Errors = new Dictionary<string, ApiErrorInfo>
    {
        [AuthErrorCodes.RoleForbidden] = new(StatusCodes.Status403Forbidden, "No tienes permisos para realizar esta acción."),
        [AuthErrorCodes.UserNotFound] = new(StatusCodes.Status404NotFound, "El usuario no existe."),
        [AuthErrorCodes.CannotRemoveLastRole] = new(StatusCodes.Status400BadRequest, "No se puede quitar el único rol que tiene el usuario."),
        [AuthErrorCodes.BootstrapAlreadyDone] = new(StatusCodes.Status409Conflict, "El administrador inicial ya fue creado."),
        [AuthErrorCodes.EmailTaken] = new(StatusCodes.Status409Conflict, "El correo ya está en uso."),
        [AuthErrorCodes.CannotRemoveProfessorRole] = new(StatusCodes.Status400BadRequest, "No se puede quitar el rol de PROFESOR."),

        // Errores nativos de Postgres que vale la pena traducir a algo legibles
        ["22P02"] = new(StatusCodes.Status400BadRequest, "Uno de los valores enviados no es válido."), // invalid_text_representation
        ["23505"] = new(StatusCodes.Status409Conflict, "Ya existe un registro con esos datos."),        // unique_violation
        ["23503"] = new(StatusCodes.Status409Conflict, "La operación hace referencia a un registro que no existe."), // foreign_key_violation
    };
}