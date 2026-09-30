-- ============================================================
-- 13_admin_matriculas.sql: CU 25 a 28 (admin) + estudiantes de una sección (profesor/guía).
-- Una matrícula por estudiante y periodo; se identifica por (año, cédula del estudiante).
-- El estado se deriva: RETIRADA si tiene retiro; si no PROGRAMADA / ACTIVA / FINALIZADA según el periodo.
-- El ADMIN puede matricular en periodos pasados (digitalización).
-- ============================================================
SET search_path = academico, api, auth, public;

CREATE TYPE academico.matricula_detalle AS (
    anio INTEGER,
    nivel SMALLINT,
    numero SMALLINT,
    seccion TEXT,                -- "10-1"
    cedula_estudiante VARCHAR(20),
    nombre_estudiante TEXT,      -- "Apellido1 Apellido2, Nombre"
    fecha_matricula DATE,
    estado academico.estado_matricula,
    fecha_retiro DATE,
    motivo_retiro VARCHAR(255)
);

-- ------------------------------------------------------------
-- Helpers
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION academico.fn_estado_matricula(p_fecha_retiro DATE, p_periodo academico.periodos_academicos)
RETURNS academico.estado_matricula
LANGUAGE sql STABLE
SET search_path = academico, auth, api, public
AS $$
    SELECT CASE
        WHEN p_fecha_retiro IS NOT NULL THEN 'RETIRADA'
        ELSE CASE academico.fn_estado_periodo(p_periodo)
                 WHEN 'PROGRAMADO' THEN 'PROGRAMADA'
                 WHEN 'EN_CURSO' THEN 'ACTIVA'
                 ELSE 'FINALIZADA'
             END
    END::academico.estado_matricula;
$$;

-- Todas las matrículas con sus datos resueltos (una fila por matrícula).
CREATE OR REPLACE FUNCTION academico.fn_matriculas_detalle()
RETURNS TABLE(id_matricula BIGINT, id_seccion BIGINT, apellidos_nombre TEXT, fila academico.matricula_detalle)
LANGUAGE sql STABLE
SET search_path = academico, auth, api, public
AS $$
    SELECT m.id_matricula, m.id_seccion,
           concat_ws(' ', e.primer_apellido, e.segundo_apellido, e.nombre),
           ROW(p.anio, s.nivel, s.numero, s.nivel || '-' || s.numero,
               e.cedula, concat_ws(' ', e.primer_apellido, e.segundo_apellido) || ', ' || e.nombre,
               m.fecha_matricula, academico.fn_estado_matricula(m.fecha_retiro, p),
               m.fecha_retiro, m.motivo_retiro)::academico.matricula_detalle
    FROM academico.matriculas m
    JOIN academico.estudiantes e ON e.id_estudiante = m.id_estudiante
    JOIN academico.secciones s ON s.id_seccion = m.id_seccion
    JOIN academico.periodos_academicos p ON p.id_periodo = m.id_periodo;
$$;

-- Id de la matrícula por (año, cédula). NF004 periodo, NF003 estudiante, NF009 matrícula.
CREATE OR REPLACE FUNCTION academico.fn_obtener_id_matricula(p_anio INTEGER, p_cedula_estudiante TEXT)
RETURNS BIGINT
LANGUAGE plpgsql STABLE
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_id BIGINT;
    v_id_periodo BIGINT;
    v_id_estudiante BIGINT := academico.fn_obtener_id_estudiante(p_cedula_estudiante);
BEGIN
    SELECT id_periodo INTO v_id_periodo FROM academico.periodos_academicos WHERE anio = p_anio;
    IF v_id_periodo IS NULL THEN
        PERFORM api.fn_lanzar_excepcion('NF004', 'El periodo académico no existe.');
    END IF;

    SELECT m.id_matricula INTO v_id
    FROM academico.matriculas m
    WHERE m.id_periodo = v_id_periodo AND m.id_estudiante = v_id_estudiante;

    IF v_id IS NULL THEN
        PERFORM api.fn_lanzar_excepcion('NF009', 'La matrícula no existe.');
    END IF;

    RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION academico.fn_snapshot_matricula(p_id_matricula BIGINT)
RETURNS JSONB
LANGUAGE sql STABLE
SET search_path = academico, auth, api, public
AS $$
    SELECT to_jsonb(d.fila) FROM academico.fn_matriculas_detalle() d WHERE d.id_matricula = p_id_matricula;
$$;

-- CU 25 - Matricular estudiante en una sección. p_fecha_matricula NULL = hoy (o el inicio del periodo
-- si ya finalizó). Reglas: una matrícula por periodo (MA001), edad 16-19 al inicio del periodo (ES003),
-- fecha de matrícula ni futura ni posterior al fin del periodo ni más de un año antes de su inicio (MA002).
CREATE OR REPLACE FUNCTION academico.fn_admin_registrar_matricula(
    p_id_usuario_actor UUID,
    p_anio INTEGER,
    p_nivel INTEGER,
    p_numero INTEGER,
    p_cedula_estudiante TEXT,
    p_fecha_matricula DATE
)
RETURNS VOID
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_id_seccion BIGINT;
    v_periodo academico.periodos_academicos%ROWTYPE;
    v_estudiante academico.estudiantes%ROWTYPE;
    v_fecha DATE;
BEGIN
    PERFORM api.fn_validar_admin_activo(p_id_usuario_actor);

    v_id_seccion := academico.fn_obtener_id_seccion(p_anio, p_nivel, p_numero);
    SELECT p.* INTO v_periodo
    FROM academico.periodos_academicos p JOIN academico.secciones s ON s.id_periodo = p.id_periodo
    WHERE s.id_seccion = v_id_seccion;

    v_estudiante.id_estudiante := academico.fn_obtener_id_estudiante(p_cedula_estudiante);
    SELECT * INTO v_estudiante FROM academico.estudiantes WHERE id_estudiante = v_estudiante.id_estudiante;

    IF EXISTS (SELECT 1 FROM academico.matriculas
               WHERE id_estudiante = v_estudiante.id_estudiante AND id_periodo = v_periodo.id_periodo) THEN
        PERFORM api.fn_lanzar_excepcion('MA001', 'El estudiante ya está matriculado en ese periodo.');
    END IF;

    -- RN-01: edad a la fecha de inicio del periodo de la matrícula.
    PERFORM academico.fn_validar_edad_estudiante(v_estudiante.fecha_nacimiento, v_periodo.inicio_semestre_i);

    v_fecha := COALESCE(p_fecha_matricula,
        CASE WHEN academico.fn_estado_periodo(v_periodo) = 'FINALIZADO' THEN v_periodo.inicio_semestre_i ELSE api.fn_hoy() END);

    IF v_fecha > api.fn_hoy() OR v_fecha > v_periodo.fin_semestre_ii
       OR v_fecha < (v_periodo.inicio_semestre_i - INTERVAL '1 year')::DATE THEN
        PERFORM api.fn_lanzar_excepcion('MA002', 'La fecha de matrícula no es válida.');
    END IF;

    INSERT INTO academico.matriculas (id_estudiante, id_periodo, id_seccion, fecha_matricula)
    VALUES (v_estudiante.id_estudiante, v_periodo.id_periodo, v_id_seccion, v_fecha);
END;
$$;

-- CU 27 - Consultar matrículas / historial. Filtros opcionales (NULL = todos): año, nivel, número de
-- sección, cédula del estudiante (historial), estado y búsqueda por nombre o cédula.
CREATE OR REPLACE FUNCTION academico.fn_matriculas_filtradas(
    p_anio INTEGER, p_nivel INTEGER, p_numero INTEGER, p_cedula_estudiante TEXT,
    p_estado academico.estado_matricula, p_busqueda TEXT)
RETURNS TABLE(apellidos_nombre TEXT, fila academico.matricula_detalle)
LANGUAGE sql STABLE
SET search_path = academico, auth, api, public
AS $$
    SELECT d.apellidos_nombre, d.fila
    FROM academico.fn_matriculas_detalle() d
    WHERE (p_anio IS NULL OR (d.fila).anio = p_anio)
      AND (p_nivel IS NULL OR (d.fila).nivel = p_nivel)
      AND (p_numero IS NULL OR (d.fila).numero = p_numero)
      AND (p_cedula_estudiante IS NULL OR (d.fila).cedula_estudiante = api.fn_limpiar(p_cedula_estudiante))
      AND (p_estado IS NULL OR (d.fila).estado = p_estado)
      AND api.fn_coincide(d.apellidos_nombre || ' ' || (d.fila).cedula_estudiante, p_busqueda);
$$;

CREATE OR REPLACE FUNCTION academico.fn_admin_listar_matriculas(
    p_anio INTEGER, p_nivel INTEGER, p_numero INTEGER, p_cedula_estudiante TEXT,
    p_estado academico.estado_matricula, p_busqueda TEXT, p_pagina INTEGER, p_tamano_pagina INTEGER)
RETURNS SETOF academico.matricula_detalle
LANGUAGE sql STABLE
SET search_path = academico, auth, api, public
AS $$
    SELECT (f.fila).*
    FROM academico.fn_matriculas_filtradas(p_anio, p_nivel, p_numero, p_cedula_estudiante, p_estado, p_busqueda) f
    ORDER BY (f.fila).anio DESC, (f.fila).nivel, (f.fila).numero, f.apellidos_nombre
    LIMIT api.fn_tamano_pagina(p_tamano_pagina)
    OFFSET api.fn_offset(p_pagina, p_tamano_pagina);
$$;

CREATE OR REPLACE FUNCTION academico.fn_admin_contar_matriculas(
    p_anio INTEGER, p_nivel INTEGER, p_numero INTEGER, p_cedula_estudiante TEXT,
    p_estado academico.estado_matricula, p_busqueda TEXT)
RETURNS BIGINT
LANGUAGE sql STABLE
SET search_path = academico, auth, api, public
AS $$
    SELECT COUNT(*)
    FROM academico.fn_matriculas_filtradas(p_anio, p_nivel, p_numero, p_cedula_estudiante, p_estado, p_busqueda);
$$;

CREATE OR REPLACE FUNCTION academico.fn_admin_obtener_matricula(p_anio INTEGER, p_cedula_estudiante TEXT)
RETURNS SETOF academico.matricula_detalle
LANGUAGE sql STABLE
SET search_path = academico, auth, api, public
AS $$
    SELECT (f.fila).*
    FROM academico.fn_matriculas_filtradas(p_anio, NULL, NULL, p_cedula_estudiante, NULL, NULL) f;
$$;

-- CU 26 - Modificar matrícula: cambiar de sección dentro del mismo periodo (traslado).
-- Devuelve 'OK' o 'SIN_CAMBIOS' y el snapshot previo.
CREATE OR REPLACE FUNCTION academico.fn_admin_cambiar_seccion_matricula(
    p_id_usuario_actor UUID,
    p_anio INTEGER,
    p_cedula_estudiante TEXT,
    p_nivel INTEGER,
    p_numero INTEGER
)
RETURNS TABLE(out_status TEXT, out_datos_anteriores JSONB)
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_id_matricula BIGINT;
    v_matricula academico.matriculas%ROWTYPE;
    v_id_seccion_nueva BIGINT;
    v_prev JSONB;
BEGIN
    PERFORM api.fn_validar_admin_activo(p_id_usuario_actor);

    v_id_matricula := academico.fn_obtener_id_matricula(p_anio, p_cedula_estudiante);
    SELECT * INTO v_matricula FROM academico.matriculas WHERE id_matricula = v_id_matricula FOR UPDATE;

    -- La sección se busca en el mismo año: la matrícula no cambia de periodo.
    v_id_seccion_nueva := academico.fn_obtener_id_seccion(p_anio, p_nivel, p_numero);

    IF v_id_seccion_nueva = v_matricula.id_seccion THEN
        RETURN QUERY SELECT 'SIN_CAMBIOS'::TEXT, NULL::JSONB;
        RETURN;
    END IF;

    v_prev := academico.fn_snapshot_matricula(v_id_matricula);

    UPDATE academico.matriculas SET id_seccion = v_id_seccion_nueva WHERE id_matricula = v_id_matricula;

    RETURN QUERY SELECT 'OK'::TEXT, v_prev;
END;
$$;

-- CU 26 - Modificar matrícula: registrar o corregir el retiro del estudiante. La fecha no puede ser
-- futura, anterior a la matrícula ni posterior al fin del periodo (MA003).
CREATE OR REPLACE FUNCTION academico.fn_admin_registrar_retiro_matricula(
    p_id_usuario_actor UUID,
    p_anio INTEGER,
    p_cedula_estudiante TEXT,
    p_fecha_retiro DATE,
    p_motivo TEXT
)
RETURNS TABLE(out_status TEXT, out_datos_anteriores JSONB)
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_id_matricula BIGINT;
    v_matricula academico.matriculas%ROWTYPE;
    v_fin_periodo DATE;
    v_motivo TEXT := api.fn_limpiar(p_motivo);
    v_prev JSONB;
BEGIN
    PERFORM api.fn_validar_admin_activo(p_id_usuario_actor);

    v_id_matricula := academico.fn_obtener_id_matricula(p_anio, p_cedula_estudiante);
    SELECT * INTO v_matricula FROM academico.matriculas WHERE id_matricula = v_id_matricula FOR UPDATE;
    SELECT fin_semestre_ii INTO v_fin_periodo FROM academico.periodos_academicos WHERE id_periodo = v_matricula.id_periodo;

    IF p_fecha_retiro IS NULL OR p_fecha_retiro > api.fn_hoy()
       OR p_fecha_retiro < v_matricula.fecha_matricula OR p_fecha_retiro > v_fin_periodo THEN
        PERFORM api.fn_lanzar_excepcion('MA003', 'La fecha de retiro no es válida.');
    END IF;

    IF (v_matricula.fecha_retiro, v_matricula.motivo_retiro) IS NOT DISTINCT FROM (p_fecha_retiro, v_motivo) THEN
        RETURN QUERY SELECT 'SIN_CAMBIOS'::TEXT, NULL::JSONB;
        RETURN;
    END IF;

    v_prev := academico.fn_snapshot_matricula(v_id_matricula);

    UPDATE academico.matriculas SET fecha_retiro = p_fecha_retiro, motivo_retiro = v_motivo
    WHERE id_matricula = v_id_matricula;

    RETURN QUERY SELECT 'OK'::TEXT, v_prev;
END;
$$;

-- CU 26 - Modificar matrícula: anular el retiro (reingreso o corrección). 'SIN_CAMBIOS' si no tenía.
CREATE OR REPLACE FUNCTION academico.fn_admin_anular_retiro_matricula(
    p_id_usuario_actor UUID,
    p_anio INTEGER,
    p_cedula_estudiante TEXT
)
RETURNS TABLE(out_status TEXT, out_datos_anteriores JSONB)
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_id_matricula BIGINT;
    v_matricula academico.matriculas%ROWTYPE;
    v_prev JSONB;
BEGIN
    PERFORM api.fn_validar_admin_activo(p_id_usuario_actor);

    v_id_matricula := academico.fn_obtener_id_matricula(p_anio, p_cedula_estudiante);
    SELECT * INTO v_matricula FROM academico.matriculas WHERE id_matricula = v_id_matricula FOR UPDATE;

    IF v_matricula.fecha_retiro IS NULL THEN
        RETURN QUERY SELECT 'SIN_CAMBIOS'::TEXT, NULL::JSONB;
        RETURN;
    END IF;

    v_prev := academico.fn_snapshot_matricula(v_id_matricula);

    UPDATE academico.matriculas SET fecha_retiro = NULL, motivo_retiro = NULL WHERE id_matricula = v_id_matricula;

    RETURN QUERY SELECT 'OK'::TEXT, v_prev;
END;
$$;

-- CU 28 - Eliminar matrícula (corrección de errores). Devuelve el snapshot previo. Si otras entidades
-- la referencian (evaluaciones, asistencia) con FK RESTRICT, Postgres lanza 23001.
CREATE OR REPLACE FUNCTION academico.fn_admin_eliminar_matricula(
    p_id_usuario_actor UUID,
    p_anio INTEGER,
    p_cedula_estudiante TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_id_matricula BIGINT;
    v_prev JSONB;
BEGIN
    PERFORM api.fn_validar_admin_activo(p_id_usuario_actor);

    v_id_matricula := academico.fn_obtener_id_matricula(p_anio, p_cedula_estudiante);
    PERFORM 1 FROM academico.matriculas WHERE id_matricula = v_id_matricula FOR UPDATE;

    v_prev := academico.fn_snapshot_matricula(v_id_matricula);
    DELETE FROM academico.matriculas WHERE id_matricula = v_id_matricula;

    RETURN v_prev;
END;
$$;

-- Profesor Regular CU04 / Guía CU02 - Estudiantes de una sección. Solo si el usuario imparte alguna
-- asignatura en la sección o es su guía (AD003); protege los datos de los estudiantes (Ley 8968).
CREATE OR REPLACE FUNCTION academico.fn_profesor_listar_estudiantes_seccion(
    p_id_usuario UUID, p_anio INTEGER, p_nivel INTEGER, p_numero INTEGER)
RETURNS SETOF academico.matricula_detalle
LANGUAGE plpgsql STABLE
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_id_seccion BIGINT := academico.fn_obtener_id_seccion(p_anio, p_nivel, p_numero);
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM academico.asignaciones_docentes a
        JOIN academico.profesores pr ON pr.id_profesor = a.id_profesor
        WHERE a.id_seccion = v_id_seccion AND pr.id_usuario = p_id_usuario
        UNION ALL
        SELECT 1 FROM academico.secciones s
        JOIN academico.profesores pr ON pr.id_profesor = s.id_profesor_guia
        WHERE s.id_seccion = v_id_seccion AND pr.id_usuario = p_id_usuario
    ) THEN
        PERFORM api.fn_lanzar_excepcion('AD003', 'No tienes acceso a esa sección.');
    END IF;

    RETURN QUERY
    SELECT (d.fila).*
    FROM academico.fn_matriculas_detalle() d
    WHERE d.id_seccion = v_id_seccion
    ORDER BY d.apellidos_nombre;
END;
$$;
