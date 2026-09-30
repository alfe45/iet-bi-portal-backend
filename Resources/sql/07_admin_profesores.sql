-- ============================================================
-- 07_admin_profesores.sql: CU 06 a 09. Se opera SIEMPRE por cédula (nunca por id_profesor).
-- La cédula es inmutable: identifica al profesor y no se modifica en CU08.
-- ============================================================
SET search_path = academico, api, auth, public;

CREATE TYPE academico.profesor_admin AS (
    nombre VARCHAR(100),
    primer_apellido VARCHAR(100),
    segundo_apellido VARCHAR(100),
    cedula VARCHAR(20),
    numero_celular VARCHAR(20),
    fecha_nacimiento DATE,
    id_usuario UUID,
    email CITEXT
);

-- CU 06 - Registrar profesor (vincula un usuario existente). Devuelve la cédula normalizada.
CREATE OR REPLACE FUNCTION academico.fn_admin_registrar_profesor(
    p_id_usuario_actor UUID,
    p_id_usuario UUID,
    p_nombre TEXT,
    p_primer_apellido TEXT,
    p_segundo_apellido TEXT,
    p_cedula TEXT,
    p_numero_celular TEXT,
    p_fecha_nacimiento DATE
)
RETURNS TEXT
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_cedula TEXT := api.fn_limpiar(p_cedula);
BEGIN
    PERFORM api.fn_validar_admin_activo(p_id_usuario_actor);

    IF NOT EXISTS (SELECT 1 FROM api.usuarios WHERE id_usuario = p_id_usuario) THEN
        PERFORM api.fn_lanzar_excepcion('NF001', 'El usuario no existe.');
    END IF;

    IF EXISTS (SELECT 1 FROM academico.profesores WHERE id_usuario = p_id_usuario) THEN
        PERFORM api.fn_lanzar_excepcion('PR001', 'El usuario ya tiene un perfil de profesor.');
    END IF;

    IF EXISTS (SELECT 1 FROM academico.profesores WHERE cedula = v_cedula) THEN
        PERFORM api.fn_lanzar_excepcion('PR002', 'Ya existe un profesor con esa cédula.');
    END IF;

    PERFORM api.fn_validar_fecha_nacimiento(p_fecha_nacimiento, 'PR005');

    INSERT INTO academico.profesores (
        nombre, primer_apellido, segundo_apellido, cedula, numero_celular, fecha_nacimiento, id_usuario)
    VALUES (
        api.fn_limpiar(p_nombre), api.fn_limpiar(p_primer_apellido), api.fn_limpiar(p_segundo_apellido),
        v_cedula, api.fn_limpiar(p_numero_celular), p_fecha_nacimiento, p_id_usuario);

    RETURN v_cedula;
END;
$$;

-- CU 07 - Consultar profesores
-- Búsqueda opcional por nombre, apellidos, cédula o correo (sin mayúsculas ni acentos).
CREATE OR REPLACE FUNCTION academico.fn_admin_listar_profesores(p_busqueda TEXT, p_pagina INTEGER, p_tamano_pagina INTEGER)
RETURNS SETOF academico.profesor_admin
LANGUAGE sql STABLE
SET search_path = academico, auth, api, public
AS $$
    SELECT p.nombre, p.primer_apellido, p.segundo_apellido, p.cedula,
           p.numero_celular, p.fecha_nacimiento, p.id_usuario, u.email
    FROM academico.profesores p
    JOIN api.usuarios u ON u.id_usuario = p.id_usuario
    WHERE api.fn_coincide(concat_ws(' ', p.nombre, p.primer_apellido, p.segundo_apellido, p.cedula, u.email), p_busqueda)
    ORDER BY p.primer_apellido, p.segundo_apellido NULLS LAST, p.nombre, p.cedula
    LIMIT api.fn_tamano_pagina(p_tamano_pagina)
    OFFSET api.fn_offset(p_pagina, p_tamano_pagina);
$$;

CREATE OR REPLACE FUNCTION academico.fn_admin_contar_profesores(p_busqueda TEXT)
RETURNS BIGINT
LANGUAGE sql STABLE
SET search_path = academico, auth, api, public
AS $$
    SELECT COUNT(*)
    FROM academico.profesores p
    JOIN api.usuarios u ON u.id_usuario = p.id_usuario
    WHERE api.fn_coincide(concat_ws(' ', p.nombre, p.primer_apellido, p.segundo_apellido, p.cedula, u.email), p_busqueda);
$$;

CREATE OR REPLACE FUNCTION academico.fn_admin_obtener_profesor(p_cedula TEXT)
RETURNS SETOF academico.profesor_admin
LANGUAGE sql STABLE
SET search_path = academico, auth, api, public
AS $$
    SELECT p.nombre, p.primer_apellido, p.segundo_apellido, p.cedula,
           p.numero_celular, p.fecha_nacimiento, p.id_usuario, u.email
    FROM academico.profesores p
    JOIN api.usuarios u ON u.id_usuario = p.id_usuario
    WHERE p.cedula = api.fn_limpiar(p_cedula);
$$;

-- CU 08 - Modificar profesor. Devuelve 'OK' o 'SIN_CAMBIOS' y el snapshot previo (auditoría).
-- Cédula y usuario vinculado no cambian.
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
    WHERE p.cedula = api.fn_limpiar(p_cedula)
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
    WHERE p.cedula = api.fn_limpiar(p_cedula)
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
