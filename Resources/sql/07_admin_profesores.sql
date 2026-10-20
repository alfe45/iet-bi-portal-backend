-- ============================================================
-- 07_admin_profesores.sql: CU 06 a 09. Se opera SIEMPRE por cédula (nunca por id_profesor).
-- La cédula es inmutable: identifica al profesor y no se modifica en CU08.
-- La cuenta de usuario es opcional (RN-05): se crea, vincula o quita desde el mismo profesor.
-- ============================================================
SET search_path = academico, api, auth, public;

CREATE TYPE academico.profesor_admin AS (
    nombre VARCHAR(100),
    primer_apellido VARCHAR(100),
    segundo_apellido VARCHAR(100),
    cedula VARCHAR(20),
    numero_celular VARCHAR(20),
    fecha_nacimiento DATE,
    id_usuario UUID,        -- NULL si no tiene cuenta (RN-05)
    email CITEXT,
    activo BOOLEAN,
    roles api.roles[]       -- vacío si no tiene cuenta
);

-- Interna: crea la cuenta del profesor (p_email + p_password_hash + p_roles) o le vincula un usuario existente
-- (p_id_usuario), nunca las dos cosas (PR006). Sin roles, la cuenta nace con PROFESOR_REGULAR (RN-05).
-- El llamador ya bloqueó al profesor y comprobó que no tiene cuenta. Devuelve el id del usuario.
CREATE OR REPLACE FUNCTION academico.fn_asignar_cuenta_profesor(
    p_id_usuario_actor UUID,
    p_id_profesor BIGINT,
    p_id_usuario UUID,
    p_email TEXT,
    p_password_hash TEXT,
    p_roles TEXT[]
)
RETURNS UUID
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_id UUID := p_id_usuario;
    v_roles api.roles[];
BEGIN
    IF (p_id_usuario IS NULL) = (api.fn_limpiar(p_email) IS NULL) THEN
        PERFORM api.fn_lanzar_excepcion('PR006', 'Indica un usuario existente o los datos de una cuenta nueva, no ambos.');
    END IF;

    IF v_id IS NOT NULL THEN
        IF p_password_hash IS NOT NULL OR cardinality(p_roles) > 0 THEN
            PERFORM api.fn_lanzar_excepcion('PR006', 'Indica un usuario existente o los datos de una cuenta nueva, no ambos.');
        END IF;
        IF NOT EXISTS (SELECT 1 FROM api.usuarios WHERE id_usuario = v_id) THEN
            PERFORM api.fn_lanzar_excepcion('NF001', 'El usuario no existe.');
        END IF;
        IF EXISTS (SELECT 1 FROM academico.profesores WHERE id_usuario = v_id) THEN
            PERFORM api.fn_lanzar_excepcion('PR001', 'El usuario ya tiene un perfil de profesor.');
        END IF;
    ELSE
        -- Roles sin repetir y sin distinguir mayúsculas; un texto que no es rol lo rechaza el cast (22P02 -> 400).
        SELECT COALESCE(array_agg(DISTINCT upper(trim(r))::api.roles ORDER BY upper(trim(r))::api.roles), ARRAY['PROFESOR_REGULAR']::api.roles[])
        INTO v_roles
        FROM unnest(COALESCE(p_roles, ARRAY[]::TEXT[])) r;

        PERFORM auth.fn_validar_rol_unico(NULL, r) FROM unnest(v_roles) r;

        v_id := auth.fn_insertar_usuario(p_email::CITEXT, p_password_hash, v_roles[1], p_id_usuario_actor);

        INSERT INTO api.usuario_roles (id_usuario, rol, asignado_por)
        SELECT v_id, r, p_id_usuario_actor FROM unnest(v_roles[2:]) r;
    END IF;

    UPDATE academico.profesores SET id_usuario = v_id WHERE id_profesor = p_id_profesor;
    RETURN v_id;
END;
$$;

-- CU 06 - Registrar profesor, con cuenta opcional en la misma operación (RN-05): sin datos de cuenta el profesor
-- queda sin usuario; con p_id_usuario se vincula uno existente; con correo + contraseña se crea. Devuelve la cédula.
CREATE OR REPLACE FUNCTION academico.fn_admin_registrar_profesor(
    p_id_usuario_actor UUID,
    p_nombre TEXT,
    p_primer_apellido TEXT,
    p_segundo_apellido TEXT,
    p_cedula TEXT,
    p_numero_celular TEXT,
    p_fecha_nacimiento DATE,
    p_id_usuario UUID,
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

    IF p_id_usuario IS NOT NULL OR api.fn_limpiar(p_email) IS NOT NULL
       OR p_password_hash IS NOT NULL OR cardinality(p_roles) > 0 THEN
        PERFORM academico.fn_asignar_cuenta_profesor(p_id_usuario_actor, v_id, p_id_usuario, p_email, p_password_hash, p_roles);
    END IF;

    RETURN v_cedula;
END;
$$;

-- CU 07 - Consultar profesores (con o sin cuenta).
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

-- CU 06 - Crear o vincular la cuenta de un profesor que no tiene (RN-05). Devuelve el id del usuario.
CREATE OR REPLACE FUNCTION academico.fn_admin_crear_cuenta_profesor(
    p_id_usuario_actor UUID,
    p_cedula TEXT,
    p_id_usuario UUID,
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

    RETURN academico.fn_asignar_cuenta_profesor(p_id_usuario_actor, v_prof.id_profesor, p_id_usuario, p_email, p_password_hash, p_roles);
END;
$$;

-- CU 09 - Quitar la cuenta de un profesor: lo desvincula y elimina el usuario (el profesor y su historial se
-- conservan, RN-07). Mismas protecciones que eliminar usuario (AU012, AU013) y desactivar (AU020: con
-- responsabilidades vigentes primero se reasignan). Devuelve el id, el correo y los roles previos (auditoría).
CREATE OR REPLACE FUNCTION academico.fn_admin_quitar_cuenta_profesor(
    p_id_usuario_actor UUID,
    p_cedula TEXT
)
RETURNS TABLE(out_id_usuario UUID, out_email CITEXT, out_roles api.roles[])
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_prof academico.profesores%ROWTYPE;
    v_email CITEXT;
    v_roles api.roles[];
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
        PERFORM api.fn_lanzar_excepcion('PR008', 'El profesor no tiene cuenta.');
    END IF;

    IF p_id_usuario_actor = v_prof.id_usuario THEN
        PERFORM api.fn_lanzar_excepcion('AU012', 'Un administrador no puede eliminarse a sí mismo.');
    END IF;

    -- RP-57: serializa con quien le asigna algo que exige un rol (fn_profesor_tiene_rol_activo toma FOR SHARE).
    PERFORM api.fn_bloquear_usuario(v_prof.id_usuario, TRUE);

    PERFORM api.fn_validar_no_ultimo_admin(v_prof.id_usuario, 'AU013',
        'No se puede eliminar al último administrador activo del sistema.');

    IF auth.fn_rol_en_uso(v_prof.id_usuario, 'GUIA') OR auth.fn_rol_en_uso(v_prof.id_usuario, 'PROFESOR_REGULAR')
       OR auth.fn_rol_en_uso(v_prof.id_usuario, 'PROFESOR_CAS') OR auth.fn_rol_en_uso(v_prof.id_usuario, 'COORD_MONOGRAFIA') THEN
        PERFORM api.fn_lanzar_excepcion('AU020', 'El usuario tiene secciones, asignaciones o monografías vigentes.');
    END IF;

    SELECT u.email INTO v_email FROM api.usuarios u WHERE u.id_usuario = v_prof.id_usuario;
    v_roles := api.fn_roles_de(v_prof.id_usuario);

    UPDATE academico.profesores SET id_usuario = NULL WHERE id_profesor = v_prof.id_profesor;
    DELETE FROM api.usuarios WHERE id_usuario = v_prof.id_usuario;

    RETURN QUERY SELECT v_prof.id_usuario, v_email, v_roles;
END;
$$;

-- CU 08 - Modificar profesor. Devuelve 'OK' o 'SIN_CAMBIOS' y el snapshot previo (auditoría).
-- Cédula y cuenta no cambian aquí (la cuenta: fn_admin_crear_cuenta_profesor / fn_admin_quitar_cuenta_profesor).
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

-- CU 09 - Eliminar profesor (solo el perfil; el usuario se conserva). Devuelve el snapshot previo.
-- Si otras entidades lo referencian con FK RESTRICT, Postgres lanza 23503.
CREATE OR REPLACE FUNCTION academico.fn_admin_eliminar_profesor(
    p_id_usuario_actor UUID,
    p_cedula TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_id BIGINT;
    v_prev JSONB;
BEGIN
    PERFORM api.fn_validar_admin_activo(p_id_usuario_actor);

    SELECT p.id_profesor, to_jsonb(p) INTO v_id, v_prev
    FROM academico.profesores p
    WHERE p.cedula = api.fn_limpiar_cedula(p_cedula)
    FOR UPDATE;

    IF NOT FOUND THEN
        PERFORM api.fn_lanzar_excepcion('NF002', 'El profesor no existe.');
    END IF;

    IF EXISTS (SELECT 1 FROM academico.secciones WHERE id_profesor_guia = v_id) THEN
        PERFORM api.fn_lanzar_excepcion('PR004', 'El profesor es guía de una sección.');
    END IF;

    DELETE FROM academico.profesores WHERE id_profesor = v_id;

    RETURN v_prev;
END;
$$;
