-- ============================================================
-- 02_helpers.sql: TIPOS Y FUNCIONES COMPARTIDAS
-- Se ejecuta después de 01 y antes de todo lo demás.
-- Regla: toda lógica repetida en 2+ funciones vive aquí.
-- ============================================================
SET search_path = academico, api, auth, public;

CREATE TYPE api.roles AS ENUM (
    'ADMIN',
    'PROFESOR_REGULAR',
    'PROFESOR_CAS',
    'GUIA',
    'COORD_MONOGRAFIA',
    'COORD_CAS'
);

-- ------------------------------------------------------------
-- Errores: lanza una excepción con ERRCODE propio (5 caracteres).
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION api.fn_lanzar_excepcion(p_codigo TEXT, p_mensaje TEXT)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION USING ERRCODE = p_codigo, MESSAGE = p_mensaje;
END;
$$;

-- ------------------------------------------------------------
-- Texto: trim; vacío => NULL (sirve para opcionales y para que un
-- obligatorio vacío falle con 23502).
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION api.fn_limpiar(p_texto TEXT)
RETURNS TEXT
LANGUAGE sql IMMUTABLE
AS $$
    SELECT NULLIF(trim(p_texto), '');
$$;

-- Cédula (RN-09/RN-11): se guarda y se busca en mayúsculas, así 'est-0001' y 'EST-0001' son la misma persona.
CREATE OR REPLACE FUNCTION api.fn_limpiar_cedula(p_cedula TEXT)
RETURNS TEXT
LANGUAGE sql IMMUTABLE
AS $$
    SELECT upper(NULLIF(trim(p_cedula), ''));
$$;

-- ------------------------------------------------------------
-- Fecha actual en hora de Costa Rica. Toda regla que dependa de "hoy" usa esta función
-- (no CURRENT_DATE, que depende del TimeZone de la sesión/servidor).
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION api.fn_hoy()
RETURNS DATE
LANGUAGE sql STABLE
AS $$
    SELECT (NOW() AT TIME ZONE 'America/Costa_Rica')::DATE;
$$;

-- ------------------------------------------------------------
-- Paginación: normaliza (clamp) y calcula el offset en BIGINT
-- (evita overflow con páginas enormes).
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION api.fn_pagina(p_pagina INTEGER)
RETURNS INTEGER
LANGUAGE sql IMMUTABLE
AS $$
    SELECT GREATEST(COALESCE(p_pagina, 1), 1);
$$;

CREATE OR REPLACE FUNCTION api.fn_tamano_pagina(p_tamano INTEGER)
RETURNS INTEGER
LANGUAGE sql IMMUTABLE
AS $$
    SELECT LEAST(GREATEST(COALESCE(p_tamano, 20), 1), 100);
$$;

CREATE OR REPLACE FUNCTION api.fn_offset(p_pagina INTEGER, p_tamano INTEGER)
RETURNS BIGINT
LANGUAGE sql IMMUTABLE
AS $$
    SELECT (api.fn_pagina(p_pagina)::BIGINT - 1) * api.fn_tamano_pagina(p_tamano);
$$;

-- ------------------------------------------------------------
-- Administradores
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION api.fn_es_admin_activo(p_id_usuario UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql STABLE
SET search_path = academico, auth, api, public
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1
        FROM api.usuarios u
        JOIN api.usuario_roles ur ON ur.id_usuario = u.id_usuario
        WHERE u.id_usuario = p_id_usuario
            AND u.activo = TRUE
            AND ur.rol = 'ADMIN'
    );
END;
$$;

-- AU009 si el actor no es ADMIN activo. Primera línea de toda función admin_*.
CREATE OR REPLACE FUNCTION api.fn_validar_admin_activo(p_id_usuario_actor UUID)
RETURNS VOID
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
BEGIN
    IF NOT api.fn_es_admin_activo(p_id_usuario_actor) THEN
        PERFORM api.fn_lanzar_excepcion('AU009', 'No autorizado.');
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION api.fn_contar_admins_activos()
RETURNS INTEGER
LANGUAGE plpgsql STABLE
SET search_path = academico, auth, api, public
AS $$
BEGIN
    RETURN (
        SELECT COUNT(*)::INTEGER
        FROM api.usuario_roles ur
        JOIN api.usuarios u ON u.id_usuario = ur.id_usuario
        WHERE ur.rol = 'ADMIN' AND u.activo = TRUE
    );
END;
$$;

-- Lanza p_codigo si p_id_objetivo es el último ADMIN activo. Toma un advisory lock
-- transaccional para que dos admins no puedan quitarse mutuamente a la vez
-- (sin el lock ambos verían "quedan 2" y el sistema quedaría sin admins).
CREATE OR REPLACE FUNCTION api.fn_validar_no_ultimo_admin(
    p_id_objetivo UUID,
    p_codigo TEXT,
    p_mensaje TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
BEGIN
    PERFORM pg_advisory_xact_lock(hashtextextended('api.admins_activos', 0));

    IF api.fn_es_admin_activo(p_id_objetivo) AND api.fn_contar_admins_activos() <= 1 THEN
        PERFORM api.fn_lanzar_excepcion(p_codigo, p_mensaje);
    END IF;
END;
$$;

-- ------------------------------------------------------------
-- Roles de un usuario (arreglo vacío si no tiene).
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION api.fn_roles_de(p_id_usuario UUID)
RETURNS api.roles[]
LANGUAGE plpgsql STABLE
SET search_path = academico, auth, api, public
AS $$
BEGIN
    RETURN COALESCE(
        (SELECT array_agg(ur.rol ORDER BY ur.rol)
         FROM api.usuario_roles ur
         WHERE ur.id_usuario = p_id_usuario),
        ARRAY[]::api.roles[]);
END;
$$;

-- ------------------------------------------------------------
-- Revocación: cierra todas las sesiones e invalida los access tokens ya emitidos.
-- Usar en: logout-all, cambio de contraseña, cambio de roles/email, desactivación,
-- reutilización de refresh token.
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE api.sp_revocar_acceso(p_id_usuario UUID)
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
BEGIN
    DELETE FROM api.sesiones WHERE id_usuario = p_id_usuario;

    UPDATE api.usuarios
    SET tokens_invalidados_desde = NOW(),
        actualizado_en = NOW()
    WHERE id_usuario = p_id_usuario;
END;
$$;

-- ------------------------------------------------------------
-- Concurrencia (RP-57): bloquea la fila del usuario. FOR UPDATE lo usan quienes cambian su estado o sus roles
-- (desactivar, revocar rol); FOR SHARE, quienes dependen de que conserve un rol activo (asignar guía, asignación,
-- CAS, monografía). Así una revocación y una asignación simultáneas se serializan y la segunda ve a la primera.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION api.fn_bloquear_usuario(p_id_usuario UUID, p_exclusivo BOOLEAN)
RETURNS VOID
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
BEGIN
    IF p_exclusivo THEN
        PERFORM 1 FROM api.usuarios WHERE id_usuario = p_id_usuario FOR UPDATE;
    ELSE
        PERFORM 1 FROM api.usuarios WHERE id_usuario = p_id_usuario FOR SHARE;
    END IF;
END;
$$;

-- ------------------------------------------------------------
-- Profesores: TRUE si el usuario del profesor está activo y tiene el rol dado. Lo usan las
-- asignaciones operativas (guía de sección, asignaciones docentes) en periodos no finalizados.
-- Bloquea el usuario (FOR SHARE) antes de leer sus roles (RP-57): VOLATILE.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION academico.fn_profesor_tiene_rol_activo(p_id_profesor BIGINT, p_rol api.roles)
RETURNS BOOLEAN
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
BEGIN
    PERFORM api.fn_bloquear_usuario((SELECT pr.id_usuario FROM academico.profesores pr WHERE pr.id_profesor = p_id_profesor), FALSE);

    RETURN EXISTS (
        SELECT 1
        FROM academico.profesores pr
        JOIN api.usuarios u ON u.id_usuario = pr.id_usuario
        JOIN api.usuario_roles ur ON ur.id_usuario = u.id_usuario
        WHERE pr.id_profesor = p_id_profesor AND u.activo AND ur.rol = p_rol
    );
END;
$$;

-- ------------------------------------------------------------
-- Profesores: AD003 si el usuario no imparte ninguna asignatura en la sección ni es su guía (RN-59).
-- Lo usan las consultas de profesores sobre una sección (estudiantes y ficha del estudiante).
-- plpgsql: las tablas se crean en 06 (RP-50).
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION academico.fn_validar_acceso_seccion(p_id_usuario UUID, p_id_seccion BIGINT)
RETURNS VOID
LANGUAGE plpgsql STABLE
SET search_path = academico, auth, api, public
AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM academico.asignaciones_docentes a
        JOIN academico.profesores pr ON pr.id_profesor = a.id_profesor
        WHERE a.id_seccion = p_id_seccion AND pr.id_usuario = p_id_usuario
        UNION ALL
        SELECT 1 FROM academico.secciones s
        JOIN academico.profesores pr ON pr.id_profesor = s.id_profesor_guia
        WHERE s.id_seccion = p_id_seccion AND pr.id_usuario = p_id_usuario
    ) THEN
        PERFORM api.fn_lanzar_excepcion('AD003', 'No tienes acceso a esa sección.');
    END IF;
END;
$$;

-- ------------------------------------------------------------
-- Profesores: AD005 si el usuario no es el guía de la sección (RN-71). Devuelve el id de la sección.
-- Lo usan las consultas del guía (ausentismo, monografías, reporte de bandas). plpgsql (RP-50).
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION academico.fn_validar_guia_seccion(p_id_usuario UUID, p_anio INTEGER, p_nivel INTEGER, p_numero INTEGER)
RETURNS BIGINT
LANGUAGE plpgsql STABLE
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_id_seccion BIGINT := academico.fn_obtener_id_seccion(p_anio, p_nivel, p_numero);
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM academico.secciones s
        JOIN academico.profesores pr ON pr.id_profesor = s.id_profesor_guia
        WHERE s.id_seccion = v_id_seccion AND pr.id_usuario = p_id_usuario
    ) THEN
        PERFORM api.fn_lanzar_excepcion('AD005', 'No eres el guía de esa sección.');
    END IF;

    RETURN v_id_seccion;
END;
$$;

-- ------------------------------------------------------------
-- Fecha de nacimiento coherente (no futura ni anterior a 1900). Depende de "hoy", por eso es
-- función y no CHECK (RP-28). Cada módulo pasa su código (ES004 estudiantes, PR005 profesores).
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION api.fn_validar_fecha_nacimiento(p_fecha_nacimiento DATE, p_codigo TEXT)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_fecha_nacimiento IS NULL OR p_fecha_nacimiento < DATE '1900-01-01' OR p_fecha_nacimiento > api.fn_hoy() THEN
        PERFORM api.fn_lanzar_excepcion(p_codigo, 'La fecha de nacimiento no es válida.');
    END IF;
END;
$$;

-- ------------------------------------------------------------
-- Búsqueda de texto en listados: TRUE si p_busqueda es NULL/vacía o si aparece en p_texto,
-- sin distinguir mayúsculas ni acentos ("solis" encuentra "Solís"). Los comodines % y _ del
-- usuario se tratan como texto literal.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION api.fn_coincide(p_texto TEXT, p_busqueda TEXT)
RETURNS BOOLEAN
LANGUAGE sql STABLE
SET search_path = academico, api, public
AS $$
    SELECT api.fn_limpiar(p_busqueda) IS NULL
        OR academico.unaccent(COALESCE(p_texto, '')) ILIKE
           '%' || replace(replace(replace(academico.unaccent(api.fn_limpiar(p_busqueda)), '\', '\\'), '%', '\%'), '_', '\_') || '%';
$$;
