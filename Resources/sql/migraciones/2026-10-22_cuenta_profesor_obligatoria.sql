-- ============================================================
-- Migración 2026-10-22: cuenta del profesor obligatoria (RN-05) y eliminar profesor elimina su cuenta (RN-07).
-- Para una base ya creada con los scripts 01..19 (por ejemplo Neon): NO borra datos. En una base nueva no hace falta:
-- 07_admin_profesores.sql ya trae estas funciones. Después de ejecutarla, reiniciar la API (Npgsql cachea los tipos).
-- Ejecutar como el dueño de los esquemas (el mismo rol que corrió los scripts), para que bi_api herede EXECUTE.
-- ============================================================
SET search_path = academico, api, auth, public;

BEGIN;

-- Firmas anteriores (cuenta opcional, vincular un usuario existente y quitar la cuenta).
DROP FUNCTION IF EXISTS academico.fn_admin_registrar_profesor(UUID, TEXT, TEXT, TEXT, TEXT, TEXT, DATE, UUID, TEXT, TEXT, TEXT[]);
DROP FUNCTION IF EXISTS academico.fn_admin_crear_cuenta_profesor(UUID, TEXT, UUID, TEXT, TEXT, TEXT[]);
DROP FUNCTION IF EXISTS academico.fn_asignar_cuenta_profesor(UUID, BIGINT, UUID, TEXT, TEXT, TEXT[]);
DROP FUNCTION IF EXISTS academico.fn_admin_quitar_cuenta_profesor(UUID, TEXT);

-- Interna: crea la cuenta del profesor (correo + hash de la contraseña + roles). Sin roles, la cuenta nace con
-- PROFESOR_REGULAR (RN-05). Correo o contraseña vacíos: NU001/NU002; correo en uso: TA001 (auth.fn_insertar_usuario).
-- El llamador ya bloqueó al profesor y comprobó que no tiene cuenta. Devuelve el id del usuario.
CREATE OR REPLACE FUNCTION academico.fn_asignar_cuenta_profesor(
    p_id_usuario_actor UUID,
    p_id_profesor BIGINT,
    p_email TEXT,
    p_password_hash TEXT,
    p_roles TEXT[]
)
RETURNS UUID
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_id UUID;
    v_roles api.roles[];
BEGIN
    -- Roles sin repetir y sin distinguir mayúsculas; un texto que no es rol lo rechaza el cast (22P02 -> 400).
    SELECT COALESCE(array_agg(DISTINCT upper(trim(r))::api.roles ORDER BY upper(trim(r))::api.roles), ARRAY['PROFESOR_REGULAR']::api.roles[])
    INTO v_roles
    FROM unnest(COALESCE(p_roles, ARRAY[]::TEXT[])) r;

    PERFORM auth.fn_validar_rol_unico(NULL, r) FROM unnest(v_roles) r;

    v_id := auth.fn_insertar_usuario(p_email::CITEXT, p_password_hash, v_roles[1], p_id_usuario_actor);

    INSERT INTO api.usuario_roles (id_usuario, rol, asignado_por)
    SELECT v_id, r, p_id_usuario_actor FROM unnest(v_roles[2:]) r;

    UPDATE academico.profesores SET id_usuario = v_id WHERE id_profesor = p_id_profesor;
    RETURN v_id;
END;
$$;

-- CU 06 - Registrar profesor con su cuenta en la misma operación (RN-05): el correo y la contraseña son
-- obligatorios (NU001/NU002); si la cuenta falla, el profesor tampoco queda registrado. Devuelve la cédula.
CREATE OR REPLACE FUNCTION academico.fn_admin_registrar_profesor(
    p_id_usuario_actor UUID,
    p_nombre TEXT,
    p_primer_apellido TEXT,
    p_segundo_apellido TEXT,
    p_cedula TEXT,
    p_numero_celular TEXT,
    p_fecha_nacimiento DATE,
    p_email TEXT,
    p_password_hash TEXT,
    p_roles TEXT[]
)
RETURNS TEXT
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_cedula TEXT := api.fn_limpiar_cedula(p_cedula);
    v_id BIGINT;
BEGIN
    PERFORM api.fn_validar_admin_activo(p_id_usuario_actor);

    IF EXISTS (SELECT 1 FROM academico.profesores WHERE cedula = v_cedula) THEN
        PERFORM api.fn_lanzar_excepcion('PR002', 'Ya existe un profesor con esa cédula.');
    END IF;

    PERFORM api.fn_validar_fecha_nacimiento(p_fecha_nacimiento, 'PR005');

    INSERT INTO academico.profesores (
        nombre, primer_apellido, segundo_apellido, cedula, numero_celular, fecha_nacimiento)
    VALUES (
        api.fn_limpiar(p_nombre), api.fn_limpiar(p_primer_apellido), api.fn_limpiar(p_segundo_apellido),
        v_cedula, api.fn_limpiar(p_numero_celular), p_fecha_nacimiento)
    RETURNING id_profesor INTO v_id;

    PERFORM academico.fn_asignar_cuenta_profesor(p_id_usuario_actor, v_id, p_email, p_password_hash, p_roles);

    RETURN v_cedula;
END;
$$;

-- CU 06 - Crear la cuenta de un profesor registrado antes de que fuera obligatoria (RN-05). Devuelve el id del usuario.
CREATE OR REPLACE FUNCTION academico.fn_admin_crear_cuenta_profesor(
    p_id_usuario_actor UUID,
    p_cedula TEXT,
    p_email TEXT,
    p_password_hash TEXT,
    p_roles TEXT[]
)
RETURNS UUID
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_prof academico.profesores%ROWTYPE;
BEGIN
    PERFORM api.fn_validar_admin_activo(p_id_usuario_actor);

    SELECT * INTO v_prof
    FROM academico.profesores p
    WHERE p.cedula = api.fn_limpiar_cedula(p_cedula)
    FOR UPDATE;   -- RP-57: dos peticiones simultáneas no le crean dos cuentas

    IF NOT FOUND THEN
        PERFORM api.fn_lanzar_excepcion('NF002', 'El profesor no existe.');
    END IF;

    IF v_prof.id_usuario IS NOT NULL THEN
        PERFORM api.fn_lanzar_excepcion('PR007', 'El profesor ya tiene cuenta.');
    END IF;

    RETURN academico.fn_asignar_cuenta_profesor(p_id_usuario_actor, v_prof.id_profesor, p_email, p_password_hash, p_roles);
END;
$$;

-- CU 09 - Eliminar profesor: elimina el perfil y su cuenta de usuario en la misma operación (RN-07).
-- No se elimina si es guía (PR004), si la cuenta es la del propio actor (AU012), si es el último administrador activo
-- (AU013) o si tiene asignaciones o monografías vigentes (PR009). Si sus registros académicos lo referencian con
-- FK RESTRICT, Postgres lanza 23001 y no se borra nada. Devuelve el snapshot previo (perfil + correo y roles).
CREATE OR REPLACE FUNCTION academico.fn_admin_eliminar_profesor(
    p_id_usuario_actor UUID,
    p_cedula TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_prof academico.profesores%ROWTYPE;
    v_prev JSONB;
BEGIN
    PERFORM api.fn_validar_admin_activo(p_id_usuario_actor);

    SELECT * INTO v_prof
    FROM academico.profesores p
    WHERE p.cedula = api.fn_limpiar_cedula(p_cedula)
    FOR UPDATE;

    IF NOT FOUND THEN
        PERFORM api.fn_lanzar_excepcion('NF002', 'El profesor no existe.');
    END IF;

    IF EXISTS (SELECT 1 FROM academico.secciones WHERE id_profesor_guia = v_prof.id_profesor) THEN
        PERFORM api.fn_lanzar_excepcion('PR004', 'El profesor es guía de una sección.');
    END IF;

    v_prev := to_jsonb(v_prof);

    IF v_prof.id_usuario IS NOT NULL THEN
        IF p_id_usuario_actor = v_prof.id_usuario THEN
            PERFORM api.fn_lanzar_excepcion('AU012', 'Un administrador no puede eliminarse a sí mismo.');
        END IF;

        -- RP-57: serializa con quien le asigna algo que exige un rol (fn_profesor_tiene_rol_activo toma FOR SHARE).
        PERFORM api.fn_bloquear_usuario(v_prof.id_usuario, TRUE);

        PERFORM api.fn_validar_no_ultimo_admin(v_prof.id_usuario, 'AU013',
            'No se puede eliminar al último administrador activo del sistema.');

        IF auth.fn_rol_en_uso(v_prof.id_usuario, 'PROFESOR_REGULAR') OR auth.fn_rol_en_uso(v_prof.id_usuario, 'PROFESOR_CAS')
           OR auth.fn_rol_en_uso(v_prof.id_usuario, 'COORD_MONOGRAFIA') THEN
            PERFORM api.fn_lanzar_excepcion('PR009', 'El profesor tiene asignaciones o monografías vigentes.');
        END IF;

        v_prev := v_prev || jsonb_build_object(
            'email', (SELECT u.email FROM api.usuarios u WHERE u.id_usuario = v_prof.id_usuario),
            'roles', api.fn_roles_de(v_prof.id_usuario));
    END IF;

    DELETE FROM academico.profesores WHERE id_profesor = v_prof.id_profesor;

    IF v_prof.id_usuario IS NOT NULL THEN
        DELETE FROM api.usuarios WHERE id_usuario = v_prof.id_usuario;
    END IF;

    RETURN v_prev;
END;
$$;

COMMIT;
