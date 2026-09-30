-- ============================================================
-- 15_evaluaciones.sql: notas semestrales (Profesor Regular CU01, CU06 a CU09 y CU14; Guía CU03/CU04) y
-- prórrogas del ADMIN. Tablas en 06.
-- La nota es por semestre, estudiante y asignación, en la escala fija del tipo de asignatura (RN-73).
-- El profesor registra y corrige sus notas desde el inicio del semestre hasta el cierre: la fecha de fin del
-- semestre o la prórroga que el ADMIN le dio (RN-74). Las envía al guía (RN-75); el guía y el reporte de
-- bandas solo ven notas enviadas.
-- ============================================================
SET search_path = academico, api, auth, public;

CREATE TYPE academico.nota_estudiante AS (
    cedula_estudiante VARCHAR(20),
    nombre_estudiante TEXT,      -- "Apellido1 Apellido2, Nombre"
    estado_matricula academico.estado_matricula,
    nota VARCHAR(3),             -- NULL = sin nota
    nota_minima VARCHAR(3),      -- NULL en TRONCAL (sin mínima)
    aprobada BOOLEAN,            -- NULL sin nota o en TRONCAL
    observaciones VARCHAR(500)
);

-- Estado de las notas de una asignación en un semestre.
CREATE TYPE academico.estado_notas AS (
    anio INTEGER,
    seccion TEXT,
    codigo_asignatura VARCHAR(10),
    asignatura TEXT,
    tipo_asignatura academico.tipo_asignatura,
    semestre academico.numero_semestre,
    fecha_cierre DATE,           -- fin del semestre o prórroga
    enviado_en TIMESTAMPTZ,      -- NULL = sin enviar
    estudiantes INTEGER,
    sin_nota INTEGER
);

-- Guía CU03: una fila por estudiante y asignación de la sección. nota solo si el profesor ya la envió.
CREATE TYPE academico.nota_seccion AS (
    cedula_estudiante VARCHAR(20),
    nombre_estudiante TEXT,
    estado_matricula academico.estado_matricula,
    codigo_asignatura VARCHAR(10),
    asignatura TEXT,
    tipo_asignatura academico.tipo_asignatura,
    nombre_profesor TEXT,
    enviada BOOLEAN,
    nota VARCHAR(3),
    nota_minima VARCHAR(3),
    aprobada BOOLEAN,
    observaciones VARCHAR(500)
);

-- Profesor Regular CU01: una fila por asignación y semestre con plazo abierto.
CREATE TYPE academico.aviso_notas AS (
    anio INTEGER,
    nivel SMALLINT,
    numero SMALLINT,
    seccion TEXT,
    codigo_asignatura VARCHAR(10),
    asignatura TEXT,
    semestre academico.numero_semestre,
    fecha_cierre DATE,
    dias_para_cierre INTEGER,
    estudiantes INTEGER,
    sin_nota INTEGER,
    enviada BOOLEAN,
    aviso TEXT                   -- NINGUNO | INFORMATIVO | PRIORIDAD (RN-76)
);

CREATE TYPE academico.prorroga_detalle AS (
    anio INTEGER,
    semestre academico.numero_semestre,
    cedula_profesor VARCHAR(20),
    nombre_profesor TEXT,
    fin_semestre DATE,
    fecha_limite DATE
);

-- ------------------------------------------------------------
-- Escalas (RN-73)
-- ------------------------------------------------------------
-- Nota normalizada según el tipo: SUPERIOR y MEDIO '1'..'7'; TRONCAL 'A'..'E'; MEP entero '0'..'100'. EV001 si no cabe.
CREATE OR REPLACE FUNCTION academico.fn_normalizar_nota(p_tipo academico.tipo_asignatura, p_nota TEXT)
RETURNS TEXT
LANGUAGE plpgsql IMMUTABLE
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_nota TEXT := upper(api.fn_limpiar(p_nota));
BEGIN
    IF v_nota IS NOT NULL THEN
        IF p_tipo IN ('SUPERIOR', 'MEDIO') AND v_nota ~ '^[1-7]$' THEN
            RETURN v_nota;
        ELSIF p_tipo = 'TRONCAL' AND v_nota ~ '^[A-E]$' THEN
            RETURN v_nota;
        ELSIF p_tipo = 'MEP' AND v_nota ~ '^[0-9]{1,3}$' AND v_nota::INTEGER <= 100 THEN
            RETURN v_nota::INTEGER::TEXT;
        END IF;
    END IF;

    PERFORM api.fn_lanzar_excepcion('EV001', 'La nota no corresponde a la escala de la asignatura.');
END;
$$;

-- Nota mínima de aprobación: SUPERIOR 4, MEDIO 3, MEP 70; TRONCAL no tiene.
CREATE OR REPLACE FUNCTION academico.fn_nota_minima(p_tipo academico.tipo_asignatura)
RETURNS TEXT
LANGUAGE sql IMMUTABLE
AS $$
    SELECT CASE p_tipo WHEN 'SUPERIOR' THEN '4' WHEN 'MEDIO' THEN '3' WHEN 'MEP' THEN '70' END;
$$;

-- NULL sin nota o en TRONCAL.
CREATE OR REPLACE FUNCTION academico.fn_nota_aprobada(p_tipo academico.tipo_asignatura, p_nota TEXT)
RETURNS BOOLEAN
LANGUAGE sql IMMUTABLE
AS $$
    SELECT CASE WHEN p_nota IS NULL OR p_tipo = 'TRONCAL' THEN NULL
                ELSE p_nota::INTEGER >= academico.fn_nota_minima(p_tipo)::INTEGER END;
$$;

-- ------------------------------------------------------------
-- Helpers
-- ------------------------------------------------------------
-- Inicio de un semestre.
CREATE OR REPLACE FUNCTION academico.fn_inicio_semestre(p academico.periodos_academicos, p_semestre academico.numero_semestre)
RETURNS DATE
LANGUAGE sql IMMUTABLE
AS $$
    SELECT CASE p_semestre WHEN 'I_SEMESTRE' THEN p.inicio_semestre_i ELSE p.inicio_semestre_ii END;
$$;

-- RN-74: cierre de notas del profesor en el semestre: el fin del semestre o su prórroga, si es posterior.
CREATE OR REPLACE FUNCTION academico.fn_cierre_notas(
    p_id_profesor BIGINT, p academico.periodos_academicos, p_semestre academico.numero_semestre)
RETURNS DATE
LANGUAGE plpgsql STABLE
SET search_path = academico, auth, api, public
AS $$
BEGIN
    RETURN GREATEST(academico.fn_fin_semestre(p, p_semestre),
                    (SELECT pg.fecha_limite FROM academico.prorrogas pg
                     WHERE pg.id_profesor = p_id_profesor AND pg.id_periodo = p.id_periodo AND pg.semestre = p_semestre));
END;
$$;

-- RN-74: EV002 si el semestre no ha iniciado; EV003 si ya pasó el cierre del profesor.
CREATE OR REPLACE FUNCTION academico.fn_validar_plazo_notas(
    p_id_profesor BIGINT, p academico.periodos_academicos, p_semestre academico.numero_semestre)
RETURNS VOID
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
BEGIN
    IF p_semestre IS NULL THEN
        PERFORM api.fn_lanzar_excepcion('22P02', 'Falta el semestre.');
    END IF;

    IF api.fn_hoy() < academico.fn_inicio_semestre(p, p_semestre) THEN
        PERFORM api.fn_lanzar_excepcion('EV002', 'El semestre todavía no ha iniciado.');
    END IF;

    IF api.fn_hoy() > academico.fn_cierre_notas(p_id_profesor, p, p_semestre) THEN
        PERFORM api.fn_lanzar_excepcion('EV003', 'El plazo de notas del semestre cerró.');
    END IF;
END;
$$;

-- Estudiantes que se califican en una sección y semestre: matriculados a más tardar el fin del semestre y sin
-- retiro en o antes de esa fecha (RN-75). Lo usan evaluaciones, CAS e informes.
CREATE OR REPLACE FUNCTION academico.fn_matriculas_del_semestre(p_id_seccion BIGINT, p_semestre academico.numero_semestre)
RETURNS TABLE(id_matricula BIGINT, id_estudiante BIGINT)
LANGUAGE plpgsql STABLE
SET search_path = academico, auth, api, public
AS $$
BEGIN
    RETURN QUERY
    SELECT m.id_matricula, m.id_estudiante
    FROM academico.matriculas m
    JOIN academico.periodos_academicos p ON p.id_periodo = m.id_periodo
    WHERE m.id_seccion = p_id_seccion
      AND m.fecha_matricula <= academico.fn_fin_semestre(p, p_semestre)
      AND (m.fecha_retiro IS NULL OR m.fecha_retiro > academico.fn_fin_semestre(p, p_semestre));
END;
$$;

-- Asignación con lo necesario para operar sus notas.
CREATE OR REPLACE FUNCTION academico.fn_datos_asignacion(p_id_asignacion BIGINT)
RETURNS TABLE(id_seccion BIGINT, id_profesor BIGINT, tipo academico.tipo_asignatura, periodo academico.periodos_academicos)
LANGUAGE plpgsql STABLE
SET search_path = academico, auth, api, public
AS $$
BEGIN
    RETURN QUERY
    SELECT a.id_seccion, a.id_profesor, asg.tipo, p
    FROM academico.asignaciones_docentes a
    JOIN academico.asignaturas asg ON asg.id_asignatura = a.id_asignatura
    JOIN academico.secciones s ON s.id_seccion = a.id_seccion
    JOIN academico.periodos_academicos p ON p.id_periodo = s.id_periodo
    WHERE a.id_asignacion = p_id_asignacion;
END;
$$;

-- Notas de los estudiantes a calificar de una asignación en un semestre (incluye a quien no tiene nota).
CREATE OR REPLACE FUNCTION academico.fn_notas_asignacion(p_id_asignacion BIGINT, p_semestre academico.numero_semestre)
RETURNS SETOF academico.nota_estudiante
LANGUAGE plpgsql STABLE
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v RECORD;
BEGIN
    SELECT * INTO v FROM academico.fn_datos_asignacion(p_id_asignacion);

    RETURN QUERY
    SELECT (d.fila).cedula_estudiante, (d.fila).nombre_estudiante, (d.fila).estado,
           ev.nota, academico.fn_nota_minima(v.tipo)::VARCHAR(3), academico.fn_nota_aprobada(v.tipo, ev.nota), ev.observaciones
    FROM academico.fn_matriculas_del_semestre(v.id_seccion, p_semestre) ms
    JOIN academico.fn_matriculas_detalle() d ON d.id_matricula = ms.id_matricula
    LEFT JOIN academico.evaluaciones ev
           ON ev.id_asignacion = p_id_asignacion AND ev.id_matricula = ms.id_matricula AND ev.semestre = p_semestre
    ORDER BY d.apellidos_nombre;
END;
$$;

-- Estado de las notas de una asignación en un semestre.
CREATE OR REPLACE FUNCTION academico.fn_estado_notas(p_id_asignacion BIGINT, p_semestre academico.numero_semestre)
RETURNS academico.estado_notas
LANGUAGE plpgsql STABLE
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v RECORD;
    r academico.estado_notas;
BEGIN
    SELECT * INTO v FROM academico.fn_datos_asignacion(p_id_asignacion);

    SELECT (ad.fila).anio, (ad.fila).seccion, (ad.fila).codigo_asignatura, (ad.fila).asignatura, v.tipo, p_semestre,
           academico.fn_cierre_notas(v.id_profesor, v.periodo, p_semestre),
           (SELECT en.enviado_en FROM academico.envios_notas en WHERE en.id_asignacion = p_id_asignacion AND en.semestre = p_semestre),
           (SELECT COUNT(*)::INTEGER FROM academico.fn_notas_asignacion(p_id_asignacion, p_semestre)),
           (SELECT COUNT(*)::INTEGER FROM academico.fn_notas_asignacion(p_id_asignacion, p_semestre) n WHERE n.nota IS NULL)
    INTO r
    FROM academico.fn_asignaciones_detalle() ad
    WHERE ad.id_asignacion = p_id_asignacion;

    RETURN r;
END;
$$;

-- ------------------------------------------------------------
-- Profesor Regular CU06 / CU07 / CU09 - Registrar y modificar notas y observaciones
-- p_notas: [{ "cedulaEstudiante": "...", "nota": "6", "observaciones": "..." }]. Registra o reemplaza la nota y
-- las observaciones de cada estudiante indicado; los demás no cambian. EV004 si un estudiante no se califica en
-- la sección y semestre; EV005 si se repite. Devuelve 'OK' o 'SIN_CAMBIOS' y los valores previos de lo que cambió.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION academico.fn_profesor_registrar_notas(
    p_id_usuario UUID,
    p_anio INTEGER,
    p_nivel INTEGER,
    p_numero INTEGER,
    p_codigo_asignatura TEXT,
    p_semestre academico.numero_semestre,
    p_notas JSONB,
    OUT out_status TEXT,
    OUT out_datos_anteriores JSONB
)
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_id_asignacion BIGINT := academico.fn_obtener_mi_asignacion(p_id_usuario, p_anio, p_nivel, p_numero, p_codigo_asignatura);
    v RECORD;
    v_item JSONB;
    v_cedula TEXT;
    v_nota TEXT;
    v_observaciones TEXT;
    v_id_matricula BIGINT;
    v_prev academico.evaluaciones%ROWTYPE;
    v_vistas TEXT[] := ARRAY[]::TEXT[];
    v_cambios JSONB := '[]'::jsonb;
BEGIN
    SELECT * INTO v FROM academico.fn_datos_asignacion(v_id_asignacion);
    PERFORM academico.fn_validar_plazo_notas(v.id_profesor, v.periodo, p_semestre);

    FOR v_item IN SELECT * FROM jsonb_array_elements(COALESCE(p_notas, '[]'::jsonb)) LOOP
        v_cedula := api.fn_limpiar(v_item->>'cedulaEstudiante');
        IF v_cedula = ANY (v_vistas) THEN
            PERFORM api.fn_lanzar_excepcion('EV005', 'Un estudiante aparece más de una vez.');
        END IF;
        v_vistas := v_vistas || v_cedula;

        SELECT ms.id_matricula INTO v_id_matricula
        FROM academico.fn_matriculas_del_semestre(v.id_seccion, p_semestre) ms
        JOIN academico.estudiantes e ON e.id_estudiante = ms.id_estudiante
        WHERE e.cedula = v_cedula;

        IF v_id_matricula IS NULL THEN
            PERFORM api.fn_lanzar_excepcion('EV004', 'El estudiante no se califica en esa sección y semestre.');
        END IF;

        v_nota := academico.fn_normalizar_nota(v.tipo, v_item->>'nota');
        v_observaciones := api.fn_limpiar(v_item->>'observaciones');

        SELECT * INTO v_prev FROM academico.evaluaciones
        WHERE id_asignacion = v_id_asignacion AND id_matricula = v_id_matricula AND semestre = p_semestre
        FOR UPDATE;

        IF NOT FOUND THEN
            INSERT INTO academico.evaluaciones (id_asignacion, id_matricula, semestre, nota, observaciones)
            VALUES (v_id_asignacion, v_id_matricula, p_semestre, v_nota, v_observaciones);
            v_cambios := v_cambios || jsonb_build_object('cedulaEstudiante', v_cedula, 'nota', NULL, 'observaciones', NULL);
        ELSIF (v_prev.nota, v_prev.observaciones) IS DISTINCT FROM (v_nota, v_observaciones) THEN
            UPDATE academico.evaluaciones
            SET nota = v_nota, observaciones = v_observaciones, modificado_en = NOW()
            WHERE id_evaluacion = v_prev.id_evaluacion;
            v_cambios := v_cambios || jsonb_build_object('cedulaEstudiante', v_cedula, 'nota', v_prev.nota, 'observaciones', v_prev.observaciones);
        END IF;
    END LOOP;

    IF jsonb_array_length(v_cambios) = 0 THEN
        out_status := 'SIN_CAMBIOS';
    ELSE
        out_status := 'OK';
        out_datos_anteriores := v_cambios;
    END IF;
END;
$$;

-- ------------------------------------------------------------
-- Profesor Regular CU07 - Eliminar la nota de un estudiante (corrección). Anula el envío de la asignación en el
-- semestre: hay que volver a enviar (RN-75). NF009 si no tiene matrícula ese año; NF016 si no tiene nota.
-- Devuelve la nota previa y si se anuló el envío.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION academico.fn_profesor_eliminar_nota(
    p_id_usuario UUID, p_anio INTEGER, p_nivel INTEGER, p_numero INTEGER, p_codigo_asignatura TEXT,
    p_semestre academico.numero_semestre, p_cedula_estudiante TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_id_asignacion BIGINT := academico.fn_obtener_mi_asignacion(p_id_usuario, p_anio, p_nivel, p_numero, p_codigo_asignatura);
    v RECORD;
    v_id_matricula BIGINT := academico.fn_obtener_id_matricula(p_anio, p_cedula_estudiante);
    v_prev academico.evaluaciones%ROWTYPE;
    v_envio_anulado BOOLEAN;
BEGIN
    SELECT * INTO v FROM academico.fn_datos_asignacion(v_id_asignacion);
    PERFORM academico.fn_validar_plazo_notas(v.id_profesor, v.periodo, p_semestre);

    DELETE FROM academico.evaluaciones
    WHERE id_asignacion = v_id_asignacion AND id_matricula = v_id_matricula AND semestre = p_semestre
    RETURNING * INTO v_prev;

    IF v_prev.id_evaluacion IS NULL THEN
        PERFORM api.fn_lanzar_excepcion('NF016', 'El estudiante no tiene nota en esa asignación y semestre.');
    END IF;

    DELETE FROM academico.envios_notas WHERE id_asignacion = v_id_asignacion AND semestre = p_semestre;
    v_envio_anulado := FOUND;

    RETURN jsonb_build_object('cedulaEstudiante', api.fn_limpiar(p_cedula_estudiante), 'nota', v_prev.nota,
                              'observaciones', v_prev.observaciones, 'envioAnulado', v_envio_anulado);
END;
$$;

-- ------------------------------------------------------------
-- Profesor Regular CU08 - Consultar evaluaciones de mi asignación en un semestre
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION academico.fn_profesor_listar_notas(
    p_id_usuario UUID, p_anio INTEGER, p_nivel INTEGER, p_numero INTEGER, p_codigo_asignatura TEXT,
    p_semestre academico.numero_semestre)
RETURNS SETOF academico.nota_estudiante
LANGUAGE plpgsql STABLE
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_id_asignacion BIGINT := academico.fn_obtener_mi_asignacion(p_id_usuario, p_anio, p_nivel, p_numero, p_codigo_asignatura);
BEGIN
    RETURN QUERY SELECT * FROM academico.fn_notas_asignacion(v_id_asignacion, p_semestre);
END;
$$;

CREATE OR REPLACE FUNCTION academico.fn_profesor_estado_notas(
    p_id_usuario UUID, p_anio INTEGER, p_nivel INTEGER, p_numero INTEGER, p_codigo_asignatura TEXT,
    p_semestre academico.numero_semestre)
RETURNS SETOF academico.estado_notas
LANGUAGE plpgsql STABLE
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_id_asignacion BIGINT := academico.fn_obtener_mi_asignacion(p_id_usuario, p_anio, p_nivel, p_numero, p_codigo_asignatura);
BEGIN
    RETURN QUERY SELECT (academico.fn_estado_notas(v_id_asignacion, p_semestre)).*;
END;
$$;

-- ------------------------------------------------------------
-- Profesor Regular CU14 - Enviar el registro de bandas al guía (RN-75). EV006 si falta la nota de algún
-- estudiante. Devuelve 'OK', o 'SIN_CAMBIOS' si ya estaba enviado.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION academico.fn_profesor_enviar_notas(
    p_id_usuario UUID, p_anio INTEGER, p_nivel INTEGER, p_numero INTEGER, p_codigo_asignatura TEXT,
    p_semestre academico.numero_semestre)
RETURNS TEXT
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_id_asignacion BIGINT := academico.fn_obtener_mi_asignacion(p_id_usuario, p_anio, p_nivel, p_numero, p_codigo_asignatura);
    v RECORD;
BEGIN
    SELECT * INTO v FROM academico.fn_datos_asignacion(v_id_asignacion);
    PERFORM academico.fn_validar_plazo_notas(v.id_profesor, v.periodo, p_semestre);

    IF EXISTS (SELECT 1 FROM academico.fn_notas_asignacion(v_id_asignacion, p_semestre) n WHERE n.nota IS NULL) THEN
        PERFORM api.fn_lanzar_excepcion('EV006', 'Hay estudiantes sin nota.');
    END IF;

    INSERT INTO academico.envios_notas (id_asignacion, semestre) VALUES (v_id_asignacion, p_semestre)
    ON CONFLICT (id_asignacion, semestre) DO NOTHING;

    RETURN CASE WHEN FOUND THEN 'OK' ELSE 'SIN_CAMBIOS' END;
END;
$$;

-- ------------------------------------------------------------
-- Profesor Regular CU01 - Pantalla principal: mis asignaciones con el plazo de notas abierto y el aviso según
-- los días para el cierre (RN-76). Quedan pendientes si falta alguna nota o no las ha enviado.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION academico.fn_profesor_avisos_notas(p_id_usuario UUID)
RETURNS SETOF academico.aviso_notas
LANGUAGE plpgsql STABLE
SET search_path = academico, auth, api, public
AS $$
BEGIN
    RETURN QUERY
    WITH abiertas AS (
        SELECT ad.id_asignacion, ad.fila, sem.s AS semestre,
               academico.fn_cierre_notas(a.id_profesor, p, sem.s) AS cierre
        FROM academico.fn_asignaciones_detalle() ad
        JOIN academico.asignaciones_docentes a ON a.id_asignacion = ad.id_asignacion
        JOIN academico.periodos_academicos p ON p.id_periodo = ad.id_periodo
        CROSS JOIN unnest(ARRAY['I_SEMESTRE', 'II_SEMESTRE']::academico.numero_semestre[]) AS sem(s)
        WHERE ad.id_usuario_profesor = p_id_usuario
          AND api.fn_hoy() BETWEEN academico.fn_inicio_semestre(p, sem.s) AND academico.fn_cierre_notas(a.id_profesor, p, sem.s)
    ), conteo AS (
        SELECT ab.*, e.estudiantes, e.sin_nota, e.enviado_en IS NOT NULL AS enviada, ab.cierre - api.fn_hoy() AS dias
        FROM abiertas ab
        CROSS JOIN LATERAL academico.fn_estado_notas(ab.id_asignacion, ab.semestre) e
    )
    SELECT (c.fila).anio, (c.fila).nivel, (c.fila).numero, (c.fila).seccion, (c.fila).codigo_asignatura, (c.fila).asignatura,
           c.semestre, c.cierre, c.dias, c.estudiantes, c.sin_nota, c.enviada,
           CASE WHEN c.sin_nota = 0 AND c.enviada THEN 'NINGUNO'
                WHEN c.dias <= 15 THEN 'PRIORIDAD'
                WHEN c.dias <= 30 THEN 'INFORMATIVO'
                ELSE 'NINGUNO' END
    FROM conteo c
    ORDER BY c.cierre, (c.fila).nivel, (c.fila).numero, (c.fila).asignatura;
END;
$$;

-- ------------------------------------------------------------
-- Guía CU03 / CU04 - Notas de una sección (RN-77): cualquier guía consulta cualquier sección. Una fila por
-- estudiante y asignación; la nota solo aparece si el profesor ya la envió.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION academico.fn_guia_notas_seccion(
    p_anio INTEGER, p_nivel INTEGER, p_numero INTEGER, p_semestre academico.numero_semestre)
RETURNS SETOF academico.nota_seccion
LANGUAGE plpgsql STABLE
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_id_seccion BIGINT := academico.fn_obtener_id_seccion(p_anio, p_nivel, p_numero);
BEGIN
    RETURN QUERY
    SELECT (d.fila).cedula_estudiante, (d.fila).nombre_estudiante, (d.fila).estado,
           (ad.fila).codigo_asignatura, (ad.fila).asignatura, asg.tipo, (ad.fila).nombre_profesor,
           en.id_asignacion IS NOT NULL,
           CASE WHEN en.id_asignacion IS NOT NULL THEN ev.nota END::VARCHAR(3),
           academico.fn_nota_minima(asg.tipo)::VARCHAR(3),
           CASE WHEN en.id_asignacion IS NOT NULL THEN academico.fn_nota_aprobada(asg.tipo, ev.nota) END,
           CASE WHEN en.id_asignacion IS NOT NULL THEN ev.observaciones END::VARCHAR(500)
    FROM academico.fn_matriculas_del_semestre(v_id_seccion, p_semestre) ms
    JOIN academico.fn_matriculas_detalle() d ON d.id_matricula = ms.id_matricula
    JOIN academico.asignaciones_docentes a ON a.id_seccion = v_id_seccion
    JOIN academico.asignaturas asg ON asg.id_asignatura = a.id_asignatura
    JOIN academico.fn_asignaciones_detalle() ad ON ad.id_asignacion = a.id_asignacion
    LEFT JOIN academico.envios_notas en ON en.id_asignacion = a.id_asignacion AND en.semestre = p_semestre
    LEFT JOIN academico.evaluaciones ev
           ON ev.id_asignacion = a.id_asignacion AND ev.id_matricula = ms.id_matricula AND ev.semestre = p_semestre
    ORDER BY d.apellidos_nombre, (ad.fila).asignatura, (ad.fila).nombre_profesor;
END;
$$;

-- ------------------------------------------------------------
-- Administrador - Prórrogas de notas (RN-74)
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION academico.fn_prorrogas_detalle()
RETURNS TABLE(id_profesor BIGINT, id_periodo BIGINT, fila academico.prorroga_detalle)
LANGUAGE sql STABLE
SET search_path = academico, auth, api, public
AS $$
    SELECT pg.id_profesor, pg.id_periodo,
           ROW(p.anio, pg.semestre, pr.cedula, concat_ws(' ', pr.nombre, pr.primer_apellido, pr.segundo_apellido),
               academico.fn_fin_semestre(p, pg.semestre), pg.fecha_limite)::academico.prorroga_detalle
    FROM academico.prorrogas pg
    JOIN academico.periodos_academicos p ON p.id_periodo = pg.id_periodo
    JOIN academico.profesores pr ON pr.id_profesor = pg.id_profesor;
$$;

-- Otorga o cambia la prórroga de un profesor en un semestre. EV007 si la fecha límite no es posterior al fin del
-- semestre o ya pasó. Devuelve 'OK' o 'SIN_CAMBIOS' y la prórroga previa.
CREATE OR REPLACE FUNCTION academico.fn_admin_otorgar_prorroga(
    p_id_usuario_actor UUID,
    p_anio INTEGER,
    p_semestre academico.numero_semestre,
    p_cedula_profesor TEXT,
    p_fecha_limite DATE,
    OUT out_status TEXT,
    OUT out_datos_anteriores JSONB
)
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_periodo academico.periodos_academicos%ROWTYPE;
    v_id_profesor BIGINT;
    v_prev academico.prorrogas%ROWTYPE;
BEGIN
    PERFORM api.fn_validar_admin_activo(p_id_usuario_actor);

    SELECT * INTO v_periodo FROM academico.periodos_academicos WHERE anio = p_anio;
    IF NOT FOUND THEN
        PERFORM api.fn_lanzar_excepcion('NF004', 'El periodo académico no existe.');
    END IF;
    v_id_profesor := academico.fn_obtener_id_profesor(p_cedula_profesor);

    IF p_fecha_limite IS NULL OR p_fecha_limite <= academico.fn_fin_semestre(v_periodo, p_semestre)
       OR p_fecha_limite < api.fn_hoy() THEN
        PERFORM api.fn_lanzar_excepcion('EV007', 'La fecha límite de la prórroga no es válida.');
    END IF;

    SELECT * INTO v_prev FROM academico.prorrogas
    WHERE id_profesor = v_id_profesor AND id_periodo = v_periodo.id_periodo AND semestre = p_semestre
    FOR UPDATE;

    IF FOUND THEN
        IF v_prev.fecha_limite = p_fecha_limite THEN
            out_status := 'SIN_CAMBIOS';
            RETURN;
        END IF;
        out_datos_anteriores := (SELECT to_jsonb(d.fila) FROM academico.fn_prorrogas_detalle() d
                                 WHERE d.id_profesor = v_id_profesor AND d.id_periodo = v_periodo.id_periodo
                                   AND (d.fila).semestre = p_semestre);
        UPDATE academico.prorrogas SET fecha_limite = p_fecha_limite
        WHERE id_profesor = v_id_profesor AND id_periodo = v_periodo.id_periodo AND semestre = p_semestre;
    ELSE
        INSERT INTO academico.prorrogas (id_profesor, id_periodo, semestre, fecha_limite)
        VALUES (v_id_profesor, v_periodo.id_periodo, p_semestre, p_fecha_limite);
    END IF;

    out_status := 'OK';
END;
$$;

-- Quita la prórroga. NF012 si no existe. Devuelve el snapshot previo.
CREATE OR REPLACE FUNCTION academico.fn_admin_quitar_prorroga(
    p_id_usuario_actor UUID, p_anio INTEGER, p_semestre academico.numero_semestre, p_cedula_profesor TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_id_profesor BIGINT;
    v_prev JSONB;
BEGIN
    PERFORM api.fn_validar_admin_activo(p_id_usuario_actor);
    v_id_profesor := academico.fn_obtener_id_profesor(p_cedula_profesor);

    SELECT to_jsonb(d.fila) INTO v_prev
    FROM academico.fn_prorrogas_detalle() d
    WHERE d.id_profesor = v_id_profesor AND (d.fila).anio = p_anio AND (d.fila).semestre = p_semestre;

    IF v_prev IS NULL THEN
        PERFORM api.fn_lanzar_excepcion('NF012', 'La prórroga no existe.');
    END IF;

    DELETE FROM academico.prorrogas pg
    USING academico.periodos_academicos p
    WHERE p.id_periodo = pg.id_periodo AND pg.id_profesor = v_id_profesor AND p.anio = p_anio AND pg.semestre = p_semestre;

    RETURN v_prev;
END;
$$;

-- Prórrogas, con filtros opcionales por año y profesor.
CREATE OR REPLACE FUNCTION academico.fn_admin_listar_prorrogas(p_anio INTEGER, p_cedula_profesor TEXT)
RETURNS SETOF academico.prorroga_detalle
LANGUAGE sql STABLE
SET search_path = academico, auth, api, public
AS $$
    SELECT (d.fila).*
    FROM academico.fn_prorrogas_detalle() d
    WHERE (p_anio IS NULL OR (d.fila).anio = p_anio)
      AND (p_cedula_profesor IS NULL OR (d.fila).cedula_profesor = api.fn_limpiar(p_cedula_profesor))
    ORDER BY (d.fila).anio DESC, (d.fila).semestre, (d.fila).nombre_profesor;
$$;
