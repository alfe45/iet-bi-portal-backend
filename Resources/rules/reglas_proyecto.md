# Reglas del proyecto

Reglas de diseño que se aplican siempre al escribir código. Cada regla es atómica.

## Idioma y nombres
- RP-01: Todo nombre (carpetas, clases, métodos, rutas, DTOs, tablas, funciones SQL) va en español.
- RP-02: Se mantienen en inglés solo términos técnicos: login, logout, logout-all, token, refresh, email, errors, logs, auth, setup, admin, common, config, modules, security, roles y los sufijos Async, Service, Repository, Controller, Module.
- RP-03: Términos del negocio siempre en español: Usuarios, Profesores, Estudiantes, cédula.
- RP-04: Funciones SQL: `fn_` devuelve valor, `sp_` es procedimiento; las de administración llevan prefijo `fn_admin_` / `sp_admin_`.

## Configuración
- RP-05: Toda configuración sale del `.env`, en variables planas (sin nesting tipo `Jwt__Key`).
- RP-06: Se lee con `EnvConfig.Required` / `RequiredInt` y falla al arrancar si falta algo.

## Identificadores
- RP-07: Profesores y estudiantes se buscan y operan por cédula; su id interno nunca se expone en la API.
- RP-08: Los usuarios se identifican por id (UUID).
- RP-53: Las lecciones se identifican por id (idLeccion): no tienen una clave natural estable, porque su fecha y hora se pueden corregir.

## Roles y autorización
- RP-09: Un usuario tiene varios roles mediante la tabla `api.usuario_roles`.
- RP-10: PROFESOR_REGULAR es el rol base; los demás se suman.
- RP-11: El JWT lleva un claim `role` por cada rol; se usa `[Authorize(Roles = "A,B")]` (OR).
- RP-12: Toda función SQL de administración empieza con `api.fn_validar_admin_activo`.

## Errores
- RP-13: Las funciones SQL lanzan errores con `api.fn_lanzar_excepcion(codigo, mensaje)`; nunca texto plano.
- RP-14: Un solo diccionario `error_codes.json` mapea código a (status HTTP, mensaje seguro).
- RP-15: Un solo `GlobalExceptionHandler` arma la respuesta `{ codigo, mensaje }`.
- RP-16: Nunca se envía al cliente `pg.Detail`, `pg.MessageText` ni `ex.Message`.
- RP-17: No se identifica una causa parseando el texto de un mensaje.
- RP-18: Todo código lanzado desde SQL debe existir en `error_codes.json`.

## Sesiones y tokens
- RP-19: Los refresh tokens se guardan hasheados y rotan; reusar uno rotado revoca todo el acceso del usuario.
- RP-20: El access token (JWT) es stateless y se valida contra `tokens_invalidados_desde` en cada request, con resolución de segundos (`iat` < marca truncada al segundo).
- RP-21: Toda revocación de acceso usa `api.sp_revocar_acceso`.
- RP-22: Toda actualización de contraseña usa `auth.sp_establecer_contrasena`.

## Contraseñas
- RP-23: Hash lento (PBKDF2, cientos de miles de iteraciones) con comparación en tiempo constante.
- RP-24: El login hace una verificación dummy cuando el correo no existe.

## SQL
- RP-25: Orden de scripts: 01 roles/esquemas, 02 helpers, 03 auth, 04 logs, 05 admin usuarios, 06 tablas académico, 07 admin profesores, 08 admin estudiantes, 09 admin periodos, 10 admin secciones, 11 admin asignaturas, 12 admin asignaciones, 13 admin matrículas, 14 ausentismo, 15 views.
- RP-26: Lógica repetida en 2 o más funciones va a `02_helpers.sql`.
- RP-27: Los scripts se escriben para crear desde cero; no se cuidan datos previos. Después de ejecutarlos hay que reiniciar la API: Npgsql guarda en caché los OID de los tipos (citext, enums) y los recrea el script.
- RP-28: Las reglas que dependen de la fecha actual se validan en función; las demás, con CHECK en la tabla.
- RP-29: Las reglas de negocio se validan en la base de datos; el backend no las duplica.
- RP-30: Las actualizaciones devuelven `OK` o `SIN_CAMBIOS` y el snapshot previo para auditoría.
- RP-31: Los listados usan `api.fn_tamano_pagina` y `api.fn_offset`. Los filtros se aplican en la DB (nunca en el frontend sobre una página); la búsqueda de texto usa `api.fn_coincide` (sin mayúsculas ni acentos) y en C# `ConsultaConBusqueda`.
- RP-47: "Hoy" es siempre `api.fn_hoy()` (hora de Costa Rica), nunca `CURRENT_DATE`.
- RP-48: Las funciones operativas (profesores) que dependan de un periodo o semestre validan el cierre con `academico.fn_validar_periodo_abierto` / `academico.fn_validar_semestre_abierto` (devuelven el `id_periodo` para la FK). Las funciones `fn_admin_*` no lo validan, para permitir la digitalización de periodos pasados.
- RP-51: Los estados que dependen de la fecha (periodo, matrícula) se derivan en funciones; no se guardan en columnas.
- RP-52: Los filtros por enum (estado, tipo, rol) aceptan cualquier combinación de mayúsculas y se normalizan antes de ir a la DB.
- RP-50: Las funciones `LANGUAGE sql` validan las tablas al crearse: si referencian tablas de un script posterior deben ser plpgsql.
- RP-49: Las secciones se referencian desde otros módulos con `academico.fn_obtener_id_seccion(año, nivel, número)` (NF006) y las asignaturas con `academico.fn_obtener_id_asignatura(código)` (NF007).

## C#
- RP-32: Flujo fijo: Controller → Service → Repository → función SQL. El Repository solo llama funciones SQL, sin SQL de tablas.
- RP-33: Acceso a datos común en `Common/Data/DbExtensions.cs`; no se repite código de comandos Npgsql.
- RP-34: Paginación común en `Common/Models` (`ConsultaPaginada`, `ResultadoPaginado`); los listados usan `ListarPaginadoAsync`.
- RP-35: DTOs de request son `class` con propiedades settable, no `record` con atributos `[property: ...]`.
- RP-36: Los errores de negocio conocidos se devuelven con `this.ApiError(codigo)`.
- RP-37: El namespace refleja la carpeta.

## Módulos
- RP-40: Los módulos de negocio (Auth, Usuarios, Profesores, Estudiantes, Periodos, Secciones, Asignaturas, Asignaciones, Matrículas, Ausentismo) solo dependen de Common, Config, Errors y Logs; nunca entre sí.
- RP-41: Todo lo que usen 2 o más módulos vive en Common (roles, claims, contraseñas, paginación, base de controllers, texto, acceso a datos).
- RP-42: Todo controller hereda de `ApiControllerBase`; los de administración, de `AdminControllerBase` (exige ADMIN).
- RP-43: El id del usuario autenticado se lee con `ActorId`; no se repite la validación del claim en cada endpoint.
- RP-44: Un solo tipo por concepto: el mismo record es resultado del Repository y respuesta HTTP.
- RP-45: Los estados `OK` / `SIN_CAMBIOS` se comparan con `EstadoOperacion`, no con strings sueltos.
- RP-46: Cada módulo se registra con `Add<Nombre>Module` y se conecta en `Program.cs`.

## Auditoría
- RP-38: Todo servicio que muta datos llama a `ILogsService.RegistrarAsync` con una constante de `AccionesLog` (nombres en español, descritos en `log_codes.md`); nunca strings sueltos.
- RP-39: Nunca se registra contraseña ni hash.
