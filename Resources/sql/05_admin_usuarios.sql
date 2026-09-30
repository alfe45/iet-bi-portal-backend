-- ============================================================
-- 05_admin_usuarios.sql: ADMINISTRACIÓN DE USUARIOS (CU 02 a 07) + detalle (CU 01)
-- Toda función fn_admin_* / sp_admin_* empieza validando api.fn_validar_admin_activo.
-- ============================================================
SET search_path = academico, api, auth, public;

CREATE TYPE api.usuario_admin AS (
    id_usuario UUID,
    email CITEXT,
    activo BOOLEAN,
    bloqueado_hasta TIMESTAMPTZ,
    ultimo_login TIMESTAMPTZ,
    creado_en TIMESTAMPTZ,
    roles api.roles[],
    cantidad_sesiones BIGINT   -- solo sesiones vigentes (no rotadas, no expiradas)
);

-- ============================================================
-- CU 02 - Registrar usuario (siempre nace con PROFESOR_REGULAR)
-- ============================================================
CREATE OR REPLACE FUNCTION auth.fn_admin_registrar_usuario(
    p_id_usuario_actor UUID,
    p_email CITEXT,
    p_password_hash TEXT
)
RETURNS UUID
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
BEGIN
    PERFORM api.fn_validar_admin_activo(p_id_usuario_actor);
    RETURN auth.fn_insertar_usuario(p_email, p_password_hash, 'PROFESOR_REGULAR', p_id_usuario_actor);
END;
$$;

-- ============================================================
-- CU 01 / CU 03 - Consultar usuarios (detalle sirve también para "mi perfil")
-- ============================================================
CREATE OR REPLACE FUNCTION auth.fn_obtener_usuario_detalle(p_id_usuario UUID)
RETURNS SETOF api.usuario_admin
LANGUAGE sql STABLE
SET search_path = academico, auth, api, public
AS $$
    SELECT u.id_usuario, u.email, u.activo, u.bloqueado_hasta, u.ultimo_login, u.creado_en,
           api.fn_roles_de(u.id_usuario),
           (SELECT COUNT(*) FROM api.sesiones s
             WHERE s.id_usuario = u.id_usuario AND s.rotado_en IS NULL AND s.expira_en > NOW())
    FROM api.usuarios u
    WHERE u.id_usuario = p_id_usuario;
$$;

CREATE OR REPLACE FUNCTION auth.fn_admin_listar_usuarios(p_pagina INTEGER, p_tamano_pagina INTEGER)
RETURNS SETOF api.usuario_admin
LANGUAGE sql STABLE
SET search_path = academico, auth, api, public
AS $$
    SELECT u.id_usuario, u.email, u.activo, u.bloqueado_hasta, u.ultimo_login, u.creado_en,
           api.fn_roles_de(u.id_usuario),
           (SELECT COUNT(*) FROM api.sesiones s
             WHERE s.id_usuario = u.id_usuario AND s.rotado_en IS NULL AND s.expira_en > NOW())
    FROM api.usuarios u
    ORDER BY u.creado_en DESC, u.id_usuario
    LIMIT api.fn_tamano_pagina(p_tamano_pagina)
    OFFSET api.fn_offset(p_pagina, p_tamano_pagina);
$$;

CREATE OR REPLACE FUNCTION auth.fn_admin_contar_usuarios()
RETURNS BIGINT
LANGUAGE sql STABLE
SET search_path = academico, auth, api, public
AS $$
    SELECT COUNT(*) FROM api.usuarios;
$$;

-- ============================================================
-- CU 04 - Modificar email y resetear contraseña
-- ============================================================
CREATE OR REPLACE FUNCTION auth.fn_admin_actualizar_email(
    p_id_usuario_actor UUID,
    p_id_usuario_objetivo UUID,
    p_nuevo_email CITEXT
)
RETURNS TABLE(out_status TEXT, out_email_anterior CITEXT)
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_email_actual CITEXT;
    v_email_nuevo CITEXT := api.fn_limpiar(p_nuevo_email::TEXT)::CITEXT;
BEGIN
    PERFORM api.fn_validar_admin_activo(p_id_usuario_actor);

    SELECT u.email INTO v_email_actual
    FROM api.usuarios u
    WHERE u.id_usuario = p_id_usuario_objetivo
    FOR UPDATE;

    IF NOT FOUND THEN
        PERFORM api.fn_lanzar_excepcion('NF001', 'El usuario no existe.');
    END IF;

    IF v_email_nuevo IS NULL THEN
        PERFORM api.fn_lanzar_excepcion('NU001', 'El correo no puede estar vacío.');
    END IF;

    IF EXISTS (SELECT 1 FROM api.usuarios WHERE email = v_email_nuevo AND id_usuario <> p_id_usuario_objetivo) THEN
        PERFORM api.fn_lanzar_excepcion('TA001', 'El correo ya está en uso.');
    END IF;

    IF v_email_actual = v_email_nuevo THEN
        RETURN QUERY SELECT 'SIN_CAMBIOS'::TEXT, v_email_actual;
        RETURN;
    END IF;

    UPDATE api.usuarios SET email = v_email_nuevo WHERE id_usuario = p_id_usuario_objetivo;
    CALL api.sp_revocar_acceso(p_id_usuario_objetivo);   -- el JWT lleva el email como claim

    RETURN QUERY SELECT 'OK'::TEXT, v_email_actual;
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
BEGIN
    PERFORM api.fn_validar_admin_activo(p_id_usuario_actor);
    CALL auth.sp_establecer_contrasena(p_id_usuario_objetivo, p_new_password_hash);
END;
$$;

-- ============================================================
-- CU 05 - Activar / desactivar
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
    v_activo_actual BOOLEAN;
BEGIN
    PERFORM api.fn_validar_admin_activo(p_id_usuario_actor);

    SELECT u.activo INTO v_activo_actual
    FROM api.usuarios u
    WHERE u.id_usuario = p_id_usuario_objetivo;

    IF NOT FOUND THEN
        PERFORM api.fn_lanzar_excepcion('NF001', 'El usuario no existe.');
    END IF;

    IF v_activo_actual = p_activo THEN
        RETURN 'SIN_CAMBIOS';
    END IF;

    IF NOT p_activo THEN
        IF p_id_usuario_actor = p_id_usuario_objetivo THEN
            PERFORM api.fn_lanzar_excepcion('AU010', 'Un administrador no puede desactivarse a sí mismo.');
        END IF;
        PERFORM api.fn_validar_no_ultimo_admin(p_id_usuario_objetivo, 'AU011',
            'No se puede desactivar al último administrador activo del sistema.');
    END IF;

    UPDATE api.usuarios SET activo = p_activo WHERE id_usuario = p_id_usuario_objetivo;

    IF NOT p_activo THEN
        CALL api.sp_revocar_acceso(p_id_usuario_objetivo);
    END IF;

    RETURN 'OK';
END;
$$;

-- ============================================================
-- CU 06 - Asignar / revocar roles
-- ============================================================
CREATE OR REPLACE FUNCTION auth.fn_admin_asignar_rol(
    p_id_usuario_actor UUID,
    p_id_usuario_objetivo UUID,
    p_rol api.roles
)
RETURNS TEXT
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
BEGIN
    PERFORM api.fn_validar_admin_activo(p_id_usuario_actor);

    IF NOT EXISTS (SELECT 1 FROM api.usuarios WHERE id_usuario = p_id_usuario_objetivo) THEN
        PERFORM api.fn_lanzar_excepcion('NF001', 'El usuario no existe.');
    END IF;

    INSERT INTO api.usuario_roles (id_usuario, rol, asignado_por)
    VALUES (p_id_usuario_objetivo, p_rol, p_id_usuario_actor)
    ON CONFLICT (id_usuario, rol) DO NOTHING;

    IF NOT FOUND THEN
        RETURN 'SIN_CAMBIOS';
    END IF;

    CALL api.sp_revocar_acceso(p_id_usuario_objetivo);
    RETURN 'OK';
END;
$$;

CREATE OR REPLACE FUNCTION auth.fn_admin_revocar_rol(
    p_id_usuario_actor UUID,
    p_id_usuario_objetivo UUID,
    p_rol api.roles
)
RETURNS TEXT
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
BEGIN
    PERFORM api.fn_validar_admin_activo(p_id_usuario_actor);

    IF NOT EXISTS (SELECT 1 FROM api.usuarios WHERE id_usuario = p_id_usuario_objetivo) THEN
        PERFORM api.fn_lanzar_excepcion('NF001', 'El usuario no existe.');
    END IF;

    IF NOT EXISTS (SELECT 1 FROM api.usuario_roles WHERE id_usuario = p_id_usuario_objetivo AND rol = p_rol) THEN
        RETURN 'SIN_CAMBIOS';
    END IF;

    IF p_rol = 'ADMIN' THEN
        IF p_id_usuario_actor = p_id_usuario_objetivo THEN
            PERFORM api.fn_lanzar_excepcion('AU003', 'Un administrador no puede quitarse a sí mismo el rol ADMIN.');
        END IF;
        PERFORM api.fn_validar_no_ultimo_admin(p_id_usuario_objetivo, 'AU004',
            'No se puede revocar el último administrador activo del sistema.');
    END IF;

    IF (SELECT COUNT(*) FROM api.usuario_roles WHERE id_usuario = p_id_usuario_objetivo) <= 1 THEN
        PERFORM api.fn_lanzar_excepcion('AU005', 'No se puede quitar el único rol que tiene el usuario.');
    END IF;

    DELETE FROM api.usuario_roles WHERE id_usuario = p_id_usuario_objetivo AND rol = p_rol;
    CALL api.sp_revocar_acceso(p_id_usuario_objetivo);

    RETURN 'OK';
END;
$$;

-- ============================================================
-- CU 07 - Eliminar usuario (devuelve email y roles previos para auditoría)
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
    v_email CITEXT;
    v_roles api.roles[];
BEGIN
    PERFORM api.fn_validar_admin_activo(p_id_usuario_actor);

    SELECT u.email INTO v_email FROM api.usuarios u WHERE u.id_usuario = p_id_usuario_objetivo;

    IF NOT FOUND THEN
        PERFORM api.fn_lanzar_excepcion('NF001', 'El usuario no existe.');
    END IF;

    IF p_id_usuario_actor = p_id_usuario_objetivo THEN
        PERFORM api.fn_lanzar_excepcion('AU012', 'Un administrador no puede eliminarse a sí mismo.');
    END IF;

    IF EXISTS (SELECT 1 FROM academico.profesores WHERE id_usuario = p_id_usuario_objetivo) THEN
        PERFORM api.fn_lanzar_excepcion('PR003',
            'No se puede eliminar un usuario que tiene un perfil de profesor. Elimina primero el perfil.');
    END IF;

    PERFORM api.fn_validar_no_ultimo_admin(p_id_usuario_objetivo, 'AU013',
        'No se puede eliminar al último administrador activo del sistema.');

    v_roles := api.fn_roles_de(p_id_usuario_objetivo);

    DELETE FROM api.usuarios WHERE id_usuario = p_id_usuario_objetivo;

    RETURN QUERY SELECT v_email, v_roles;
END;
$$;
