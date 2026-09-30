CREATE_USER       // Alta de un usuario por un administrador (siempre nace con PROFESOR_REGULAR).
LOGIN             // Inicio de sesión exitoso.
LOGOUT_ALL        // Cierre de todas las sesiones del usuario autenticado.
CHANGE_PASSWORD   // Cambio de contraseña por el propio usuario. Nunca se loguea el hash ni la contraseña.
RESET_PASSWORD    // Reseteo de contraseña de otro usuario por un administrador. Nunca se loguea el hash ni la contraseña.
BOOTSTRAP_ADMIN   // Creación del primer administrador del sistema.
ASSIGN_ROLE       // Se le otorgó un rol a un usuario (queda el rol en newData).
REVOKE_ROLE       // Se le quitó un rol a un usuario (queda el rol en previousData).
UPDATE_USER_EMAIL // Un administrador modificó el email de un usuario (queda el email nuevo en newData).
ACTIVATE_USER     // Un administrador reactivó a un usuario previamente desactivado.
DEACTIVATE_USER   // Un administrador desactivó a un usuario.
DELETE_USER       // Un administrador eliminó físicamente a un usuario (queda email+roles en previousData, snapshot previo al borrado).
LOGOUT            // Cierre de la sesión actual. El actor se obtiene del refresh token; si el token no existía no se registra.
CREATE_PROFESSOR  // Alta de perfil de profesor por un administrador (queda usuario + datos en newData).
UPDATE_PROFESSOR  // Modificación de un profesor (previousData = snapshot previo, newData = datos nuevos).
DELETE_PROFESSOR  // Eliminación del perfil de profesor (previousData = snapshot previo).
CREATE_STUDENT    // Alta de estudiante por un administrador.
UPDATE_STUDENT    // Modificación de un estudiante (previousData/newData).
DELETE_STUDENT    // Eliminación de un estudiante (previousData = snapshot previo).