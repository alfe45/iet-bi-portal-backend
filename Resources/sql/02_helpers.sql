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
