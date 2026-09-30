# Reglas de negocio

Restricciones propias del dominio. Cada regla es atómica y verificable.

## Estudiantes
- RN-01: Un estudiante debe tener 16 años cumplidos y menos de 20 al inscribirse (error ES003).
- RN-02: Al modificar un estudiante, la edad solo se revalida si cambia la fecha de nacimiento.
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
- RN-14: Un usuario tiene uno o más roles y nunca puede quedarse sin ninguno (AU005).
- RN-15: Todo usuario creado por un administrador nace con PROFESOR_REGULAR.
- RN-16: No existe auto-registro; los usuarios los crea un administrador.
- RN-17: Solo un ADMIN activo puede ejecutar acciones administrativas (AU009).
- RN-18: Un administrador no puede desactivarse (AU010), eliminarse (AU012) ni quitarse el rol ADMIN (AU003).
- RN-19: Siempre debe existir al menos un ADMIN activo (AU004, AU011, AU013).

## Sesión
- RN-20: El primer administrador se crea una sola vez, con el token de inicialización (AU001).
- RN-21: Tras N intentos fallidos de login (configurable) la cuenta se bloquea M minutos (AU015).
- RN-22: Un usuario desactivado no puede iniciar sesión (AU014).
- RN-23: Cambiar contraseña, correo o roles, desactivar el usuario o hacer logout-all cierra todas sus sesiones.

## Auditoría
- RN-24: Toda operación que modifica datos registra una entrada en `api.logs`, sin contraseñas ni hashes.
