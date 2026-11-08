-- ============================================================
-- 07_admin_profesores.sql: CU 01 a 04. Se opera SIEMPRE por cédula (nunca por id_profesor).
-- La cédula es inmutable: identifica al profesor y no se modifica en CU03.
-- Todo profesor nuevo nace con su cuenta de usuario (RN-05) y eliminarlo elimina también la cuenta (RN-07).
-- ============================================================
SET search_path = academico, api, auth, public;

CREATE TYPE academico.profesor_admin AS (
    nombre VARCHAR(100),
    primer_apellido VARCHAR(100),
    segundo_apellido VARCHAR(100),
    cedula VARCHAR(20),
    numero_celular VARCHAR(20),
    fecha_nacimiento DATE,
    id_usuario UUID,        -- NULL solo en profesores registrados antes de que la cuenta fuera obligatoria (RN-05)
    email CITEXT,
    activo BOOLEAN,
    roles api.roles[]       -- vacío si no tiene cuenta
);

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

-- CU 01 - Registrar profesor con su cuenta en la misma operación (RN-05): el correo y la contraseña son
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

-- CU 02 - Consultar profesores (con su cuenta, si tienen).
-- Búsqueda opcional por nombre, apellidos, cédula o correo (sin mayúsculas ni acentos).
CREATE OR REPLACE FUNCTION academico.fn_a_profesor_admin(p academico.profesores)
RETURNS academico.profesor_admin
LANGUAGE sql STABLE
SET search_path = academico, auth, api, public
AS $$
    SELECT p.nombre, p.primer_apellido, p.segundo_apellido, p.cedula, p.numero_celular, p.fecha_nacimiento,
           u.id_usuario, u.email, u.activo,
           CASE WHEN u.id_usuario IS NULL THEN ARRAY[]::api.roles[] ELSE api.fn_roles_de(u.id_usuario) END
    FROM (SELECT 1) x
    LEFT JOIN api.usuarios u ON u.id_usuario = p.id_usuario;
$$;

CREATE OR REPLACE FUNCTION academico.fn_admin_listar_profesores(p_id_usuario_actor UUID, p_busqueda TEXT, p_pagina INTEGER, p_tamano_pagina INTEGER)
RETURNS SETOF academico.profesor_admin
LANGUAGE sql STABLE
SET search_path = academico, auth, api, public
AS $$
    SELECT api.fn_validar_admin_activo(p_id_usuario_actor);   -- RP-12 (las lecturas también)
    SELECT f.*   -- LATERAL: (f(p)).* llamaría a la función una vez por columna
    FROM academico.profesores p
    LEFT JOIN api.usuarios u ON u.id_usuario = p.id_usuario
    CROSS JOIN LATERAL academico.fn_a_profesor_admin(p) f
    WHERE api.fn_coincide(concat_ws(' ', p.nombre, p.primer_apellido, p.segundo_apellido, p.cedula, u.email), p_busqueda)
    ORDER BY p.primer_apellido, p.segundo_apellido NULLS LAST, p.nombre, p.cedula
    LIMIT api.fn_tamano_pagina(p_tamano_pagina)
    OFFSET api.fn_offset(p_pagina, p_tamano_pagina);
$$;

CREATE OR REPLACE FUNCTION academico.fn_admin_contar_profesores(p_id_usuario_actor UUID, p_busqueda TEXT)
RETURNS BIGINT
LANGUAGE sql STABLE
SET search_path = academico, auth, api, public
AS $$
    SELECT api.fn_validar_admin_activo(p_id_usuario_actor);   -- RP-12 (las lecturas también)
    SELECT COUNT(*)
    FROM academico.profesores p
    LEFT JOIN api.usuarios u ON u.id_usuario = p.id_usuario
    WHERE api.fn_coincide(concat_ws(' ', p.nombre, p.primer_apellido, p.segundo_apellido, p.cedula, u.email), p_busqueda);
$$;

CREATE OR REPLACE FUNCTION academico.fn_admin_obtener_profesor(p_id_usuario_actor UUID, p_cedula TEXT)
RETURNS SETOF academico.profesor_admin
LANGUAGE sql STABLE
SET search_path = academico, auth, api, public
AS $$
    SELECT api.fn_validar_admin_activo(p_id_usuario_actor);   -- RP-12 (las lecturas también)
    SELECT f.*
    FROM academico.profesores p
    CROSS JOIN LATERAL academico.fn_a_profesor_admin(p) f
    WHERE p.cedula = api.fn_limpiar_cedula(p_cedula);
$$;

-- CU 01 - Crear la cuenta de un profesor registrado antes de que fuera obligatoria (RN-05). Devuelve el id del usuario.
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

-- CU 03 - Modificar profesor. Devuelve 'OK' o 'SIN_CAMBIOS' y el snapshot previo (auditoría).
-- La cédula no cambia; la cuenta se modifica en la misma petición con academico.fn_admin_actualizar_cuenta_profesor.
CREATE OR REPLACE FUNCTION academico.fn_admin_actualizar_profesor(
    p_id_usuario_actor UUID,
    p_cedula TEXT,
    p_nombre TEXT,
    p_primer_apellido TEXT,
    p_segundo_apellido TEXT,
    p_numero_celular TEXT,
    p_fecha_nacimiento DATE
)
RETURNS TABLE(out_status TEXT, out_datos_anteriores JSONB)
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_prev academico.profesores%ROWTYPE;
    v_nuevo academico.profesores%ROWTYPE;
BEGIN
    PERFORM api.fn_validar_admin_activo(p_id_usuario_actor);

    SELECT * INTO v_prev
    FROM academico.profesores p
    WHERE p.cedula = api.fn_limpiar_cedula(p_cedula)
    FOR UPDATE;

    IF NOT FOUND THEN
        PERFORM api.fn_lanzar_excepcion('NF002', 'El profesor no existe.');
    END IF;

    v_nuevo := v_prev;
    v_nuevo.nombre := api.fn_limpiar(p_nombre);
    v_nuevo.primer_apellido := api.fn_limpiar(p_primer_apellido);
    v_nuevo.segundo_apellido := api.fn_limpiar(p_segundo_apellido);
    v_nuevo.numero_celular := api.fn_limpiar(p_numero_celular);
    v_nuevo.fecha_nacimiento := p_fecha_nacimiento;

    IF v_nuevo.fecha_nacimiento IS DISTINCT FROM v_prev.fecha_nacimiento THEN
        PERFORM api.fn_validar_fecha_nacimiento(v_nuevo.fecha_nacimiento, 'PR005');
    END IF;

    IF v_nuevo IS NOT DISTINCT FROM v_prev THEN
        RETURN QUERY SELECT 'SIN_CAMBIOS'::TEXT, NULL::JSONB;
        RETURN;
    END IF;

    UPDATE academico.profesores
    SET nombre = v_nuevo.nombre,
        primer_apellido = v_nuevo.primer_apellido,
        segundo_apellido = v_nuevo.segundo_apellido,
        numero_celular = v_nuevo.numero_celular,
        fecha_nacimiento = v_nuevo.fecha_nacimiento
    WHERE id_profesor = v_prev.id_profesor;

    RETURN QUERY SELECT 'OK'::TEXT, to_jsonb(v_prev);
END;
$$;

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

-- CU 04 - Eliminar profesor: elimina el perfil y su cuenta de usuario en la misma operación (RN-07).
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
