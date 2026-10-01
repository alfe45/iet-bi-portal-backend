-- ============================================================
-- 05_admin_usuarios.sql: ADMINISTRACIÓN DE USUARIOS (CU 02 a 05) + detalle (CU 01)
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
    cantidad_sesiones BIGINT,      -- solo sesiones vigentes (no rotadas, no expiradas)
    cedula_profesor VARCHAR(20),   -- NULL si no tiene perfil de profesor
    nombre_profesor TEXT
);

-- Fila de api.usuario_admin para un usuario (detalle, listado y "mi perfil").
-- plpgsql: referencia academico.profesores, que se crea en 06.
CREATE OR REPLACE FUNCTION auth.fn_a_usuario_admin(u api.usuarios)
RETURNS api.usuario_admin
LANGUAGE plpgsql STABLE
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_fila api.usuario_admin;
BEGIN
    SELECT u.id_usuario, u.email, u.activo, u.bloqueado_hasta, u.ultimo_login, u.creado_en,
           api.fn_roles_de(u.id_usuario),
           (SELECT COUNT(*) FROM api.sesiones s
             WHERE s.id_usuario = u.id_usuario AND s.rotado_en IS NULL AND s.expira_en > NOW()),
           pr.cedula,
           CASE WHEN pr.id_profesor IS NULL THEN NULL
                ELSE concat_ws(' ', pr.nombre, pr.primer_apellido, pr.segundo_apellido) END
    INTO v_fila
    FROM (SELECT 1) x
    LEFT JOIN academico.profesores pr ON pr.id_usuario = u.id_usuario;

    RETURN v_fila;
END;
$$;

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
    SELECT (auth.fn_a_usuario_admin(u)).*
    FROM api.usuarios u
    WHERE u.id_usuario = p_id_usuario;
$$;

-- CU 03 (administrador): el mismo detalle, validando que el actor sea ADMIN (RP-12).
CREATE OR REPLACE FUNCTION auth.fn_admin_obtener_usuario(p_id_usuario_actor UUID, p_id_usuario UUID)
RETURNS SETOF api.usuario_admin
LANGUAGE sql STABLE
SET search_path = academico, auth, api, public
AS $$
    SELECT api.fn_validar_admin_activo(p_id_usuario_actor);
    SELECT * FROM auth.fn_obtener_usuario_detalle(p_id_usuario);
$$;

-- Filtros opcionales: p_busqueda (correo, cédula o nombre del perfil de profesor) y p_rol.
CREATE OR REPLACE FUNCTION auth.fn_usuarios_filtrados(p_busqueda TEXT, p_rol api.roles)
RETURNS SETOF api.usuarios
LANGUAGE plpgsql STABLE
SET search_path = academico, auth, api, public
AS $$
BEGIN
    RETURN QUERY
    SELECT u.*
    FROM api.usuarios u
    LEFT JOIN academico.profesores pr ON pr.id_usuario = u.id_usuario
    WHERE api.fn_coincide(concat_ws(' ', u.email, pr.cedula, pr.nombre, pr.primer_apellido, pr.segundo_apellido), p_busqueda)
      AND (p_rol IS NULL OR EXISTS (SELECT 1 FROM api.usuario_roles ur WHERE ur.id_usuario = u.id_usuario AND ur.rol = p_rol));
END;
$$;

CREATE OR REPLACE FUNCTION auth.fn_admin_listar_usuarios(p_id_usuario_actor UUID, 
    p_busqueda TEXT, p_rol api.roles, p_pagina INTEGER, p_tamano_pagina INTEGER)
RETURNS SETOF api.usuario_admin
LANGUAGE sql STABLE
SET search_path = academico, auth, api, public
AS $$
    SELECT api.fn_validar_admin_activo(p_id_usuario_actor);   -- RP-12 (las lecturas también)
    SELECT (auth.fn_a_usuario_admin(u)).*
    FROM auth.fn_usuarios_filtrados(p_busqueda, p_rol) u
    ORDER BY u.creado_en DESC, u.id_usuario
    LIMIT api.fn_tamano_pagina(p_tamano_pagina)
    OFFSET api.fn_offset(p_pagina, p_tamano_pagina);
$$;

CREATE OR REPLACE FUNCTION auth.fn_admin_contar_usuarios(p_id_usuario_actor UUID, p_busqueda TEXT, p_rol api.roles)
RETURNS BIGINT
LANGUAGE sql STABLE
SET search_path = academico, auth, api, public
AS $$
    SELECT api.fn_validar_admin_activo(p_id_usuario_actor);   -- RP-12 (las lecturas también)
    SELECT COUNT(*) FROM auth.fn_usuarios_filtrados(p_busqueda, p_rol);
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
-- TRUE si el usuario tiene responsabilidades vigentes que dependen del rol (RN-40, RN-49, RN-82, RN-78): guía de una
-- sección o asignaciones (CAS incluido) en un periodo no finalizado, o monografías sin terminar. La usan revocar rol
-- (AU016-AU019) y desactivar (AU020). plpgsql: las tablas de academico se crean en 06 (RP-50).
-- ============================================================
CREATE OR REPLACE FUNCTION auth.fn_rol_en_uso(p_id_usuario UUID, p_rol api.roles)
RETURNS BOOLEAN
LANGUAGE plpgsql STABLE
SET search_path = academico, auth, api, public
AS $$
BEGIN
    RETURN CASE p_rol
        WHEN 'GUIA' THEN EXISTS (
            SELECT 1
            FROM academico.secciones s
            JOIN academico.profesores pr ON pr.id_profesor = s.id_profesor_guia
            JOIN academico.periodos_academicos p ON p.id_periodo = s.id_periodo
            WHERE pr.id_usuario = p_id_usuario AND academico.fn_estado_periodo(p) <> 'FINALIZADO')
        WHEN 'PROFESOR_REGULAR' THEN EXISTS (
            SELECT 1
            FROM academico.asignaciones_docentes a
            JOIN academico.profesores pr ON pr.id_profesor = a.id_profesor
            JOIN academico.secciones s ON s.id_seccion = a.id_seccion
            JOIN academico.periodos_academicos p ON p.id_periodo = s.id_periodo
            WHERE pr.id_usuario = p_id_usuario AND academico.fn_estado_periodo(p) <> 'FINALIZADO')
        WHEN 'PROFESOR_CAS' THEN EXISTS (
            SELECT 1
            FROM academico.asignaciones_docentes a
            JOIN academico.asignaturas asg ON asg.id_asignatura = a.id_asignatura
            JOIN academico.profesores pr ON pr.id_profesor = a.id_profesor
            JOIN academico.secciones s ON s.id_seccion = a.id_seccion
            JOIN academico.periodos_academicos p ON p.id_periodo = s.id_periodo
            WHERE pr.id_usuario = p_id_usuario AND asg.codigo = 'CAS' AND academico.fn_estado_periodo(p) <> 'FINALIZADO')
        WHEN 'COORD_MONOGRAFIA' THEN EXISTS (
            SELECT 1
            FROM academico.monografias mo
            JOIN academico.profesores pr ON pr.id_profesor = mo.id_coordinador
            WHERE pr.id_usuario = p_id_usuario AND mo.estado <> 'TERMINADA')
        ELSE FALSE
    END;
END;
$$;

-- ============================================================
-- CU 04 - Activar / desactivar. AU020: no se desactiva a quien tiene responsabilidades vigentes (decisión del
-- 01/10/2026, misma regla que AU016-AU019): primero se reasignan.
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
    WHERE u.id_usuario = p_id_usuario_objetivo
    FOR UPDATE;   -- RP-57: serializa con asignaciones que exigen usuario activo

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
        IF auth.fn_rol_en_uso(p_id_usuario_objetivo, 'GUIA') OR auth.fn_rol_en_uso(p_id_usuario_objetivo, 'PROFESOR_REGULAR')
           OR auth.fn_rol_en_uso(p_id_usuario_objetivo, 'PROFESOR_CAS') OR auth.fn_rol_en_uso(p_id_usuario_objetivo, 'COORD_MONOGRAFIA') THEN
            PERFORM api.fn_lanzar_excepcion('AU020', 'El usuario tiene secciones, asignaciones o monografías vigentes.');
        END IF;
    END IF;

    UPDATE api.usuarios SET activo = p_activo WHERE id_usuario = p_id_usuario_objetivo;

    IF NOT p_activo THEN
        CALL api.sp_revocar_acceso(p_id_usuario_objetivo);
    END IF;

    RETURN 'OK';
END;
$$;

-- ============================================================
-- CU 04 - Asignar / revocar roles
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

    -- RP-57: serializa con quien asigna algo que exige este rol (fn_profesor_tiene_rol_activo toma FOR SHARE).
    PERFORM api.fn_bloquear_usuario(p_id_usuario_objetivo, TRUE);

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

    -- El front activa los módulos según los roles: quien tiene responsabilidades vigentes conserva el rol que exigen.
    IF p_rol = 'GUIA' AND auth.fn_rol_en_uso(p_id_usuario_objetivo, p_rol) THEN
        PERFORM api.fn_lanzar_excepcion('AU016', 'El usuario es guía de una sección en un periodo no finalizado.');
    END IF;
    IF p_rol = 'PROFESOR_REGULAR' AND auth.fn_rol_en_uso(p_id_usuario_objetivo, p_rol) THEN
        PERFORM api.fn_lanzar_excepcion('AU017', 'El usuario tiene asignaciones docentes en un periodo no finalizado.');
    END IF;
    IF p_rol = 'PROFESOR_CAS' AND auth.fn_rol_en_uso(p_id_usuario_objetivo, p_rol) THEN
        PERFORM api.fn_lanzar_excepcion('AU018', 'El usuario imparte CAS en un periodo no finalizado.');
    END IF;
    IF p_rol = 'COORD_MONOGRAFIA' AND auth.fn_rol_en_uso(p_id_usuario_objetivo, p_rol) THEN
        PERFORM api.fn_lanzar_excepcion('AU019', 'El usuario coordina monografías sin terminar.');
    END IF;

    DELETE FROM api.usuario_roles WHERE id_usuario = p_id_usuario_objetivo AND rol = p_rol;
    CALL api.sp_revocar_acceso(p_id_usuario_objetivo);

    RETURN 'OK';
END;
$$;

-- ============================================================
-- CU 05 - Eliminar usuario (devuelve email y roles previos para auditoría)
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
