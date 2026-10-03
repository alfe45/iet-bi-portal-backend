-- ============================================================
-- 12_admin_asignaciones.sql: CU 30 a 33 (admin) + consulta de mis asignaciones (profesor).
-- Una asignación = profesor que imparte una asignatura en una sección. Varios profesores pueden
-- compartir la misma asignatura y sección (co-docencia). Se opera SIEMPRE por claves naturales:
-- (año, nivel, número, código de asignatura, cédula del profesor), nunca por id_asignacion.
-- En periodos no finalizados el profesor debe tener usuario activo con rol PROFESOR_REGULAR
-- (AD002); en periodos finalizados no se exige (digitalización).
-- ============================================================
SET search_path = academico, api, auth, public;

CREATE TYPE academico.asignacion_docente AS (
    anio INTEGER,
    nivel SMALLINT,
    numero SMALLINT,
    seccion TEXT,                -- "10-1"
    codigo_asignatura VARCHAR(10),
    asignatura TEXT,
    cedula_profesor VARCHAR(20),
    nombre_profesor TEXT
);

-- ------------------------------------------------------------
-- Helpers
-- ------------------------------------------------------------
-- Vista interna con todo resuelto (una fila por asignación).
CREATE OR REPLACE FUNCTION academico.fn_asignaciones_detalle()
RETURNS TABLE(id_asignacion BIGINT, id_periodo BIGINT, id_profesor BIGINT, id_usuario_profesor UUID,
              fila academico.asignacion_docente)
LANGUAGE sql STABLE
SET search_path = academico, auth, api, public
AS $$
    SELECT a.id_asignacion, s.id_periodo, pr.id_profesor, pr.id_usuario,
           ROW(p.anio, s.nivel, s.numero, s.nivel || '-' || s.numero,
               asg.codigo, asg.nombre::TEXT,
               pr.cedula, concat_ws(' ', pr.nombre, pr.primer_apellido, pr.segundo_apellido))::academico.asignacion_docente
    FROM academico.asignaciones_docentes a
    JOIN academico.secciones s ON s.id_seccion = a.id_seccion
    JOIN academico.periodos_academicos p ON p.id_periodo = s.id_periodo
    JOIN academico.asignaturas asg ON asg.id_asignatura = a.id_asignatura
    JOIN academico.profesores pr ON pr.id_profesor = a.id_profesor;
$$;

-- Id interno del profesor por cédula. NF002 si no existe.
CREATE OR REPLACE FUNCTION academico.fn_obtener_id_profesor(p_cedula TEXT)
RETURNS BIGINT
LANGUAGE plpgsql STABLE
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_id BIGINT;
BEGIN
    SELECT id_profesor INTO v_id FROM academico.profesores WHERE cedula = api.fn_limpiar_cedula(p_cedula);

    IF v_id IS NULL THEN
        PERFORM api.fn_lanzar_excepcion('NF002', 'El profesor no existe.');
    END IF;

    RETURN v_id;
END;
$$;

-- AD002 si el periodo de la sección no está finalizado y el profesor no tiene usuario activo con
-- rol PROFESOR_REGULAR (el front activa el módulo de profesor según ese rol). En la asignatura CAS además
-- debe tener el rol PROFESOR_CAS (RN-82, AD007): asignar CAS es el Administrador CU38.
CREATE OR REPLACE FUNCTION academico.fn_validar_profesor_asignable(p_id_seccion BIGINT, p_id_asignatura BIGINT, p_id_profesor BIGINT)
RETURNS VOID
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_periodo academico.periodos_academicos%ROWTYPE;
BEGIN
    SELECT p.* INTO v_periodo
    FROM academico.periodos_academicos p
    JOIN academico.secciones s ON s.id_periodo = p.id_periodo
    WHERE s.id_seccion = p_id_seccion;

    IF academico.fn_estado_periodo(v_periodo) <> 'FINALIZADO'
       AND NOT academico.fn_profesor_tiene_rol_activo(p_id_profesor, 'PROFESOR_REGULAR') THEN
        PERFORM api.fn_lanzar_excepcion('AD002', 'El profesor debe tener un usuario activo con el rol PROFESOR_REGULAR.');
    END IF;

    IF academico.fn_estado_periodo(v_periodo) <> 'FINALIZADO'
       AND EXISTS (SELECT 1 FROM academico.asignaturas WHERE id_asignatura = p_id_asignatura AND codigo = 'CAS')
       AND NOT academico.fn_profesor_tiene_rol_activo(p_id_profesor, 'PROFESOR_CAS') THEN
        PERFORM api.fn_lanzar_excepcion('AD007', 'Para impartir CAS el profesor debe tener un usuario activo con el rol PROFESOR_CAS.');
    END IF;
END;
$$;

-- Id de la asignación por claves naturales. NF006/NF007/NF002 si no existe una de las partes,
-- NF008 si la asignación no existe.
CREATE OR REPLACE FUNCTION academico.fn_obtener_id_asignacion(
    p_anio INTEGER, p_nivel INTEGER, p_numero INTEGER, p_codigo_asignatura TEXT, p_cedula_profesor TEXT)
RETURNS BIGINT
LANGUAGE plpgsql STABLE
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_id BIGINT;
    v_id_seccion BIGINT := academico.fn_obtener_id_seccion(p_anio, p_nivel, p_numero);
    v_id_asignatura BIGINT := academico.fn_obtener_id_asignatura(p_codigo_asignatura);
    v_id_profesor BIGINT := academico.fn_obtener_id_profesor(p_cedula_profesor);
BEGIN
    SELECT a.id_asignacion INTO v_id
    FROM academico.asignaciones_docentes a
    WHERE a.id_seccion = v_id_seccion AND a.id_asignatura = v_id_asignatura AND a.id_profesor = v_id_profesor;

    IF v_id IS NULL THEN
        PERFORM api.fn_lanzar_excepcion('NF008', 'La asignación no existe.');
    END IF;

    RETURN v_id;
END;
$$;

-- CU 30 - Asignar a un profesor una asignatura en una sección.
CREATE OR REPLACE FUNCTION academico.fn_admin_registrar_asignacion(
    p_id_usuario_actor UUID,
    p_anio INTEGER,
    p_nivel INTEGER,
    p_numero INTEGER,
    p_codigo_asignatura TEXT,
    p_cedula_profesor TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_id_seccion BIGINT;
    v_id_asignatura BIGINT;
    v_id_profesor BIGINT;
BEGIN
    PERFORM api.fn_validar_admin_activo(p_id_usuario_actor);

    v_id_seccion := academico.fn_obtener_id_seccion(p_anio, p_nivel, p_numero);
    v_id_asignatura := academico.fn_obtener_id_asignatura(p_codigo_asignatura);
    v_id_profesor := academico.fn_obtener_id_profesor(p_cedula_profesor);

    -- RN-39: la asignatura se imparte en el nivel de la sección (ej. Cívica no en 11).
    PERFORM academico.fn_validar_asignatura_en_nivel(v_id_asignatura, p_nivel);
    PERFORM academico.fn_validar_profesor_asignable(v_id_seccion, v_id_asignatura, v_id_profesor);

    IF EXISTS (SELECT 1 FROM academico.asignaciones_docentes
               WHERE id_seccion = v_id_seccion AND id_asignatura = v_id_asignatura AND id_profesor = v_id_profesor) THEN
        PERFORM api.fn_lanzar_excepcion('AD001', 'El profesor ya tiene asignada esa asignatura en la sección.');
    END IF;

    INSERT INTO academico.asignaciones_docentes (id_seccion, id_asignatura, id_profesor)
    VALUES (v_id_seccion, v_id_asignatura, v_id_profesor);
END;
$$;

-- CU 31 - Consultar asignaciones. Todos los filtros son opcionales (NULL = todos).
CREATE OR REPLACE FUNCTION academico.fn_admin_listar_asignaciones(p_id_usuario_actor UUID, 
    p_anio INTEGER, p_nivel INTEGER, p_numero INTEGER, p_codigo_asignatura TEXT, p_cedula_profesor TEXT,
    p_pagina INTEGER, p_tamano_pagina INTEGER)
RETURNS SETOF academico.asignacion_docente
LANGUAGE sql STABLE
SET search_path = academico, auth, api, public
AS $$
    SELECT api.fn_validar_admin_activo(p_id_usuario_actor);   -- RP-12 (las lecturas también)
    SELECT (d.fila).*
    FROM academico.fn_asignaciones_detalle() d
    WHERE (p_anio IS NULL OR (d.fila).anio = p_anio)
      AND (p_nivel IS NULL OR (d.fila).nivel = p_nivel)
      AND (p_numero IS NULL OR (d.fila).numero = p_numero)
      AND (p_codigo_asignatura IS NULL OR (d.fila).codigo_asignatura = academico.fn_normalizar_codigo_asignatura(p_codigo_asignatura))
      AND (p_cedula_profesor IS NULL OR (d.fila).cedula_profesor = api.fn_limpiar_cedula(p_cedula_profesor))
    ORDER BY (d.fila).anio DESC, (d.fila).nivel, (d.fila).numero, (d.fila).asignatura, (d.fila).nombre_profesor
    LIMIT api.fn_tamano_pagina(p_tamano_pagina)
    OFFSET api.fn_offset(p_pagina, p_tamano_pagina);
$$;

CREATE OR REPLACE FUNCTION academico.fn_admin_contar_asignaciones(p_id_usuario_actor UUID, 
    p_anio INTEGER, p_nivel INTEGER, p_numero INTEGER, p_codigo_asignatura TEXT, p_cedula_profesor TEXT)
RETURNS BIGINT
LANGUAGE sql STABLE
SET search_path = academico, auth, api, public
AS $$
    SELECT api.fn_validar_admin_activo(p_id_usuario_actor);   -- RP-12 (las lecturas también)
    SELECT COUNT(*)
    FROM academico.fn_asignaciones_detalle() d
    WHERE (p_anio IS NULL OR (d.fila).anio = p_anio)
      AND (p_nivel IS NULL OR (d.fila).nivel = p_nivel)
      AND (p_numero IS NULL OR (d.fila).numero = p_numero)
      AND (p_codigo_asignatura IS NULL OR (d.fila).codigo_asignatura = academico.fn_normalizar_codigo_asignatura(p_codigo_asignatura))
      AND (p_cedula_profesor IS NULL OR (d.fila).cedula_profesor = api.fn_limpiar_cedula(p_cedula_profesor));
$$;

-- CU 32 - Modificar asignación: reemplazar al profesor (ej. sustitución de un docente). Se conserva
-- la asignación para que sus registros futuros (evaluaciones, asistencia) sigan asociados.
-- Devuelve 'OK' o 'SIN_CAMBIOS' y el snapshot previo.
CREATE OR REPLACE FUNCTION academico.fn_admin_cambiar_profesor_asignacion(
    p_id_usuario_actor UUID,
    p_anio INTEGER,
    p_nivel INTEGER,
    p_numero INTEGER,
    p_codigo_asignatura TEXT,
    p_cedula_profesor_actual TEXT,
    p_cedula_profesor_nuevo TEXT
)
RETURNS TABLE(out_status TEXT, out_datos_anteriores JSONB)
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_id_asignacion BIGINT;
    v_asignacion academico.asignaciones_docentes%ROWTYPE;
    v_id_profesor_nuevo BIGINT;
    v_prev JSONB;
BEGIN
    PERFORM api.fn_validar_admin_activo(p_id_usuario_actor);

    v_id_asignacion := academico.fn_obtener_id_asignacion(
        p_anio, p_nivel, p_numero, p_codigo_asignatura, p_cedula_profesor_actual);
    SELECT * INTO v_asignacion FROM academico.asignaciones_docentes WHERE id_asignacion = v_id_asignacion FOR UPDATE;

    v_id_profesor_nuevo := academico.fn_obtener_id_profesor(p_cedula_profesor_nuevo);

    IF v_id_profesor_nuevo = v_asignacion.id_profesor THEN
        RETURN QUERY SELECT 'SIN_CAMBIOS'::TEXT, NULL::JSONB;
        RETURN;
    END IF;

    PERFORM academico.fn_validar_profesor_asignable(v_asignacion.id_seccion, v_asignacion.id_asignatura, v_id_profesor_nuevo);

    IF EXISTS (SELECT 1 FROM academico.asignaciones_docentes
               WHERE id_seccion = v_asignacion.id_seccion AND id_asignatura = v_asignacion.id_asignatura
                 AND id_profesor = v_id_profesor_nuevo) THEN
        PERFORM api.fn_lanzar_excepcion('AD001', 'El profesor ya tiene asignada esa asignatura en la sección.');
    END IF;

    SELECT to_jsonb(d.fila) INTO v_prev FROM academico.fn_asignaciones_detalle() d WHERE d.id_asignacion = v_id_asignacion;

    UPDATE academico.asignaciones_docentes SET id_profesor = v_id_profesor_nuevo WHERE id_asignacion = v_id_asignacion;

    RETURN QUERY SELECT 'OK'::TEXT, v_prev;
END;
$$;

-- CU 33 - Eliminar asignación. Devuelve el snapshot previo. Si otras entidades la referencian
-- (evaluaciones, asistencia) con FK RESTRICT, Postgres lanza 23001.
CREATE OR REPLACE FUNCTION academico.fn_admin_eliminar_asignacion(
    p_id_usuario_actor UUID,
    p_anio INTEGER,
    p_nivel INTEGER,
    p_numero INTEGER,
    p_codigo_asignatura TEXT,
    p_cedula_profesor TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_id_asignacion BIGINT;
    v_prev JSONB;
BEGIN
    PERFORM api.fn_validar_admin_activo(p_id_usuario_actor);

    v_id_asignacion := academico.fn_obtener_id_asignacion(p_anio, p_nivel, p_numero, p_codigo_asignatura, p_cedula_profesor);
    PERFORM 1 FROM academico.asignaciones_docentes WHERE id_asignacion = v_id_asignacion FOR UPDATE;

    SELECT to_jsonb(d.fila) INTO v_prev FROM academico.fn_asignaciones_detalle() d WHERE d.id_asignacion = v_id_asignacion;

    DELETE FROM academico.asignaciones_docentes WHERE id_asignacion = v_id_asignacion;

    RETURN v_prev;
END;
$$;

-- Profesor Regular CU03 - Mis asignaciones (secciones y asignaturas que imparto) en un año.
-- p_anio NULL = periodo en curso (NF005 si no hay). Si el usuario no tiene perfil de profesor,
-- no devuelve filas.
CREATE OR REPLACE FUNCTION academico.fn_profesor_listar_mis_asignaciones(p_id_usuario UUID, p_anio INTEGER)
RETURNS SETOF academico.asignacion_docente
LANGUAGE plpgsql STABLE
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_anio INTEGER := p_anio;
BEGIN
    IF v_anio IS NULL THEN
        SELECT anio INTO v_anio FROM academico.fn_periodo_actual();
        IF v_anio IS NULL THEN
            PERFORM api.fn_lanzar_excepcion('NF005', 'No hay un periodo académico en curso.');
        END IF;
    END IF;

    RETURN QUERY
    SELECT (d.fila).*
    FROM academico.fn_asignaciones_detalle() d
    WHERE d.id_usuario_profesor = p_id_usuario AND (d.fila).anio = v_anio
    ORDER BY (d.fila).nivel, (d.fila).numero, (d.fila).asignatura;
END;
$$;
