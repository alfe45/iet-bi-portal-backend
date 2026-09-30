# Reglas de negocio

Restricciones propias del dominio. Cada regla es atómica y verificable.

## Estudiantes
- RN-01: Al matricularse, el estudiante debe tener 16 años cumplidos y menos de 20 a la fecha de inicio del periodo de la matrícula (ES003). No se valida al registrar al estudiante, para poder digitalizar estudiantes de periodos pasados.
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
- RN-11: La cédula tiene de 5 a 20 caracteres, solo letras, dígitos y guion.

## Usuarios y roles
- RN-12: El correo del usuario es único, sin distinguir mayúsculas (TA001).
- RN-13: Roles válidos: ADMIN, PROFESOR_REGULAR, PROFESOR_CAS, GUIA, COORD_MONOGRAFIA, COORD_CAS.
- RN-14: Un usuario tiene uno o más roles y nunca puede quedarse sin ninguno (AU005). Los roles determinan qué módulos del front se activan.
- RN-15: Todo usuario creado por un administrador nace con PROFESOR_REGULAR. El primer administrador (setup) nace solo con ADMIN: un administrador puede ser independiente del rol de profesor.
- RN-16: No existe auto-registro; los usuarios los crea un administrador.
- RN-17: Solo un ADMIN activo puede ejecutar acciones administrativas (AU009).
- RN-18: Un administrador no puede desactivarse (AU010), eliminarse (AU012) ni quitarse el rol ADMIN (AU003).
- RN-19: Siempre debe existir al menos un ADMIN activo (AU004, AU011, AU013).

## Sesión
- RN-20: El primer administrador se crea una sola vez, con el token de inicialización (AU001).
- RN-21: Tras N intentos fallidos de login (configurable) la cuenta se bloquea M minutos (AU015).
- RN-22: Un usuario desactivado no puede iniciar sesión (AU014).
- RN-23: Cambiar contraseña, correo o roles, desactivar el usuario o hacer logout-all cierra todas sus sesiones.

## Periodos académicos
- RN-25: Un periodo académico corresponde a un año y tiene exactamente dos semestres (I y II); hay como máximo un periodo por año (PA001).
- RN-26: Las fechas cumplen inicio I < fin I < inicio II < fin II y caen dentro del año del periodo (PA002).
- RN-27: El año identifica al periodo y es inmutable; solo se modifican las fechas.
- RN-28: El estado se deriva de la fecha actual (hora de Costa Rica): PROGRAMADO antes del inicio del I semestre, EN_CURSO hasta el fin del II semestre, FINALIZADO después.
- RN-29: El periodo actual es el que contiene la fecha de hoy; el semestre actual es el que contiene la fecha de hoy, o ninguno durante el receso entre semestres.
- RN-30: Un semestre queda cerrado automáticamente al pasar su fecha de fin: sus fechas y los procesos de los profesores que dependen de él ya no se modifican (PA004).
- RN-31: El ADMIN puede registrar y corregir periodos pasados y sus datos, para digitalizar información en papel; un periodo finalizado no se puede reabrir (PA007).
- RN-32: La fecha de fin de un semestre no finalizado no puede quedar en el pasado (PA005).
- RN-33: Un periodo con secciones no se elimina (PA006).

## Secciones
- RN-35: El sistema solo maneja los niveles 10 y 11. Una sección se identifica por año, nivel y número (1 a 99), ej. 2026 "10-1"; no se repite en el periodo (SE001, SE002).
- RN-36: Una sección tiene como máximo un profesor guía, y un profesor es guía de una sola sección por periodo (SE004).
- RN-37: En periodos no finalizados el guía debe tener un usuario activo con el rol GUIA (SE003); en periodos finalizados (digitalización) no se exige.
- RN-38: No se elimina un profesor que es guía de una sección (PR004).
- RN-61: Un guía consulta las secciones de las que es guía (del periodo en curso por defecto). Cada sección informa su cantidad de estudiantes (matrículas no retiradas).
- RN-40: No se quita el rol GUIA a un profesor que es guía de una sección en un periodo no finalizado (AU016).

## Asignaturas
- RN-41: Una asignatura se identifica por un código de 2 a 10 letras o dígitos (en mayúsculas, inmutable) y tiene un nombre único sin distinguir mayúsculas (AS001, AS002, AS004).
- RN-42: Tipos de asignatura: TRONCAL, SUPERIOR, MEDIO, MEP.
- RN-43: Cada asignatura indica en qué niveles se imparte (10, 11 o ambos; al menos uno, AS003).
- RN-39: El nivel 11 no recibe Educación Cívica ni Estudios Sociales: se registran solo con nivel 10, y una asignatura no se asigna a una sección de un nivel donde no se imparte (AS005, se aplica en asignaciones).

## Asignaciones docentes
- RN-44: Una asignación es un profesor que imparte una asignatura en una sección; se identifica por año, nivel, número, código de asignatura y cédula del profesor.
- RN-45: Varios profesores pueden impartir la misma asignatura en la misma sección (co-docencia); el mismo profesor no se repite en la misma asignatura y sección (AD001).
- RN-46: La asignatura debe impartirse en el nivel de la sección (AS005, RN-39).
- RN-47: En periodos no finalizados el profesor debe tener un usuario activo con el rol PROFESOR_REGULAR (AD002); en periodos finalizados (digitalización) no se exige.
- RN-48: Modificar una asignación es reemplazar al profesor; la asignación (y lo que dependa de ella) se conserva.
- RN-49: No se quita el rol PROFESOR_REGULAR a un profesor con asignaciones en un periodo no finalizado (AU017).
- RN-50: No se elimina una sección, asignatura o profesor que tenga asignaciones (23001).
- RN-51: Un profesor consulta sus propias asignaciones (del periodo en curso por defecto) y su perfil incluye su cédula y nombre de profesor.

## Matrículas
- RN-53: Un estudiante tiene como máximo una matrícula por periodo (MA001); se identifica por año y cédula del estudiante.
- RN-54: Al matricularse, el estudiante tiene de 16 a 19 años a la fecha de inicio del periodo (ES003, RN-01).
- RN-55: La fecha de matrícula no puede ser futura, posterior al fin del periodo ni más de un año anterior a su inicio (MA002). Por defecto es hoy, o el inicio del periodo si ya finalizó (digitalización).
- RN-56: El estado de la matrícula no se guarda: es RETIRADA si tiene retiro; si no, PROGRAMADA / ACTIVA / FINALIZADA según el estado del periodo.
- RN-57: Modificar una matrícula es trasladarla a otra sección del mismo año, o registrar/anular su retiro. La fecha de retiro no puede ser futura, anterior a la matrícula ni posterior al fin del periodo (MA003).
- RN-58: No se exige haber cursado nivel 10 para matricular en 11 ni se impide repetir nivel: bloquearía traslados, repitentes y la digitalización fuera de orden.
- RN-59: Un profesor solo consulta los estudiantes de una sección si imparte en ella o es su guía (AD003).
- RN-60: No se elimina un estudiante o una sección con matrículas (23001).

## Auditoría
- RN-24: Toda operación que modifica datos registra una entrada en `api.logs`, sin contraseñas ni hashes.
- RN-52: La reutilización de un refresh token ya rotado revoca todo el acceso del usuario y se audita (SESION_REUTILIZADA).
- RN-34: Todo intento de login fallido se audita (`LOGIN_FALLIDO`) con el correo intentado, el motivo y si bloqueó la cuenta; al cliente se le sigue respondiendo genérico.
