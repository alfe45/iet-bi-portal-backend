-- ============================================================
-- Migración 2026-11-08 (LC01, RD-010): edición atómica del profesor (datos + cuenta en una sola petición).
-- Solo crea academico.fn_admin_actualizar_cuenta_profesor; no toca datos. Después de ejecutarla, reiniciar la API.
-- ============================================================
SET search_path = academico, api, auth, public;

-- CU 03 - Modificar la cuenta del profesor en la misma petición (y transacción) que sus datos (RD-010): si algo
-- falla, no queda nada aplicado. Cada parámetro NULL no se modifica: correo, hash de la contraseña nueva, estado y
-- roles (el conjunto completo deseado: se agregan los que faltan y se quitan los que sobran). Reutiliza las
-- operaciones de auth.fn_admin_*, con sus mismas validaciones y errores (NU001, TA001, AU003-AU005, AU010, AU011,
-- AU016-AU021). Un profesor sin cuenta (registrado antes de RN-05) la recibe aquí (NU001/NU002 si faltan datos).
-- Devuelve 'OK'/'SIN_CAMBIOS', el snapshot previo de la cuenta (auditoría), el id del usuario y si se creó la cuenta.
CREATE OR REPLACE FUNCTION academico.fn_admin_actualizar_cuenta_profesor(
    p_id_usuario_actor UUID,
    p_cedula TEXT,
    p_email TEXT,
    p_password_hash TEXT,
    p_activo BOOLEAN,
    p_roles TEXT[]
)
RETURNS TABLE(out_status TEXT, out_datos_anteriores JSONB, out_id_usuario UUID, out_cuenta_creada BOOLEAN)
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_prof academico.profesores%ROWTYPE;
    v_id UUID;
    v_prev JSONB;
    v_roles api.roles[];
    v_rol api.roles;
    v_cambio BOOLEAN := FALSE;
BEGIN
    PERFORM api.fn_validar_admin_activo(p_id_usuario_actor);

    SELECT * INTO v_prof
    FROM academico.profesores p
    WHERE p.cedula = api.fn_limpiar_cedula(p_cedula)
    FOR UPDATE;

    IF NOT FOUND THEN
        PERFORM api.fn_lanzar_excepcion('NF002', 'El profesor no existe.');
    END IF;

    IF v_prof.id_usuario IS NULL THEN
        v_id := academico.fn_asignar_cuenta_profesor(p_id_usuario_actor, v_prof.id_profesor, p_email, p_password_hash, p_roles);
        IF p_activo IS FALSE THEN
            PERFORM auth.fn_admin_cambiar_estado_usuario(p_id_usuario_actor, v_id, FALSE);
        END IF;
        RETURN QUERY SELECT 'OK'::TEXT, NULL::JSONB, v_id, TRUE;
        RETURN;
    END IF;

    v_id := v_prof.id_usuario;
    SELECT jsonb_build_object('email', u.email, 'activo', u.activo,
               'roles', COALESCE((SELECT jsonb_agg(ur.rol ORDER BY ur.rol) FROM api.usuario_roles ur WHERE ur.id_usuario = u.id_usuario), '[]'::JSONB))
    INTO v_prev
    FROM api.usuarios u
    WHERE u.id_usuario = v_id;

    IF p_email IS NOT NULL AND (SELECT e.out_status FROM auth.fn_admin_actualizar_email(p_id_usuario_actor, v_id, p_email::CITEXT) e) = 'OK' THEN
        v_cambio := TRUE;
    END IF;

    IF p_password_hash IS NOT NULL THEN
        CALL auth.sp_admin_resetear_contrasena(p_id_usuario_actor, v_id, p_password_hash);
        v_cambio := TRUE;
    END IF;

    IF p_roles IS NOT NULL THEN
        -- Mismo criterio que al crear la cuenta: sin repetir y sin distinguir mayúsculas (texto inválido: 22P02 -> 400).
        SELECT COALESCE(array_agg(DISTINCT upper(trim(r))::api.roles), ARRAY[]::api.roles[])
        INTO v_roles
        FROM unnest(p_roles) r;

        IF cardinality(v_roles) = 0 THEN
            PERFORM api.fn_lanzar_excepcion('AU005', 'No se puede quitar el único rol que tiene el usuario.');
        END IF;

        -- Primero se agregan (así quitar el único rol anterior no choca con AU005) y luego se quitan.
        FOREACH v_rol IN ARRAY v_roles LOOP
            IF auth.fn_admin_asignar_rol(p_id_usuario_actor, v_id, v_rol) = 'OK' THEN
                v_cambio := TRUE;
            END IF;
        END LOOP;

        FOR v_rol IN
            SELECT ur.rol FROM api.usuario_roles ur WHERE ur.id_usuario = v_id AND ur.rol <> ALL (v_roles) ORDER BY ur.rol
        LOOP
            IF auth.fn_admin_revocar_rol(p_id_usuario_actor, v_id, v_rol) = 'OK' THEN
                v_cambio := TRUE;
            END IF;
        END LOOP;
    END IF;

    -- El estado va al final: desactivar valida las responsabilidades vigentes con los roles ya actualizados (AU020).
    IF p_activo IS NOT NULL AND auth.fn_admin_cambiar_estado_usuario(p_id_usuario_actor, v_id, p_activo) = 'OK' THEN
        v_cambio := TRUE;
    END IF;

    IF NOT v_cambio THEN
        RETURN QUERY SELECT 'SIN_CAMBIOS'::TEXT, NULL::JSONB, v_id, FALSE;
        RETURN;
    END IF;

    RETURN QUERY SELECT 'OK'::TEXT, v_prev, v_id, FALSE;
END;
$$;
