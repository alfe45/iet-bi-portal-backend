# Reglas generales (sistema de matrículas de un colegio)

Reglas genéricas o técnicas que tendría cualquier sistema de matrículas de un colegio. Las reglas propias del
Instituto y del programa BI están en `reglas_propias.md`; las de diseño del código, en `reglas_proyecto.md`.
La numeración RN-xx es común a los dos archivos de negocio (el código la cita) y no se reutiliza.
Entre paréntesis: el código de error que devuelve la API.

## Estudiantes
- RN-02: La fecha de nacimiento (de estudiantes y profesores) no puede ser futura ni anterior a 1900 (ES004, PR005).
- RN-03: La cédula del estudiante es única (ES001).
- RN-04: El correo del estudiante es único, sin distinguir mayúsculas (ES002).

## Profesores
- RN-05: Un profesor pertenece a exactamente un usuario; un usuario tiene como máximo un perfil de profesor (PR001).
- RN-06: La cédula del profesor es única (PR002).
- RN-07: Eliminar un profesor elimina solo el perfil; el usuario se conserva.
- RN-08: No se puede eliminar un usuario que tiene perfil de profesor (PR003).

## Cédula (profesores y estudiantes)
- RN-09: La cédula es el identificador de negocio; se usa en rutas y búsquedas en lugar del id interno.
- RN-10: La cédula es inmutable: no se modifica después del registro.
- RN-11: La cédula tiene de 5 a 20 caracteres, solo letras, dígitos y guion. Se guarda en mayúsculas y se busca sin distinguir mayúsculas: `est-0001` y `EST-0001` son la misma persona.

## Usuarios y roles
- RN-12: El correo del usuario es único, sin distinguir mayúsculas (TA001).
- RN-14: Un usuario tiene uno o más roles y nunca puede quedarse sin ninguno (AU005). Los roles determinan qué módulos del front se activan.
- RN-15: Todo usuario creado por un administrador nace con PROFESOR_REGULAR. El primer administrador (setup) nace solo con ADMIN: un administrador puede ser independiente del rol de profesor.
- RN-16: No existe auto-registro; los usuarios los crea un administrador.
- RN-17: Solo un ADMIN activo puede ejecutar acciones administrativas (AU009).
- RN-18: Un administrador no puede desactivarse (AU010), eliminarse (AU012) ni quitarse el rol ADMIN (AU003).
- RN-19: Siempre debe existir al menos un ADMIN activo (AU004, AU011, AU013).
- RN-89: No se desactiva a un usuario con responsabilidades vigentes: guía de una sección o asignaciones (CAS incluido) en un periodo no finalizado, o monografías sin terminar (AU020). Es la misma regla que impide quitarle el rol (AU016-AU019): primero se reasignan (decisión del 01/10/2026).

## Sesión
- RN-20: El primer administrador se crea una sola vez, con el token de inicialización (AU001).
- RN-21: Tras N intentos fallidos de login (configurable) la cuenta se bloquea M minutos (AU015). Mientras está bloqueada, el login responde AU015 sin evaluar la contraseña (si la evaluara, el bloqueo diría cuándo se acertó).
- RN-22: Un usuario desactivado no puede iniciar sesión (AU014, sin evaluar la contraseña).
- RN-23: Cambiar contraseña, correo o roles, desactivar el usuario o hacer logout-all cierra todas sus sesiones.

## Periodos académicos
- RN-26: Las fechas del periodo están en orden y dentro de su año (PA002). La estructura de semestres está en RN-25 (propia).
- RN-27: El año identifica al periodo y es inmutable; solo se modifican las fechas.
- RN-28: El estado se deriva de la fecha actual (hora de Costa Rica): PROGRAMADO antes del inicio, EN_CURSO hasta el fin, FINALIZADO después.
- RN-29: El periodo actual es el que contiene la fecha de hoy; el semestre actual es el que contiene la fecha de hoy, o ninguno durante el receso.
- RN-30: Un semestre queda cerrado automáticamente al pasar su fecha de fin: sus fechas y los procesos de los profesores que dependen de él ya no se modifican (PA004).
- RN-31: El ADMIN puede registrar y corregir periodos pasados y sus datos, para digitalizar información en papel; un periodo finalizado no se puede reabrir (PA007).
- RN-32: La fecha de fin de un semestre no finalizado no puede quedar en el pasado (PA005).
- RN-33: Un periodo con secciones no se elimina (PA006).
- RN-90: El inicio de un semestre que ya comenzó no puede pasar a una fecha futura (PA009): sus notas, lecciones e informes quedarían en un semestre "no iniciado".
- RN-87: Modificar las fechas de un periodo no puede dejar fuera registros ya hechos: lecciones fuera de un semestre, matrículas o retiros posteriores al fin del periodo, experiencias CAS fuera del periodo ni seguimientos de monografía anteriores a su inicio (PA008).

## Secciones
- RN-36: Una sección tiene como máximo un profesor guía, y un profesor es guía de una sola sección por periodo (SE004).
- RN-37: En periodos no finalizados el guía debe tener un usuario activo con el rol GUIA (SE003); en periodos finalizados (digitalización) no se exige.
- RN-38: No se elimina un profesor que es guía de una sección (PR004).
- RN-40: No se quita el rol GUIA a un profesor que es guía de una sección en un periodo no finalizado (AU016).
- RN-61: Un guía consulta las secciones de las que es guía (del periodo en curso por defecto). Cada sección informa su cantidad de estudiantes (matrículas no retiradas).

## Asignaturas
- RN-41: Una asignatura se identifica por un código de 2 a 10 letras o dígitos (en mayúsculas, inmutable) y tiene un nombre único sin distinguir mayúsculas (AS001, AS002, AS004).
- RN-43: Cada asignatura indica en qué niveles se imparte (al menos uno, AS003); una asignatura no se asigna a una sección de un nivel donde no se imparte (AS005), y no se le quita un nivel en el que ya está asignada (AS007).

## Asignaciones docentes
- RN-44: Una asignación es un profesor que imparte una asignatura en una sección; se identifica por año, nivel, número, código de asignatura y cédula del profesor.
- RN-45: Varios profesores pueden impartir la misma asignatura en la misma sección (co-docencia); el mismo profesor no se repite en la misma asignatura y sección (AD001).
- RN-46: La asignatura debe impartirse en el nivel de la sección (AS005).
- RN-47: En periodos no finalizados el profesor debe tener un usuario activo con el rol PROFESOR_REGULAR (AD002); en periodos finalizados (digitalización) no se exige.
- RN-48: Modificar una asignación es reemplazar al profesor; la asignación (y lo que dependa de ella) se conserva.
- RN-49: No se quita el rol PROFESOR_REGULAR a un profesor con asignaciones en un periodo no finalizado (AU017).
- RN-50: No se elimina una sección, asignatura o profesor que tenga asignaciones (23001).
- RN-51: Un profesor consulta sus propias asignaciones (del periodo en curso por defecto) y su perfil incluye su cédula y nombre de profesor.

## Matrículas
- RN-53: Un estudiante tiene como máximo una matrícula por periodo (MA001); se identifica por año y cédula del estudiante.
- RN-55: La fecha de matrícula no puede ser futura, posterior al fin del periodo ni más de un año anterior a su inicio (MA002). Por defecto es hoy, o el inicio del periodo si ya finalizó (digitalización).
- RN-56: El estado de la matrícula no se guarda: es RETIRADA si tiene retiro; si no, PROGRAMADA / ACTIVA / FINALIZADA según el estado del periodo.
- RN-57: Modificar una matrícula es trasladarla a otra sección del mismo año (con las limitaciones de RN-58) o registrar/anular su retiro. La fecha de retiro no puede ser futura, anterior a la matrícula ni posterior al fin del periodo (MA003), ni dejar fuera registros ya hechos: debe ser posterior a su última ausencia o tardía y al fin de los semestres en que ya tiene nota o informe CAS (MA009).
- RN-59: Un profesor solo consulta los estudiantes de una sección si imparte en ella o es su guía (AD003).
- RN-60: No se elimina un estudiante o una sección con matrículas (23001).
- RN-65: Con el mismo acceso de RN-59, el profesor consulta la ficha de un estudiante de la sección: sus datos personales y su matrícula, incluido el motivo de retiro, que puede ver cualquier profesor con acceso a la sección (NF009 si no está matriculado en ella, exista o no la cédula: el profesor no puede averiguar si una cédula existe fuera de sus secciones).

## Auditoría y seguridad
- RN-24: Toda operación que modifica datos registra una entrada en `api.logs`, sin contraseñas ni hashes. La operación y su auditoría se confirman juntas (si falla una, no queda ninguna). La entrada guarda el id y el correo del actor y los conserva aunque el usuario se elimine.
- RN-34: Todo intento de login fallido se audita (`LOGIN_FALLIDO`) con el correo intentado, el motivo y si bloqueó la cuenta; al cliente se le sigue respondiendo genérico.
- RN-52: La reutilización de un refresh token ya rotado revoca todo el acceso del usuario y se audita (SESION_REUTILIZADA). Excepción: dentro de los 10 s siguientes a la rotación se responde AU007 sin revocar (dos pestañas del mismo navegador que refrescan a la vez); el reuso no obtiene sesión en ningún caso.
