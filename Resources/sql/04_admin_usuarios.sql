SET search_path = academico, api, auth, public;
-- ============================================================
-- ADMINISTRACIÓN DE USUARIOS (CU-Administrador 02 a 07)
-- Todas las funciones de mutación validan a nivel de base de datos que
-- p_id_usuario_actor sea un ADMIN activo (defensa en profundidad: el backend
-- ya restringe estos endpoints con [Authorize(Roles = Admin)], pero la DB
-- no confía ciegamente en la capa de arriba).
-- ============================================================

-- ============================================================
-- TIPOS
-- ============================================================
DROP TYPE IF EXISTS api.usuario_admin CASCADE;
CREATE TYPE api.usuario_admin AS (
    id_usuario UUID,
    email CITEXT,
    activo BOOLEAN,
    bloqueado_hasta TIMESTAMPTZ,
    ultimo_login TIMESTAMPTZ,
    creado_en TIMESTAMPTZ,
    roles api.roles[],
    cantidad_sesiones BIGINT
);

-- ============================================================
-- CU 02 - Registrar usuarios (por un ADMIN)
-- Siempre nace con el rol PROFESOR_REGULAR. No emite sesión: el admin no
-- recibe tokens del usuario creado, solo su identidad.
-- ============================================================
CREATE OR REPLACE FUNCTION auth.fn_registrar_usuario_admin(-- TODO: ver nombre cambiar usuario_admin
    p_id_usuario_actor UUID,
    p_email CITEXT,
    p_password_hash TEXT
)
RETURNS UUID
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_es_admin BOOLEAN;
    v_id UUID;
BEGIN
    SELECT EXISTS (
        SELECT 1
        FROM api.usuarios u
        JOIN api.usuario_roles ur ON ur.id_usuario = u.id_usuario
        WHERE u.id_usuario = p_id_usuario_actor
            AND u.activo = TRUE
            AND ur.rol = 'ADMIN'
    )
    INTO v_es_admin;

    IF NOT v_es_admin THEN
        PERFORM auth.fn_lanzar_excepcion('AU009', 'No autorizado.');
    END IF;

    IF p_email IS NULL OR trim(p_email::TEXT) = '' THEN
        PERFORM auth.fn_lanzar_excepcion('NU001', 'El correo no puede estar vacío.');
    END IF;

    IF p_password_hash IS NULL OR trim(p_password_hash) = '' THEN
        PERFORM auth.fn_lanzar_excepcion('NU002', 'La contraseña no puede estar vacía.');
    END IF;

    IF EXISTS (SELECT 1 FROM api.usuarios WHERE email = trim(p_email::TEXT)::CITEXT) THEN
        PERFORM auth.fn_lanzar_excepcion('TA001', 'El correo ya está en uso.');
    END IF;

    INSERT INTO api.usuarios (email, password_hash)
    VALUES (trim(p_email::TEXT)::CITEXT, p_password_hash)
    RETURNING id_usuario INTO v_id;

    INSERT INTO api.usuario_roles (id_usuario, rol, asignado_por)
    VALUES (v_id, 'PROFESOR_REGULAR', p_id_usuario_actor);

    RETURN v_id;
END;
$$;

-- ============================================================
-- CU 03 - Consultar usuarios (listado paginado + detalle)
-- Sin filtros (los aplica el frontend). p_pagina/p_tamano_pagina se
-- normalizan (clamp) en vez de lanzar error: la validación de rango real
-- ya la hace el DTO en C# con [Range].
-- ============================================================
CREATE OR REPLACE FUNCTION auth.fn_listar_usuarios_admin(
    p_pagina INTEGER,
    p_tamano_pagina INTEGER
)
RETURNS SETOF api.usuario_admin
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_pagina INTEGER := GREATEST(COALESCE(p_pagina, 1), 1);
    v_tamano INTEGER := LEAST(GREATEST(COALESCE(p_tamano_pagina, 20), 1), 100);
BEGIN
    RETURN QUERY
    SELECT
        u.id_usuario,
        u.email,
        u.activo,
        u.bloqueado_hasta,
        u.ultimo_login,
        u.creado_en,
        COALESCE(array_agg(ur.rol) FILTER (WHERE ur.rol IS NOT NULL), ARRAY[]::api.roles[]),
        COUNT(DISTINCT s.id_sesion)
    FROM api.usuarios u
    LEFT JOIN api.usuario_roles ur ON ur.id_usuario = u.id_usuario
    LEFT JOIN api.sesiones s ON s.id_usuario = u.id_usuario
    GROUP BY u.id_usuario, u.email, u.activo, u.bloqueado_hasta, u.ultimo_login, u.creado_en
    ORDER BY u.creado_en DESC
    LIMIT v_tamano
    OFFSET (v_pagina - 1) * v_tamano;
END;
$$;

-- Total de usuarios, para armar la metadata de paginación en el backend.
CREATE OR REPLACE FUNCTION auth.fn_contar_usuarios_admin()
RETURNS BIGINT
LANGUAGE sql
SET search_path = academico, auth, api, public
AS $$
    SELECT COUNT(*) FROM api.usuarios;
$$;

-- Detalle de un usuario puntual (sin password_hash).
CREATE OR REPLACE FUNCTION auth.fn_obtener_usuario_admin_por_id(
    p_id_usuario UUID
)
RETURNS SETOF api.usuario_admin
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
BEGIN
    RETURN QUERY
    SELECT
        u.id_usuario,
        u.email,
        u.activo,
        u.bloqueado_hasta,
        u.ultimo_login,
        u.creado_en,
        COALESCE(array_agg(ur.rol) FILTER (WHERE ur.rol IS NOT NULL), ARRAY[]::api.roles[]),
        COUNT(DISTINCT s.id_sesion)
    FROM api.usuarios u
    LEFT JOIN api.usuario_roles ur ON ur.id_usuario = u.id_usuario
    LEFT JOIN api.sesiones s ON s.id_usuario = u.id_usuario
    WHERE u.id_usuario = p_id_usuario
    GROUP BY u.id_usuario, u.email, u.activo, u.bloqueado_hasta, u.ultimo_login, u.creado_en;
END;
$$;

-- ============================================================
-- CU 04 - Modificar usuarios (solo email) + reseteo de contraseña por admin
-- Ambas operaciones invalidan sesiones y tokens del usuario objetivo: el
-- JWT lleva el email como claim, y un reseteo de contraseña debe cerrar
-- cualquier sesión existente (igual que el cambio de contraseña self-service).
-- ============================================================
CREATE OR REPLACE FUNCTION auth.fn_admin_actualizar_email(
    p_id_usuario_actor UUID,
    p_id_usuario_objetivo UUID,
    p_nuevo_email CITEXT
)
RETURNS TEXT
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_es_admin BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1
        FROM api.usuarios u
        JOIN api.usuario_roles ur ON ur.id_usuario = u.id_usuario
        WHERE u.id_usuario = p_id_usuario_actor
            AND u.activo = TRUE
            AND ur.rol = 'ADMIN'
    )
    INTO v_es_admin;

    IF NOT v_es_admin THEN
        PERFORM auth.fn_lanzar_excepcion('AU009', 'No autorizado.');
    END IF;

    IF NOT EXISTS (SELECT 1 FROM api.usuarios WHERE id_usuario = p_id_usuario_objetivo) THEN
        PERFORM auth.fn_lanzar_excepcion('NF001', 'El usuario no existe.');
    END IF;

    IF p_nuevo_email IS NULL OR trim(p_nuevo_email::TEXT) = '' THEN
        PERFORM auth.fn_lanzar_excepcion('NU001', 'El correo no puede estar vacío.');
    END IF;

    IF EXISTS (
        SELECT 1 FROM api.usuarios
        WHERE email = trim(p_nuevo_email::TEXT)::CITEXT
            AND id_usuario <> p_id_usuario_objetivo
    ) THEN
        PERFORM auth.fn_lanzar_excepcion('TA001', 'El correo ya está en uso.');
    END IF;

    IF EXISTS (
        SELECT 1 FROM api.usuarios
        WHERE id_usuario = p_id_usuario_objetivo
            AND email = trim(p_nuevo_email::TEXT)::CITEXT
    ) THEN
        RETURN 'SIN_CAMBIOS';
    END IF;

    UPDATE api.usuarios
    SET email = trim(p_nuevo_email::TEXT)::CITEXT,
        tokens_invalidados_desde = NOW(),
        actualizado_en = NOW()
    WHERE id_usuario = p_id_usuario_objetivo;

    DELETE FROM api.sesiones WHERE id_usuario = p_id_usuario_objetivo;

    RETURN 'OK';
END;
$$;

CREATE OR REPLACE PROCEDURE auth.sp_admin_resetear_contrasena(
    p_id_usuario_actor UUID,
    p_id_usuario_objetivo UUID,
    p_new_password_hash TEXT
)
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_es_admin BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1
        FROM api.usuarios u
        JOIN api.usuario_roles ur ON ur.id_usuario = u.id_usuario
        WHERE u.id_usuario = p_id_usuario_actor
            AND u.activo = TRUE
            AND ur.rol = 'ADMIN'
    )
    INTO v_es_admin;

    IF NOT v_es_admin THEN
        PERFORM auth.fn_lanzar_excepcion('AU009', 'No autorizado.');
    END IF;

    IF NOT EXISTS (SELECT 1 FROM api.usuarios WHERE id_usuario = p_id_usuario_objetivo) THEN
        PERFORM auth.fn_lanzar_excepcion('NF001', 'El usuario no existe.');
    END IF;

    IF p_new_password_hash IS NULL OR trim(p_new_password_hash) = '' THEN
        PERFORM auth.fn_lanzar_excepcion('NU002', 'La contraseña no puede estar vacía.');
    END IF;

    UPDATE api.usuarios
    SET password_hash = p_new_password_hash,
        password_cambiada_en = NOW(),
        intentos_fallidos_login = 0,
        bloqueado_hasta = NULL,
        tokens_invalidados_desde = NOW(),
        actualizado_en = NOW()
    WHERE id_usuario = p_id_usuario_objetivo;

    DELETE FROM api.sesiones WHERE id_usuario = p_id_usuario_objetivo;
END;
$$;

-- ============================================================
-- CU 05 - Activar / desactivar usuarios
-- Reglas calcadas de auth.fn_revocar_rol: un admin no puede desactivarse a
-- sí mismo, y no se puede dejar el sistema sin ningún admin activo. Al
-- desactivar se revocan sesiones y se invalidan los access tokens ya
-- emitidos; al activar no se toca nada de eso.
-- ============================================================
CREATE OR REPLACE FUNCTION auth.fn_admin_cambiar_estado_usuario(
    p_id_usuario_actor UUID,
    p_id_usuario_objetivo UUID,
    p_activo BOOLEAN
)
RETURNS TEXT
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_es_admin BOOLEAN;
    v_activo_actual BOOLEAN;
    v_tiene_admin BOOLEAN;
    v_cantidad_admins INTEGER;
BEGIN
    SELECT EXISTS (
        SELECT 1
        FROM api.usuarios u
        JOIN api.usuario_roles ur ON ur.id_usuario = u.id_usuario
        WHERE u.id_usuario = p_id_usuario_actor
            AND u.activo = TRUE
            AND ur.rol = 'ADMIN'
    )
    INTO v_es_admin;

    IF NOT v_es_admin THEN
        PERFORM auth.fn_lanzar_excepcion('AU009', 'No autorizado.');
    END IF;

    SELECT activo INTO v_activo_actual
    FROM api.usuarios
    WHERE id_usuario = p_id_usuario_objetivo;

    IF NOT FOUND THEN
        PERFORM auth.fn_lanzar_excepcion('NF001', 'El usuario no existe.');
    END IF;

    IF v_activo_actual = p_activo THEN
        RETURN 'SIN_CAMBIOS';
    END IF;

    IF p_activo = FALSE THEN
        IF p_id_usuario_actor = p_id_usuario_objetivo THEN
            PERFORM auth.fn_lanzar_excepcion('AU010', 'Un administrador no puede desactivarse a sí mismo.');
        END IF;

        SELECT EXISTS (
            SELECT 1 FROM api.usuario_roles
            WHERE id_usuario = p_id_usuario_objetivo AND rol = 'ADMIN'
        )
        INTO v_tiene_admin;

        IF v_tiene_admin THEN
            SELECT COUNT(*)
            INTO v_cantidad_admins
            FROM api.usuario_roles ur
            JOIN api.usuarios u ON u.id_usuario = ur.id_usuario
            WHERE ur.rol = 'ADMIN' AND u.activo = TRUE;

            IF v_cantidad_admins <= 1 THEN
                PERFORM auth.fn_lanzar_excepcion('AU011', 'No se puede desactivar al último administrador activo del sistema.');
            END IF;
        END IF;
    END IF;

    UPDATE api.usuarios
    SET activo = p_activo,
        actualizado_en = NOW(),
        tokens_invalidados_desde = CASE WHEN p_activo = FALSE THEN NOW() ELSE tokens_invalidados_desde END
    WHERE id_usuario = p_id_usuario_objetivo;

    IF p_activo = FALSE THEN
        DELETE FROM api.sesiones WHERE id_usuario = p_id_usuario_objetivo;
    END IF;

    RETURN 'OK';
END;
$$;

-- ============================================================
-- CU 07 - Eliminar usuarios (borrado físico)
-- Mismas protecciones que desactivar (no autoeliminarse, no eliminar al
-- último admin activo). Devuelve email + roles del usuario justo antes de
-- borrarlo para que el backend pueda auditar el DELETE con ese snapshot
-- (después del DELETE ya no queda nada que consultar).
-- FKs ya validadas: usuario_roles y sesiones son ON DELETE CASCADE,
-- logs.id_usuario es ON DELETE SET NULL (el rastro de auditoría no se pierde).
-- ============================================================
CREATE OR REPLACE FUNCTION auth.fn_admin_eliminar_usuario(
    p_id_usuario_actor UUID,
    p_id_usuario_objetivo UUID
)
RETURNS TABLE(out_email CITEXT, out_roles api.roles[])
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_es_admin BOOLEAN;
    v_tiene_admin BOOLEAN;
    v_cantidad_admins INTEGER;
    v_email CITEXT;
    v_roles api.roles[];
BEGIN
    SELECT EXISTS (
        SELECT 1
        FROM api.usuarios u
        JOIN api.usuario_roles ur ON ur.id_usuario = u.id_usuario
        WHERE u.id_usuario = p_id_usuario_actor
            AND u.activo = TRUE
            AND ur.rol = 'ADMIN'
    )
    INTO v_es_admin;

    IF NOT v_es_admin THEN
        PERFORM auth.fn_lanzar_excepcion('AU009', 'No autorizado.');
    END IF;

    IF NOT EXISTS (SELECT 1 FROM api.usuarios WHERE id_usuario = p_id_usuario_objetivo) THEN
        PERFORM auth.fn_lanzar_excepcion('NF001', 'El usuario no existe.');
    END IF;

    IF p_id_usuario_actor = p_id_usuario_objetivo THEN
        PERFORM auth.fn_lanzar_excepcion('AU012', 'Un administrador no puede eliminarse a sí mismo.');
    END IF;

    SELECT EXISTS (
        SELECT 1 FROM api.usuario_roles
        WHERE id_usuario = p_id_usuario_objetivo AND rol = 'ADMIN'
    )
    INTO v_tiene_admin;

    IF v_tiene_admin THEN
        SELECT COUNT(*)
        INTO v_cantidad_admins
        FROM api.usuario_roles ur
        JOIN api.usuarios u ON u.id_usuario = ur.id_usuario
        WHERE ur.rol = 'ADMIN' AND u.activo = TRUE;

        IF v_cantidad_admins <= 1 THEN
            PERFORM auth.fn_lanzar_excepcion('AU013', 'No se puede eliminar al último administrador activo del sistema.');
        END IF;
    END IF;

    SELECT email INTO v_email FROM api.usuarios WHERE id_usuario = p_id_usuario_objetivo;

    SELECT COALESCE(array_agg(rol), ARRAY[]::api.roles[])
    INTO v_roles
    FROM api.usuario_roles
    WHERE id_usuario = p_id_usuario_objetivo;

    DELETE FROM api.usuarios WHERE id_usuario = p_id_usuario_objetivo;

    RETURN QUERY SELECT v_email, v_roles;
END;
$$;

-- ============================================================
-- CONSULTAS DE VERIFICACIÓN
-- ============================================================
SELECT * FROM auth.fn_listar_usuarios_admin(1, 20);
SELECT auth.fn_contar_usuarios_admin();