-- ============================================================
-- 13_admin_matriculas.sql: CU 22 a 25 (admin) + estudiantes de una sección y ficha del estudiante (profesor/guía).
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

-- BI es un programa de dos años: nivel 10 y luego nivel 11 con el mismo número de sección (la sección
-- completa sube de nivel). TRUE si la matrícula es de nivel 10 y el estudiante ya tiene la de nivel 11
-- del año siguiente (su continuidad).
CREATE OR REPLACE FUNCTION academico.fn_matricula_tiene_continuidad(p_id_matricula BIGINT)
RETURNS BOOLEAN
LANGUAGE sql STABLE
SET search_path = academico, auth, api, public
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM academico.matriculas m
        JOIN academico.secciones s ON s.id_seccion = m.id_seccion AND s.nivel = 10
        JOIN academico.periodos_academicos p ON p.id_periodo = m.id_periodo
        JOIN academico.matriculas m11 ON m11.id_estudiante = m.id_estudiante
        JOIN academico.secciones s11 ON s11.id_seccion = m11.id_seccion AND s11.nivel = 11
        JOIN academico.periodos_academicos p11 ON p11.id_periodo = m11.id_periodo AND p11.anio = p.anio + 1
        WHERE m.id_matricula = p_id_matricula
    );
$$;

-- MA007 si la matrícula de nivel 10 ya tiene continuidad en nivel 11 (no se retira ni se elimina).
CREATE OR REPLACE FUNCTION academico.fn_validar_sin_continuidad(p_id_matricula BIGINT)
RETURNS VOID
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
BEGIN
    IF academico.fn_matricula_tiene_continuidad(p_id_matricula) THEN
        PERFORM api.fn_lanzar_excepcion('MA007', 'La matrícula de nivel 10 ya tiene continuidad en nivel 11.');
    END IF;
END;
$$;

-- TRUE si la matrícula tiene ausencias (o tardías), notas o informes CAS. plpgsql: las tablas se crean en 06 pero la
-- función se usa también desde módulos posteriores (RP-50).
CREATE OR REPLACE FUNCTION academico.fn_matricula_tiene_registros(p_id_matricula BIGINT)
RETURNS BOOLEAN
LANGUAGE plpgsql STABLE
SET search_path = academico, auth, api, public
AS $$
BEGIN
    RETURN EXISTS (SELECT 1 FROM academico.ausencias WHERE id_matricula = p_id_matricula)
        OR EXISTS (SELECT 1 FROM academico.evaluaciones WHERE id_matricula = p_id_matricula)
        OR EXISTS (SELECT 1 FROM academico.informes_cas WHERE id_matricula = p_id_matricula);
END;
$$;

CREATE OR REPLACE FUNCTION academico.fn_snapshot_matricula(p_id_matricula BIGINT)
RETURNS JSONB
LANGUAGE sql STABLE
SET search_path = academico, auth, api, public
AS $$
    SELECT to_jsonb(d.fila) FROM academico.fn_matriculas_detalle() d WHERE d.id_matricula = p_id_matricula;
$$;

-- Fecha de matrícula efectiva: p_fecha NULL = hoy (o el inicio del periodo si ya finalizó). MA002 si es
-- futura, posterior al fin del periodo o más de un año anterior a su inicio.
CREATE OR REPLACE FUNCTION academico.fn_validar_fecha_matricula(p_periodo academico.periodos_academicos, p_fecha DATE)
RETURNS DATE
LANGUAGE plpgsql STABLE
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_fecha DATE := COALESCE(p_fecha,
        CASE WHEN academico.fn_estado_periodo(p_periodo) = 'FINALIZADO' THEN p_periodo.inicio_semestre_i ELSE api.fn_hoy() END);
BEGIN
    IF v_fecha > api.fn_hoy() OR v_fecha > p_periodo.fin_semestre_ii
       OR v_fecha < (p_periodo.inicio_semestre_i - INTERVAL '1 year')::DATE THEN
        PERFORM api.fn_lanzar_excepcion('MA002', 'La fecha de matrícula no es válida.');
    END IF;
    RETURN v_fecha;
END;
$$;

-- CU 22 - Matricular estudiante en una sección. p_fecha_matricula NULL = hoy (o el inicio del periodo
-- si ya finalizó). Reglas: una matrícula por periodo (MA001), edad 16-19 al inicio del periodo (ES003),
-- fecha de matrícula ni futura ni posterior al fin del periodo ni más de un año antes de su inicio (MA002).
-- Para una sección completa de nivel 11, ver fn_admin_subir_seccion.
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

    -- MA005: no se repite un nivel (BI: nivel 10 y luego 11, una sola vez cada uno).
    IF EXISTS (SELECT 1 FROM academico.matriculas m JOIN academico.secciones s ON s.id_seccion = m.id_seccion
               WHERE m.id_estudiante = v_estudiante.id_estudiante AND s.nivel = p_nivel) THEN
        PERFORM api.fn_lanzar_excepcion('MA005', 'El estudiante ya tiene una matrícula en ese nivel.');
    END IF;

    IF p_nivel = 10 THEN
        -- RN-01: la edad se valida al ingresar al programa (nivel 10), a la fecha de inicio del periodo.
        PERFORM academico.fn_validar_edad_estudiante(v_estudiante.fecha_nacimiento, v_periodo.inicio_semestre_i);
    ELSIF NOT EXISTS (
        -- MA004: nivel 11 exige nivel 10 del año anterior, mismo número de sección y sin retiro.
        SELECT 1
        FROM academico.matriculas m
        JOIN academico.secciones s ON s.id_seccion = m.id_seccion
        JOIN academico.periodos_academicos p ON p.id_periodo = m.id_periodo
        WHERE m.id_estudiante = v_estudiante.id_estudiante
          AND s.nivel = 10 AND s.numero = p_numero AND p.anio = p_anio - 1 AND m.fecha_retiro IS NULL
    ) THEN
        PERFORM api.fn_lanzar_excepcion('MA004', 'Para matricular en nivel 11 el estudiante debe haber cursado nivel 10 el año anterior en la sección con el mismo número.');
    END IF;

    v_fecha := academico.fn_validar_fecha_matricula(v_periodo, p_fecha_matricula);

    INSERT INTO academico.matriculas (id_estudiante, id_periodo, id_seccion, fecha_matricula)
    VALUES (v_estudiante.id_estudiante, v_periodo.id_periodo, v_id_seccion, v_fecha);
END;
$$;

-- CU 22 - Subir la sección (RN-64): matricula en la 11-N de p_anio a todos los estudiantes de la 10-N de
-- p_anio - 1 sin retiro, en lugar de uno por uno (la matrícula individual sigue disponible). Si la 11-N
-- no existe se crea, sin guía (RN-63). Omite a quien ya tiene matrícula en p_anio (se puede repetir la
-- acción tras matricular a alguno individualmente). La edad no se valida (RN-01: solo al entrar a 10).
-- Errores: NF004 periodo, NF006 no existe la 10-N del año anterior, MA002 fecha.
CREATE OR REPLACE FUNCTION academico.fn_admin_subir_seccion(
    p_id_usuario_actor UUID,
    p_anio INTEGER,
    p_numero INTEGER,
    p_fecha_matricula DATE
)
RETURNS TABLE(seccion_creada BOOLEAN, matriculados TEXT[], omitidos TEXT[])
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_periodo academico.periodos_academicos%ROWTYPE;
    v_id_seccion_10 BIGINT;
    v_id_seccion_11 BIGINT;
    v_creada BOOLEAN := FALSE;
    v_fecha DATE;
    v_matriculados TEXT[];
    v_omitidos TEXT[];
BEGIN
    PERFORM api.fn_validar_admin_activo(p_id_usuario_actor);

    SELECT * INTO v_periodo FROM academico.periodos_academicos WHERE anio = p_anio;
    IF NOT FOUND THEN
        PERFORM api.fn_lanzar_excepcion('NF004', 'El periodo académico no existe.');
    END IF;

    v_id_seccion_10 := academico.fn_obtener_id_seccion(p_anio - 1, 10, p_numero);
    v_fecha := academico.fn_validar_fecha_matricula(v_periodo, p_fecha_matricula);

    SELECT s.id_seccion INTO v_id_seccion_11
    FROM academico.secciones s
    WHERE s.id_periodo = v_periodo.id_periodo AND s.nivel = 11 AND s.numero = p_numero;

    IF v_id_seccion_11 IS NULL THEN
        INSERT INTO academico.secciones (id_periodo, nivel, numero)
        VALUES (v_periodo.id_periodo, 11, p_numero)
        RETURNING id_seccion INTO v_id_seccion_11;
        v_creada := TRUE;
    END IF;

    -- Quien ya tiene matrícula en el año se omite (solo puede ser su 11-N: MA004 y MA005).
    SELECT array_agg(e.cedula ORDER BY e.cedula) INTO v_omitidos
    FROM academico.matriculas m10
    JOIN academico.estudiantes e ON e.id_estudiante = m10.id_estudiante
    WHERE m10.id_seccion = v_id_seccion_10 AND m10.fecha_retiro IS NULL
      AND EXISTS (SELECT 1 FROM academico.matriculas m
                  WHERE m.id_estudiante = m10.id_estudiante AND m.id_periodo = v_periodo.id_periodo);

    WITH nuevas AS (
        INSERT INTO academico.matriculas (id_estudiante, id_periodo, id_seccion, fecha_matricula)
        SELECT m10.id_estudiante, v_periodo.id_periodo, v_id_seccion_11, v_fecha
        FROM academico.matriculas m10
        WHERE m10.id_seccion = v_id_seccion_10 AND m10.fecha_retiro IS NULL
          AND NOT EXISTS (SELECT 1 FROM academico.matriculas m
                          WHERE m.id_estudiante = m10.id_estudiante AND m.id_periodo = v_periodo.id_periodo)
        RETURNING id_estudiante
    )
    SELECT array_agg(e.cedula ORDER BY e.cedula) INTO v_matriculados
    FROM nuevas n JOIN academico.estudiantes e ON e.id_estudiante = n.id_estudiante;

    RETURN QUERY SELECT v_creada, COALESCE(v_matriculados, '{}'), COALESCE(v_omitidos, '{}');
END;
$$;

-- CU 24 - Consultar matrículas / historial. Filtros opcionales (NULL = todos): año, nivel, número de
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

-- CU 23 - Modificar matrícula: cambiar de sección dentro del mismo periodo (traslado). MA006 fuera del nivel 10;
-- MA008 si ya tiene ausencias, notas o informes CAS.
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

    -- MA006: solo se traslada dentro del nivel 10 y antes de pasar a 11 (en 11 la sección conserva
    -- el número que tenía en 10).
    IF p_nivel <> 10
       OR (SELECT s.nivel FROM academico.secciones s WHERE s.id_seccion = v_matricula.id_seccion) <> 10
       OR academico.fn_matricula_tiene_continuidad(v_id_matricula) THEN
        PERFORM api.fn_lanzar_excepcion('MA006', 'Solo se puede trasladar de sección dentro del nivel 10 y antes de pasar a nivel 11.');
    END IF;

    -- MA008: las ausencias, notas e informes CAS pertenecen a las asignaciones de la sección; con registros no se
    -- traslada (quedarían fuera de la sección nueva y de su reporte de bandas).
    IF academico.fn_matricula_tiene_registros(v_id_matricula) THEN
        PERFORM api.fn_lanzar_excepcion('MA008', 'La matrícula ya tiene ausencias, notas o informes CAS en su sección.');
    END IF;

    v_prev := academico.fn_snapshot_matricula(v_id_matricula);

    UPDATE academico.matriculas SET id_seccion = v_id_seccion_nueva WHERE id_matricula = v_id_matricula;

    RETURN QUERY SELECT 'OK'::TEXT, v_prev;
END;
$$;

-- CU 23 - Modificar matrícula: registrar o corregir el retiro del estudiante. La fecha no puede ser
-- futura, anterior a la matrícula ni posterior al fin del periodo (MA003), ni dejar fuera registros ya hechos (MA009).
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
    v_periodo academico.periodos_academicos%ROWTYPE;
    v_motivo TEXT := api.fn_limpiar(p_motivo);
    v_prev JSONB;
BEGIN
    PERFORM api.fn_validar_admin_activo(p_id_usuario_actor);

    v_id_matricula := academico.fn_obtener_id_matricula(p_anio, p_cedula_estudiante);
    SELECT * INTO v_matricula FROM academico.matriculas WHERE id_matricula = v_id_matricula FOR UPDATE;
    PERFORM academico.fn_validar_sin_continuidad(v_id_matricula);
    SELECT * INTO v_periodo FROM academico.periodos_academicos WHERE id_periodo = v_matricula.id_periodo;

    IF p_fecha_retiro IS NULL OR p_fecha_retiro > api.fn_hoy()
       OR p_fecha_retiro < v_matricula.fecha_matricula OR p_fecha_retiro > v_periodo.fin_semestre_ii THEN
        PERFORM api.fn_lanzar_excepcion('MA003', 'La fecha de retiro no es válida.');
    END IF;

    -- MA009: el retiro no deja fuera registros ya hechos: ausencias en lecciones de esa fecha o posteriores (LE003) ni
    -- notas o informes CAS de un semestre que termina en o después del retiro (EV004).
    IF EXISTS (SELECT 1 FROM academico.ausencias au JOIN academico.lecciones l ON l.id_leccion = au.id_leccion
               WHERE au.id_matricula = v_id_matricula AND l.fecha >= p_fecha_retiro)
       OR EXISTS (SELECT 1 FROM academico.evaluaciones ev
                  WHERE ev.id_matricula = v_id_matricula AND academico.fn_fin_semestre(v_periodo, ev.semestre) >= p_fecha_retiro)
       OR EXISTS (SELECT 1 FROM academico.informes_cas i
                  WHERE i.id_matricula = v_id_matricula AND academico.fn_fin_semestre(v_periodo, i.semestre) >= p_fecha_retiro) THEN
        PERFORM api.fn_lanzar_excepcion('MA009', 'La fecha de retiro deja fuera ausencias, notas o informes CAS ya registrados.');
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

-- CU 23 - Modificar matrícula: anular el retiro (reingreso o corrección). 'SIN_CAMBIOS' si no tenía.
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

-- CU 25 - Eliminar matrícula (corrección de errores). Devuelve el snapshot previo. Si otras entidades
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
    PERFORM academico.fn_validar_sin_continuidad(v_id_matricula);

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
    PERFORM academico.fn_validar_acceso_seccion(p_id_usuario, v_id_seccion);

    RETURN QUERY
    SELECT (d.fila).*
    FROM academico.fn_matriculas_detalle() d
    WHERE d.id_seccion = v_id_seccion
    ORDER BY d.apellidos_nombre;
END;
$$;

-- Profesor Regular CU05 - Ficha de un estudiante de una sección (RN-65): datos personales y su matrícula
-- en esa sección, incluido el motivo de retiro. Mismo acceso que CU04 (AD003); NF003 si el estudiante no
-- existe y NF009 si no está matriculado en la sección.
CREATE TYPE academico.ficha_estudiante AS (
    cedula VARCHAR(20),
    nombre VARCHAR(100),
    primer_apellido VARCHAR(100),
    segundo_apellido VARCHAR(100),
    numero_celular VARCHAR(20),
    email CITEXT,
    fecha_nacimiento DATE,
    anio INTEGER,
    seccion TEXT,
    fecha_matricula DATE,
    estado academico.estado_matricula,
    fecha_retiro DATE,
    motivo_retiro VARCHAR(255)
);

CREATE OR REPLACE FUNCTION academico.fn_profesor_obtener_estudiante_seccion(
    p_id_usuario UUID, p_anio INTEGER, p_nivel INTEGER, p_numero INTEGER, p_cedula_estudiante TEXT)
RETURNS academico.ficha_estudiante
LANGUAGE plpgsql STABLE
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_id_seccion BIGINT := academico.fn_obtener_id_seccion(p_anio, p_nivel, p_numero);
    v_id_estudiante BIGINT;
    v_ficha academico.ficha_estudiante;
BEGIN
    PERFORM academico.fn_validar_acceso_seccion(p_id_usuario, v_id_seccion);
    v_id_estudiante := academico.fn_obtener_id_estudiante(p_cedula_estudiante);

    SELECT e.cedula, e.nombre, e.primer_apellido, e.segundo_apellido, e.numero_celular, e.email, e.fecha_nacimiento,
           (d.fila).anio, (d.fila).seccion, (d.fila).fecha_matricula, (d.fila).estado,
           (d.fila).fecha_retiro, (d.fila).motivo_retiro
    INTO v_ficha
    FROM academico.fn_matriculas_detalle() d
    JOIN academico.matriculas m ON m.id_matricula = d.id_matricula
    JOIN academico.estudiantes e ON e.id_estudiante = m.id_estudiante
    WHERE d.id_seccion = v_id_seccion AND m.id_estudiante = v_id_estudiante;

    IF NOT FOUND THEN
        PERFORM api.fn_lanzar_excepcion('NF009', 'El estudiante no está matriculado en esa sección.');
    END IF;

    RETURN v_ficha;
END;
$$;
