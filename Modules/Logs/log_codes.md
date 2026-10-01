Catálogo de acciones de api.logs. En C# se usan las constantes de AccionesLog.cs.
Nunca se registra una contraseña ni un hash (RP-39).

# Sesión
LOGIN                   // Inicio de sesión exitoso.
LOGIN_FALLIDO           // Intento de login fallido. datos_nuevos = { email, motivo, cuentaBloqueada }. id_usuario = NULL si el correo no existe.
                        // motivo: CORREO_INEXISTENTE | CONTRASENA_INCORRECTA | CUENTA_DESACTIVADA | CUENTA_BLOQUEADA | SIN_ROLES.
                        // cuentaBloqueada = true si este intento bloqueó la cuenta (RN-21).
SESION_REUTILIZADA      // Se reutilizó un refresh token ya rotado (posible robo): se revocó todo el acceso del usuario (RP-19).
LOGOUT                  // Cierre de la sesión actual. El actor se obtiene del refresh token; si el token no existía no se registra.
LOGOUT_ALL              // Cierre de todas las sesiones del usuario autenticado.
CAMBIAR_CONTRASENA      // Cambio de contraseña por el propio usuario.
CREAR_PRIMER_ADMIN      // Creación del primer administrador del sistema (setup).

# Usuarios
REGISTRAR_USUARIO       // Alta de un usuario por un administrador (siempre nace con PROFESOR_REGULAR).
MODIFICAR_EMAIL_USUARIO // Un administrador modificó el email de un usuario (email nuevo en datos_nuevos).
RESETEAR_CONTRASENA     // Reseteo de contraseña de otro usuario por un administrador.
ACTIVAR_USUARIO         // Un administrador reactivó a un usuario previamente desactivado.
DESACTIVAR_USUARIO      // Un administrador desactivó a un usuario.
ASIGNAR_ROL             // Se le otorgó un rol a un usuario (rol en datos_nuevos).
REVOCAR_ROL             // Se le quitó un rol a un usuario (rol en datos_anteriores).
ELIMINAR_USUARIO        // Un administrador eliminó a un usuario (email + roles en datos_anteriores).

# Profesores
REGISTRAR_PROFESOR      // Alta de perfil de profesor (usuario + datos en datos_nuevos).
MODIFICAR_PROFESOR      // Modificación de un profesor (datos_anteriores = snapshot previo, datos_nuevos = datos nuevos).
ELIMINAR_PROFESOR       // Eliminación del perfil de profesor (datos_anteriores = snapshot previo).

# Estudiantes
REGISTRAR_ESTUDIANTE    // Alta de estudiante.
MODIFICAR_ESTUDIANTE    // Modificación de un estudiante (datos_anteriores / datos_nuevos).
ELIMINAR_ESTUDIANTE     // Eliminación de un estudiante (datos_anteriores = snapshot previo).

# Periodos académicos
REGISTRAR_PERIODO       // Alta de un periodo académico (año + fechas de los dos semestres en datos_nuevos).
MODIFICAR_PERIODO       // Modificación de las fechas de un periodo (datos_anteriores / datos_nuevos).
ELIMINAR_PERIODO        // Eliminación de un periodo sin secciones (datos_anteriores = snapshot previo).

# Secciones (id_registro_afectado = "año/nivel-número", ej. "2026/10-1")
REGISTRAR_SECCION       // Alta de una sección (año, nivel, número en datos_nuevos).
ELIMINAR_SECCION        // Eliminación de una sección (datos_anteriores = snapshot previo, incluye guía).
ASIGNAR_GUIA            // Se asoció o reemplazó el profesor guía (datos_anteriores = sección con guía previo, datos_nuevos = cédula nueva).
QUITAR_GUIA             // Se quitó el profesor guía (datos_anteriores = sección con el guía que tenía).

# Asignaturas (id_registro_afectado = código)
REGISTRAR_ASIGNATURA    // Alta de una asignatura (datos en datos_nuevos).
MODIFICAR_ASIGNATURA    // Modificación (datos_anteriores = snapshot previo, datos_nuevos = datos nuevos).
ELIMINAR_ASIGNATURA     // Eliminación (datos_anteriores = snapshot previo).

# Asignaciones docentes (id_registro_afectado = "año/nivel-número/código/cédula", ej. "2026/10-1/MAT/1-1111-1111")
REGISTRAR_ASIGNACION        // Se asignó a un profesor una asignatura en una sección (datos_nuevos = request).
CAMBIAR_PROFESOR_ASIGNACION // Se reemplazó al profesor (datos_anteriores = asignación previa; id con la cédula nueva).
ELIMINAR_ASIGNACION         // Eliminación (datos_anteriores = snapshot previo).

# Matrículas (id_registro_afectado = "año/cédula", ej. "2026/1-1111-1111")
REGISTRAR_MATRICULA         // Matrícula de un estudiante en una sección (datos_nuevos = request).
CAMBIAR_SECCION_MATRICULA   // Traslado a otra sección del mismo año (datos_anteriores = matrícula previa).
REGISTRAR_RETIRO_MATRICULA  // Registro o corrección del retiro (fecha y motivo en datos_nuevos).
ANULAR_RETIRO_MATRICULA     // Anulación del retiro (datos_anteriores = matrícula con el retiro).
ELIMINAR_MATRICULA          // Eliminación (datos_anteriores = snapshot previo).
SUBIR_SECCION               // Matrícula masiva en 11-N de los estudiantes de 10-N del año anterior (id = "año/11-N";
                            // datos_nuevos = { fechaMatricula, seccionCreada, matriculados: [cédulas] }). No se registra si no hubo cambios.

# Ausentismo (id_registro_afectado = id de la lección, ej. "15"; en justificaciones "15/cédula")
REGISTRAR_LECCION               // El profesor registró una lección con sus ausentes (datos_nuevos = request).
MODIFICAR_LECCION               // Corrección de fecha, hora, tema o ausentes (datos_anteriores = lección con ausentes). No se registra si no hubo cambios.
ELIMINAR_LECCION                // Eliminación de la lección y sus ausencias (datos_anteriores = snapshot previo).
JUSTIFICAR_AUSENCIA             // Se justificó o se cambió la justificación de una ausencia (datos_anteriores / datos_nuevos).
ANULAR_JUSTIFICACION_AUSENCIA   // La ausencia vuelve a quedar injustificada (datos_anteriores = justificación previa).

# Evaluaciones (id_registro_afectado = "año/nivel-número/código/semestre", ej. "2026/10-1/MAT/II_SEMESTRE";
# prórrogas = "año/semestre/cédula del profesor")
REGISTRAR_NOTAS     // Registro o corrección de notas y observaciones (datos_anteriores = [{cedulaEstudiante, nota, observaciones}]
                    // previos de lo que cambió, nota null si era nueva; datos_nuevos = notas enviadas). No se registra si no hubo cambios.
ELIMINAR_NOTA       // Corrección: se eliminó la nota de un estudiante (id = ".../cédula"; datos_anteriores = nota previa y
                    // envioAnulado: si anuló el envío de la asignación).
ENVIAR_NOTAS        // El profesor envió al guía las notas del semestre (solo la primera vez).
OTORGAR_PRORROGA    // El ADMIN otorgó o cambió una prórroga (datos_anteriores = prórroga previa, datos_nuevos = fechaLimite).
QUITAR_PRORROGA     // El ADMIN quitó la prórroga (datos_anteriores = prórroga previa).

# Monografías (id_registro_afectado = cédula del estudiante; seguimientos = id del seguimiento;
# reportes = "cédula/año/semestre")
REGISTRAR_MONOGRAFIA              // Asignación del estudiante a un coordinador y materia (datos_nuevos = request).
MODIFICAR_MONOGRAFIA              // Cambio de coordinador o materia (datos_anteriores = monografía previa).
ELIMINAR_MONOGRAFIA               // Eliminación (datos_anteriores = snapshot previo).
CAMBIAR_ESTADO_MONOGRAFIA         // El coordinador cambió el estado (datos_anteriores = monografía previa, datos_nuevos = estado).
REGISTRAR_SEGUIMIENTO_MONOGRAFIA  // Observación de seguimiento (datos_nuevos = request).
MODIFICAR_SEGUIMIENTO_MONOGRAFIA  // Corrección de fecha u observación (datos_anteriores = seguimiento previo).
ELIMINAR_SEGUIMIENTO_MONOGRAFIA   // Eliminación (datos_anteriores = seguimiento previo).
ENVIAR_REPORTE_MONOGRAFIA         // Reporte semestral al guía, o su corrección (datos_anteriores = observaciones previas).
ELIMINAR_REPORTE_MONOGRAFIA       // El coordinador retiró el reporte del semestre (datos_anteriores = reporte previo).

# CAS (id_registro_afectado = "año/semestre/cédula del estudiante")
REGISTRAR_INFORME_CAS   // Primer informe CAS del estudiante en el semestre (datos_nuevos = request).
MODIFICAR_INFORME_CAS   // Cambio del informe (datos_anteriores = informe previo con sus experiencias). No se registra si no hubo cambios.
ELIMINAR_INFORME_CAS    // Eliminación (datos_anteriores = informe previo).
