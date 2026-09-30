-- ============================================================
-- 17_cas.sql: informes CAS (Profesor CAS CU01 a CU04, Coordinador de CAS CU01 y CU02). Tablas en 06.
-- CAS es la asignatura TRONCAL con código 'CAS'. El profesor CAS la imparte con una asignación académica
-- (Administrador CU38 = CU30, RN-82) y cada semestre llena un informe por estudiante con el formato del
-- Instituto (RN-83). El informe comparte la clave de la nota CAS (asignación, matrícula, semestre); la nota
-- se registra y se envía con evaluaciones. Se opera por (año, semestre, cédula del estudiante).
-- ============================================================
SET search_path = academico, api, auth, public;

-- Informe completo (Profesor CAS CU03 y Coordinador CAS CU02). experiencias: JSON en el orden del formato.
-- nota: la nota CAS del semestre (para el coordinador, solo si el profesor ya la envió).
CREATE TYPE academico.informe_cas AS (
    anio INTEGER,
    semestre academico.numero_semestre,
    seccion TEXT,
    cedula_estudiante VARCHAR(20),
    nombre_estudiante TEXT,
    email_estudiante TEXT,
    cedula_profesor VARCHAR(20),
    nombre_profesor TEXT,
    perfil BOOLEAN,
    entrevista_1 BOOLEAN,
    entrevista_2 BOOLEAN,
    entrevista_final BOOLEAN,
    observaciones VARCHAR(2000),
    nota VARCHAR(3),
    nota_enviada BOOLEAN,
    modificado_en TIMESTAMPTZ,
    experiencias JSONB
);

-- Progreso: una fila por estudiante y asignación CAS; tiene_informe FALSE = sin informe en el semestre.
CREATE TYPE academico.progreso_cas AS (
    anio INTEGER,
    seccion TEXT,
    cedula_estudiante VARCHAR(20),
    nombre_estudiante TEXT,
    nombre_profesor TEXT,
    semestre academico.numero_semestre,
    tiene_informe BOOLEAN,
    experiencias INTEGER,
    perfil BOOLEAN,
    entrevistas INTEGER,         -- cuántas de las 3 entrevistas lleva
    nota VARCHAR(3),
    nota_enviada BOOLEAN
);

-- ------------------------------------------------------------
-- Helpers
-- ------------------------------------------------------------
-- Asignación CAS del profesor autenticado en la sección donde el estudiante está matriculado ese año, y la
-- matrícula. NF004 / NF003 / NF009; AD004 si el profesor no imparte CAS en esa sección.
CREATE OR REPLACE FUNCTION academico.fn_obtener_mi_asignacion_cas(p_id_usuario UUID, p_anio INTEGER, p_cedula_estudiante TEXT)
RETURNS TABLE(id_asignacion BIGINT, id_matricula BIGINT)
LANGUAGE plpgsql STABLE
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_id_matricula BIGINT := academico.fn_obtener_id_matricula(p_anio, p_cedula_estudiante);
    v_id_asignacion BIGINT;
BEGIN
    SELECT a.id_asignacion INTO v_id_asignacion
    FROM academico.matriculas m
    JOIN academico.asignaciones_docentes a ON a.id_seccion = m.id_seccion
    JOIN academico.asignaturas asg ON asg.id_asignatura = a.id_asignatura
    JOIN academico.profesores pr ON pr.id_profesor = a.id_profesor
    WHERE m.id_matricula = v_id_matricula AND asg.codigo = 'CAS' AND pr.id_usuario = p_id_usuario;

    IF v_id_asignacion IS NULL THEN
        PERFORM api.fn_lanzar_excepcion('AD004', 'No impartes CAS en la sección del estudiante.');
    END IF;

    RETURN QUERY SELECT v_id_asignacion, v_id_matricula;
END;
$$;

-- Todos los informes con sus datos resueltos. p_solo_notas_enviadas: la nota solo aparece si ya se envió.
CREATE OR REPLACE FUNCTION academico.fn_informes_cas_detalle(p_solo_notas_enviadas BOOLEAN)
RETURNS TABLE(id_informe BIGINT, id_asignacion BIGINT, id_matricula BIGINT, fila academico.informe_cas)
LANGUAGE sql STABLE
SET search_path = academico, auth, api, public
AS $$
    SELECT i.id_informe, i.id_asignacion, i.id_matricula,
           ROW((d.fila).anio, i.semestre, (d.fila).seccion, (d.fila).cedula_estudiante, (d.fila).nombre_estudiante, e.email::TEXT,
               (ad.fila).cedula_profesor, (ad.fila).nombre_profesor,
               i.perfil, i.entrevista_1, i.entrevista_2, i.entrevista_final, i.observaciones,
               CASE WHEN NOT p_solo_notas_enviadas OR en.id_asignacion IS NOT NULL THEN ev.nota END::VARCHAR(3),
               en.id_asignacion IS NOT NULL,
               i.modificado_en,
               COALESCE((SELECT jsonb_agg(jsonb_build_object(
                             'orden', x.orden, 'descripcion', x.descripcion, 'fecha', x.fecha,
                             'creatividad', x.creatividad, 'actividad', x.actividad, 'servicio', x.servicio,
                             'resultadosAprendizaje', to_jsonb(x.resultados_aprendizaje),
                             'carpeta', x.carpeta, 'reflexion', x.reflexion, 'pruebas', x.pruebas) ORDER BY x.orden)
                         FROM academico.experiencias_cas x WHERE x.id_informe = i.id_informe), '[]'::jsonb)
              )::academico.informe_cas
    FROM academico.informes_cas i
    JOIN academico.fn_matriculas_detalle() d ON d.id_matricula = i.id_matricula
    JOIN academico.matriculas m ON m.id_matricula = i.id_matricula
    JOIN academico.estudiantes e ON e.id_estudiante = m.id_estudiante
    JOIN academico.fn_asignaciones_detalle() ad ON ad.id_asignacion = i.id_asignacion
    LEFT JOIN academico.evaluaciones ev
           ON ev.id_asignacion = i.id_asignacion AND ev.id_matricula = i.id_matricula AND ev.semestre = i.semestre
    LEFT JOIN academico.envios_notas en ON en.id_asignacion = i.id_asignacion AND en.semestre = i.semestre;
$$;

CREATE OR REPLACE FUNCTION academico.fn_snapshot_informe_cas(p_id_informe BIGINT)
RETURNS JSONB
LANGUAGE sql STABLE
SET search_path = academico, auth, api, public
AS $$
    SELECT to_jsonb(d.fila) - 'modificado_en' - 'nota' - 'nota_enviada'
    FROM academico.fn_informes_cas_detalle(FALSE) d WHERE d.id_informe = p_id_informe;
$$;

-- Progreso de las asignaciones CAS indicadas en un semestre (Profesor CAS CU03, Coordinador CAS CU01).
CREATE OR REPLACE FUNCTION academico.fn_progreso_cas(p_ids_asignacion BIGINT[], p_semestre academico.numero_semestre, p_solo_notas_enviadas BOOLEAN)
RETURNS SETOF academico.progreso_cas
LANGUAGE plpgsql STABLE
SET search_path = academico, auth, api, public
AS $$
BEGIN
    RETURN QUERY
    SELECT (d.fila).anio, (d.fila).seccion, (d.fila).cedula_estudiante, (d.fila).nombre_estudiante, (ad.fila).nombre_profesor,
           p_semestre, i.id_informe IS NOT NULL,
           (SELECT COUNT(*)::INTEGER FROM academico.experiencias_cas x WHERE x.id_informe = i.id_informe),
           COALESCE(i.perfil, FALSE),
           (COALESCE(i.entrevista_1::INTEGER, 0) + COALESCE(i.entrevista_2::INTEGER, 0) + COALESCE(i.entrevista_final::INTEGER, 0)),
           CASE WHEN NOT p_solo_notas_enviadas OR en.id_asignacion IS NOT NULL THEN ev.nota END::VARCHAR(3),
           en.id_asignacion IS NOT NULL
    FROM unnest(p_ids_asignacion) AS ids(id_asignacion)
    JOIN academico.asignaciones_docentes a ON a.id_asignacion = ids.id_asignacion
    JOIN academico.fn_asignaciones_detalle() ad ON ad.id_asignacion = a.id_asignacion
    CROSS JOIN LATERAL academico.fn_matriculas_del_semestre(a.id_seccion, p_semestre) ms
    JOIN academico.fn_matriculas_detalle() d ON d.id_matricula = ms.id_matricula
    LEFT JOIN academico.informes_cas i ON i.id_asignacion = a.id_asignacion AND i.id_matricula = ms.id_matricula AND i.semestre = p_semestre
    LEFT JOIN academico.evaluaciones ev ON ev.id_asignacion = a.id_asignacion AND ev.id_matricula = ms.id_matricula AND ev.semestre = p_semestre
    LEFT JOIN academico.envios_notas en ON en.id_asignacion = a.id_asignacion AND en.semestre = p_semestre
    ORDER BY (d.fila).anio DESC, (d.fila).nivel, (d.fila).numero, d.apellidos_nombre, (ad.fila).nombre_profesor;
END;
$$;

-- ------------------------------------------------------------
-- Profesor CAS CU01 / CU02 - Registrar o modificar el informe CAS de un estudiante en un semestre (RN-83).
-- p_experiencias: [{ descripcion, fecha, creatividad, actividad, servicio, resultadosAprendizaje: [1..7], carpeta,
-- reflexion, pruebas }], en el orden del formato (reemplaza las anteriores). Plazo como las notas (EV002 / EV003);
-- EV004 si el estudiante no se califica en el semestre; CA001 si la fecha de una experiencia es futura o está
-- fuera del periodo. Devuelve 'OK' o 'SIN_CAMBIOS' y el informe previo (NULL si es nuevo).
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION academico.fn_profesor_cas_guardar_informe(
    p_id_usuario UUID,
    p_anio INTEGER,
    p_semestre academico.numero_semestre,
    p_cedula_estudiante TEXT,
    p_perfil BOOLEAN,
    p_entrevista_1 BOOLEAN,
    p_entrevista_2 BOOLEAN,
    p_entrevista_final BOOLEAN,
    p_observaciones TEXT,
    p_experiencias JSONB,
    OUT out_status TEXT,
    OUT out_datos_anteriores JSONB
)
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_ids RECORD;
    v RECORD;
    v_id_informe BIGINT;
    v_prev JSONB;
    v_nuevo JSONB;
BEGIN
    SELECT * INTO v_ids FROM academico.fn_obtener_mi_asignacion_cas(p_id_usuario, p_anio, p_cedula_estudiante);
    SELECT * INTO v FROM academico.fn_datos_asignacion(v_ids.id_asignacion);
    PERFORM academico.fn_validar_plazo_notas(v.id_profesor, v.periodo, p_semestre);

    IF NOT EXISTS (SELECT 1 FROM academico.fn_matriculas_del_semestre(v.id_seccion, p_semestre) ms
                   WHERE ms.id_matricula = v_ids.id_matricula) THEN
        PERFORM api.fn_lanzar_excepcion('EV004', 'El estudiante no se califica en esa sección y semestre.');
    END IF;

    IF EXISTS (SELECT 1 FROM jsonb_array_elements(COALESCE(p_experiencias, '[]'::jsonb)) x
               WHERE x->>'fecha' IS NOT NULL
                 AND ((x->>'fecha')::DATE > api.fn_hoy()
                      OR (x->>'fecha')::DATE NOT BETWEEN (v.periodo).inicio_semestre_i AND (v.periodo).fin_semestre_ii)) THEN
        PERFORM api.fn_lanzar_excepcion('CA001', 'La fecha de una experiencia CAS no es válida.');
    END IF;

    SELECT i.id_informe INTO v_id_informe FROM academico.informes_cas i
    WHERE i.id_asignacion = v_ids.id_asignacion AND i.id_matricula = v_ids.id_matricula AND i.semestre = p_semestre
    FOR UPDATE;

    IF v_id_informe IS NULL THEN
        INSERT INTO academico.informes_cas (id_asignacion, id_matricula, semestre)
        VALUES (v_ids.id_asignacion, v_ids.id_matricula, p_semestre)
        RETURNING id_informe INTO v_id_informe;
    ELSE
        v_prev := academico.fn_snapshot_informe_cas(v_id_informe);
    END IF;

    UPDATE academico.informes_cas
    SET perfil = COALESCE(p_perfil, FALSE), entrevista_1 = COALESCE(p_entrevista_1, FALSE),
        entrevista_2 = COALESCE(p_entrevista_2, FALSE), entrevista_final = COALESCE(p_entrevista_final, FALSE),
        observaciones = api.fn_limpiar(p_observaciones)
    WHERE id_informe = v_id_informe;

    DELETE FROM academico.experiencias_cas WHERE id_informe = v_id_informe;
    INSERT INTO academico.experiencias_cas (id_informe, orden, descripcion, fecha, creatividad, actividad, servicio,
                                            resultados_aprendizaje, carpeta, reflexion, pruebas)
    SELECT v_id_informe, x.n, api.fn_limpiar(x.e->>'descripcion'), (x.e->>'fecha')::DATE,
           COALESCE((x.e->>'creatividad')::BOOLEAN, FALSE), COALESCE((x.e->>'actividad')::BOOLEAN, FALSE),
           COALESCE((x.e->>'servicio')::BOOLEAN, FALSE),
           ARRAY(SELECT DISTINCT r::SMALLINT FROM jsonb_array_elements_text(COALESCE(x.e->'resultadosAprendizaje', '[]'::jsonb)) r ORDER BY 1),
           COALESCE((x.e->>'carpeta')::BOOLEAN, FALSE), COALESCE((x.e->>'reflexion')::BOOLEAN, FALSE),
           COALESCE((x.e->>'pruebas')::BOOLEAN, FALSE)
    FROM jsonb_array_elements(COALESCE(p_experiencias, '[]'::jsonb)) WITH ORDINALITY AS x(e, n);

    v_nuevo := academico.fn_snapshot_informe_cas(v_id_informe);
    IF v_prev IS NOT NULL AND v_prev = v_nuevo THEN
        out_status := 'SIN_CAMBIOS';
        RETURN;
    END IF;

    UPDATE academico.informes_cas SET modificado_en = NOW() WHERE id_informe = v_id_informe;
    out_status := 'OK';
    out_datos_anteriores := v_prev;
END;
$$;

-- ------------------------------------------------------------
-- Profesor CAS CU04 - Eliminar el informe (con sus experiencias). NF015 si no existe. Devuelve el snapshot.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION academico.fn_profesor_cas_eliminar_informe(
    p_id_usuario UUID, p_anio INTEGER, p_semestre academico.numero_semestre, p_cedula_estudiante TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_ids RECORD;
    v RECORD;
    v_id_informe BIGINT;
    v_prev JSONB;
BEGIN
    SELECT * INTO v_ids FROM academico.fn_obtener_mi_asignacion_cas(p_id_usuario, p_anio, p_cedula_estudiante);
    SELECT * INTO v FROM academico.fn_datos_asignacion(v_ids.id_asignacion);
    PERFORM academico.fn_validar_plazo_notas(v.id_profesor, v.periodo, p_semestre);

    SELECT i.id_informe INTO v_id_informe FROM academico.informes_cas i
    WHERE i.id_asignacion = v_ids.id_asignacion AND i.id_matricula = v_ids.id_matricula AND i.semestre = p_semestre
    FOR UPDATE;

    IF v_id_informe IS NULL THEN
        PERFORM api.fn_lanzar_excepcion('NF015', 'El informe CAS no existe.');
    END IF;

    v_prev := academico.fn_snapshot_informe_cas(v_id_informe);
    DELETE FROM academico.informes_cas WHERE id_informe = v_id_informe;
    RETURN v_prev;
END;
$$;

-- ------------------------------------------------------------
-- Profesor CAS CU03 - Consultar: progreso de mi sección CAS y un informe completo
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION academico.fn_profesor_cas_progreso(
    p_id_usuario UUID, p_anio INTEGER, p_nivel INTEGER, p_numero INTEGER, p_semestre academico.numero_semestre)
RETURNS SETOF academico.progreso_cas
LANGUAGE plpgsql STABLE
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_id_asignacion BIGINT := academico.fn_obtener_mi_asignacion(p_id_usuario, p_anio, p_nivel, p_numero, 'CAS');
BEGIN
    RETURN QUERY SELECT * FROM academico.fn_progreso_cas(ARRAY[v_id_asignacion], p_semestre, FALSE);
END;
$$;

CREATE OR REPLACE FUNCTION academico.fn_profesor_cas_obtener_informe(
    p_id_usuario UUID, p_anio INTEGER, p_semestre academico.numero_semestre, p_cedula_estudiante TEXT)
RETURNS SETOF academico.informe_cas
LANGUAGE plpgsql STABLE
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_ids RECORD;
BEGIN
    SELECT * INTO v_ids FROM academico.fn_obtener_mi_asignacion_cas(p_id_usuario, p_anio, p_cedula_estudiante);

    RETURN QUERY
    SELECT (d.fila).* FROM academico.fn_informes_cas_detalle(FALSE) d
    WHERE d.id_asignacion = v_ids.id_asignacion AND d.id_matricula = v_ids.id_matricula AND (d.fila).semestre = p_semestre;

    IF NOT FOUND THEN
        PERFORM api.fn_lanzar_excepcion('NF015', 'El informe CAS no existe.');
    END IF;
END;
$$;

-- ------------------------------------------------------------
-- Coordinador de CAS CU01 - Progreso CAS general (RN-84): todas las secciones del año con CAS, o una sección.
-- La nota solo aparece si el profesor ya la envió.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION academico.fn_coordinador_cas_progreso(
    p_anio INTEGER, p_nivel INTEGER, p_numero INTEGER, p_semestre academico.numero_semestre)
RETURNS SETOF academico.progreso_cas
LANGUAGE plpgsql STABLE
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_ids BIGINT[];
BEGIN
    SELECT COALESCE(array_agg(ad.id_asignacion), ARRAY[]::BIGINT[]) INTO v_ids
    FROM academico.fn_asignaciones_detalle() ad
    WHERE (ad.fila).codigo_asignatura = 'CAS' AND (ad.fila).anio = p_anio
      AND (p_nivel IS NULL OR (ad.fila).nivel = p_nivel)
      AND (p_numero IS NULL OR (ad.fila).numero = p_numero);

    RETURN QUERY SELECT * FROM academico.fn_progreso_cas(v_ids, p_semestre, TRUE);
END;
$$;

-- ------------------------------------------------------------
-- Coordinador de CAS CU02 - Generar el reporte CAS de un estudiante en un semestre (RN-84): los informes CAS del
-- estudiante (uno por profesor CAS de su sección). NF015 si no hay ninguno.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION academico.fn_coordinador_cas_informes(
    p_anio INTEGER, p_semestre academico.numero_semestre, p_cedula_estudiante TEXT)
RETURNS SETOF academico.informe_cas
LANGUAGE plpgsql STABLE
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_id_matricula BIGINT := academico.fn_obtener_id_matricula(p_anio, p_cedula_estudiante);
BEGIN
    RETURN QUERY
    SELECT (d.fila).* FROM academico.fn_informes_cas_detalle(TRUE) d
    WHERE d.id_matricula = v_id_matricula AND (d.fila).semestre = p_semestre
    ORDER BY (d.fila).nombre_profesor;

    IF NOT FOUND THEN
        PERFORM api.fn_lanzar_excepcion('NF015', 'El informe CAS no existe.');
    END IF;
END;
$$;
