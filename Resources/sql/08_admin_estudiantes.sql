-- ============================================================
-- 08_admin_estudiantes.sql: CU 10 a 13. Se opera SIEMPRE por cédula (nunca por id_estudiante).
-- La cédula es inmutable. La edad (RN-01) NO se valida aquí sino al matricular, contra el inicio del
-- periodo de la matrícula: así se pueden digitalizar estudiantes de periodos pasados.
-- ============================================================
SET search_path = academico, api, auth, public;

CREATE TYPE academico.estudiante_admin AS (
    nombre VARCHAR(100),
    primer_apellido VARCHAR(100),
    segundo_apellido VARCHAR(100),
    cedula VARCHAR(20),
    numero_celular VARCHAR(20),
    email CITEXT,
    fecha_nacimiento DATE,
    fecha_registro TIMESTAMPTZ
);

-- RN-01: a la fecha de referencia (inicio del periodo de la matrícula) el estudiante tiene 16 años
-- cumplidos y menos de 20. La usa el módulo de matrículas.
CREATE OR REPLACE FUNCTION academico.fn_validar_edad_estudiante(p_fecha_nacimiento DATE, p_fecha_referencia DATE)
RETURNS VOID
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
BEGIN
    IF p_fecha_nacimiento IS NULL
        OR p_fecha_nacimiento >  (p_fecha_referencia - INTERVAL '16 years')::DATE
        OR p_fecha_nacimiento <= (p_fecha_referencia - INTERVAL '20 years')::DATE
    THEN
        PERFORM api.fn_lanzar_excepcion('ES003', 'El estudiante debe tener entre 16 y 19 años.');
    END IF;
END;
$$;

-- Id interno del estudiante por cédula (para FKs de otros módulos, ej. matrículas). NF003 si no existe.
CREATE OR REPLACE FUNCTION academico.fn_obtener_id_estudiante(p_cedula TEXT)
RETURNS BIGINT
LANGUAGE plpgsql STABLE
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_id BIGINT;
BEGIN
    SELECT id_estudiante INTO v_id FROM academico.estudiantes WHERE cedula = api.fn_limpiar(p_cedula);

    IF v_id IS NULL THEN
        PERFORM api.fn_lanzar_excepcion('NF003', 'El estudiante no existe.');
    END IF;

    RETURN v_id;
END;
$$;

-- CU 10 - Registrar estudiante. Devuelve la cédula normalizada.
CREATE OR REPLACE FUNCTION academico.fn_admin_registrar_estudiante(
    p_id_usuario_actor UUID,
    p_nombre TEXT,
    p_primer_apellido TEXT,
    p_segundo_apellido TEXT,
    p_cedula TEXT,
    p_numero_celular TEXT,
    p_email CITEXT,
    p_fecha_nacimiento DATE
)
RETURNS TEXT
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_cedula TEXT := api.fn_limpiar(p_cedula);
    v_email CITEXT := api.fn_limpiar(p_email::TEXT)::CITEXT;
BEGIN
    PERFORM api.fn_validar_admin_activo(p_id_usuario_actor);
    PERFORM api.fn_validar_fecha_nacimiento(p_fecha_nacimiento, 'ES004');

    IF EXISTS (SELECT 1 FROM academico.estudiantes WHERE cedula = v_cedula) THEN
        PERFORM api.fn_lanzar_excepcion('ES001', 'Ya existe un estudiante con esa cédula.');
    END IF;

    IF EXISTS (SELECT 1 FROM academico.estudiantes WHERE email = v_email) THEN
        PERFORM api.fn_lanzar_excepcion('ES002', 'Ya existe un estudiante con ese correo.');
    END IF;

    INSERT INTO academico.estudiantes (
        nombre, primer_apellido, segundo_apellido, cedula, numero_celular, email, fecha_nacimiento)
    VALUES (
        api.fn_limpiar(p_nombre), api.fn_limpiar(p_primer_apellido), api.fn_limpiar(p_segundo_apellido),
        v_cedula, api.fn_limpiar(p_numero_celular), v_email, p_fecha_nacimiento);

    RETURN v_cedula;
END;
$$;

-- CU 11 - Consultar estudiantes
-- Búsqueda opcional por nombre, apellidos, cédula o correo (sin mayúsculas ni acentos).
CREATE OR REPLACE FUNCTION academico.fn_admin_listar_estudiantes(p_busqueda TEXT, p_pagina INTEGER, p_tamano_pagina INTEGER)
RETURNS SETOF academico.estudiante_admin
LANGUAGE sql STABLE
SET search_path = academico, auth, api, public
AS $$
    SELECT e.nombre, e.primer_apellido, e.segundo_apellido, e.cedula,
           e.numero_celular, e.email, e.fecha_nacimiento, e.fecha_registro
    FROM academico.estudiantes e
    WHERE api.fn_coincide(concat_ws(' ', e.nombre, e.primer_apellido, e.segundo_apellido, e.cedula, e.email), p_busqueda)
    ORDER BY e.primer_apellido, e.segundo_apellido NULLS LAST, e.nombre, e.cedula
    LIMIT api.fn_tamano_pagina(p_tamano_pagina)
    OFFSET api.fn_offset(p_pagina, p_tamano_pagina);
$$;

CREATE OR REPLACE FUNCTION academico.fn_admin_contar_estudiantes(p_busqueda TEXT)
RETURNS BIGINT
LANGUAGE sql STABLE
SET search_path = academico, auth, api, public
AS $$
    SELECT COUNT(*)
    FROM academico.estudiantes e
    WHERE api.fn_coincide(concat_ws(' ', e.nombre, e.primer_apellido, e.segundo_apellido, e.cedula, e.email), p_busqueda);
$$;

CREATE OR REPLACE FUNCTION academico.fn_admin_obtener_estudiante(p_cedula TEXT)
RETURNS SETOF academico.estudiante_admin
LANGUAGE sql STABLE
SET search_path = academico, auth, api, public
AS $$
    SELECT e.nombre, e.primer_apellido, e.segundo_apellido, e.cedula,
           e.numero_celular, e.email, e.fecha_nacimiento, e.fecha_registro
    FROM academico.estudiantes e
    WHERE e.cedula = api.fn_limpiar(p_cedula);
$$;

-- CU 12 - Modificar estudiante. La fecha de nacimiento solo se revalida (ES004) si cambia; la edad se valida al matricular.
CREATE OR REPLACE FUNCTION academico.fn_admin_actualizar_estudiante(
    p_id_usuario_actor UUID,
    p_cedula TEXT,
    p_nombre TEXT,
    p_primer_apellido TEXT,
    p_segundo_apellido TEXT,
    p_numero_celular TEXT,
    p_email CITEXT,
    p_fecha_nacimiento DATE
)
RETURNS TABLE(out_status TEXT, out_datos_anteriores JSONB)
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_prev academico.estudiantes%ROWTYPE;
    v_nuevo academico.estudiantes%ROWTYPE;
BEGIN
    PERFORM api.fn_validar_admin_activo(p_id_usuario_actor);

    SELECT * INTO v_prev
    FROM academico.estudiantes e
    WHERE e.cedula = api.fn_limpiar(p_cedula)
    FOR UPDATE;

    IF NOT FOUND THEN
        PERFORM api.fn_lanzar_excepcion('NF003', 'El estudiante no existe.');
    END IF;

    v_nuevo := v_prev;
    v_nuevo.nombre := api.fn_limpiar(p_nombre);
    v_nuevo.primer_apellido := api.fn_limpiar(p_primer_apellido);
    v_nuevo.segundo_apellido := api.fn_limpiar(p_segundo_apellido);
    v_nuevo.numero_celular := api.fn_limpiar(p_numero_celular);
    v_nuevo.email := api.fn_limpiar(p_email::TEXT)::CITEXT;
    v_nuevo.fecha_nacimiento := p_fecha_nacimiento;

    IF v_nuevo.fecha_nacimiento IS DISTINCT FROM v_prev.fecha_nacimiento THEN
        PERFORM api.fn_validar_fecha_nacimiento(v_nuevo.fecha_nacimiento, 'ES004');
    END IF;

    IF EXISTS (SELECT 1 FROM academico.estudiantes
               WHERE email = v_nuevo.email AND id_estudiante <> v_prev.id_estudiante) THEN
        PERFORM api.fn_lanzar_excepcion('ES002', 'Ya existe un estudiante con ese correo.');
    END IF;

    IF v_nuevo IS NOT DISTINCT FROM v_prev THEN
        RETURN QUERY SELECT 'SIN_CAMBIOS'::TEXT, NULL::JSONB;
        RETURN;
    END IF;

    UPDATE academico.estudiantes
    SET nombre = v_nuevo.nombre,
        primer_apellido = v_nuevo.primer_apellido,
        segundo_apellido = v_nuevo.segundo_apellido,
        numero_celular = v_nuevo.numero_celular,
        email = v_nuevo.email,
        fecha_nacimiento = v_nuevo.fecha_nacimiento
    WHERE id_estudiante = v_prev.id_estudiante;

    RETURN QUERY SELECT 'OK'::TEXT, to_jsonb(v_prev);
END;
$$;

-- CU 13 - Eliminar estudiante (borrado físico; devuelve snapshot para auditoría).
CREATE OR REPLACE FUNCTION academico.fn_admin_eliminar_estudiante(
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

    SELECT e.id_estudiante, to_jsonb(e) INTO v_id, v_prev
    FROM academico.estudiantes e
    WHERE e.cedula = api.fn_limpiar(p_cedula)
    FOR UPDATE;

    IF NOT FOUND THEN
        PERFORM api.fn_lanzar_excepcion('NF003', 'El estudiante no existe.');
    END IF;

    DELETE FROM academico.estudiantes WHERE id_estudiante = v_id;

    RETURN v_prev;
END;
$$;
