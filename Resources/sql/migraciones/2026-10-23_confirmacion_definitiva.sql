-- Migración del 23/10/2026 (PR #17 de Jeferson, corregido): la confirmación de notas y de reportes de monografía es
-- definitiva hasta que el Profesor Guía reactive la edición (RN-75, RN-81).
-- Para una base con datos (Neon): no recrea tablas ni borra datos. Ejecutar completo con el dueño de la base:
--   psql -v ON_ERROR_STOP=1 -f Resources/sql/migraciones/2026-10-23_confirmacion_definitiva.sql
-- y luego reiniciar la API. Las funciones son copia de los scripts 14, 15, 16 y 18.
BEGIN;
SET search_path = academico, api, auth, public;

-- 06: el reporte de monografía puede quedar como borrador (enviado_en NULL = sin confirmar).
ALTER TABLE academico.reportes_monografia
    ALTER COLUMN enviado_en DROP NOT NULL,
    ALTER COLUMN enviado_en DROP DEFAULT;

CREATE OR REPLACE FUNCTION academico.fn_validar_notas_sin_confirmar(p_id_asignacion BIGINT, p_semestre academico.numero_semestre)
RETURNS VOID
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
BEGIN
    PERFORM 1 FROM academico.asignaciones_docentes WHERE id_asignacion = p_id_asignacion FOR UPDATE;
    IF EXISTS (SELECT 1 FROM academico.confirmaciones_notas WHERE id_asignacion = p_id_asignacion AND semestre = p_semestre) THEN
        PERFORM api.fn_lanzar_excepcion('EV008', 'Las notas de la asignación ya están confirmadas.');
    END IF;
END;
$$;

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
    -- RP-57: el tipo de la asignatura (escala, AS006) y las matrículas (traslado, retiro) no cambian mientras se califica.
    PERFORM academico.fn_bloquear_asignatura((SELECT a.id_asignatura FROM academico.asignaciones_docentes a WHERE a.id_asignacion = v_id_asignacion));
    SELECT * INTO v FROM academico.fn_datos_asignacion(v_id_asignacion);
    PERFORM academico.fn_validar_plazo_notas(v.id_profesor, v.periodo, p_semestre);
    PERFORM academico.fn_validar_notas_sin_confirmar(v_id_asignacion, p_semestre);
    PERFORM academico.fn_bloquear_matriculas((v.periodo).id_periodo,
        ARRAY(SELECT api.fn_limpiar_cedula(x->>'cedulaEstudiante') FROM jsonb_array_elements(COALESCE(p_notas, '[]'::jsonb)) x));

    FOR v_item IN SELECT * FROM jsonb_array_elements(COALESCE(p_notas, '[]'::jsonb)) LOOP
        v_cedula := api.fn_limpiar_cedula(v_item->>'cedulaEstudiante');
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
        out_datos_anteriores := jsonb_build_object('notas', v_cambios);
    END IF;
END;
$$;

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
BEGIN
    SELECT * INTO v FROM academico.fn_datos_asignacion(v_id_asignacion);
    PERFORM academico.fn_validar_plazo_notas(v.id_profesor, v.periodo, p_semestre);
    PERFORM academico.fn_validar_notas_sin_confirmar(v_id_asignacion, p_semestre);

    DELETE FROM academico.evaluaciones
    WHERE id_asignacion = v_id_asignacion AND id_matricula = v_id_matricula AND semestre = p_semestre
    RETURNING * INTO v_prev;

    IF v_prev.id_evaluacion IS NULL THEN
        PERFORM api.fn_lanzar_excepcion('NF016', 'El estudiante no tiene nota en esa asignación y semestre.');
    END IF;

    RETURN jsonb_build_object('cedulaEstudiante', api.fn_limpiar_cedula(p_cedula_estudiante), 'nota', v_prev.nota,
                              'observaciones', v_prev.observaciones);
END;
$$;

CREATE OR REPLACE FUNCTION academico.fn_profesor_confirmar_notas(
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
    PERFORM 1 FROM academico.asignaciones_docentes WHERE id_asignacion = v_id_asignacion FOR UPDATE;   -- RP-57

    IF EXISTS (SELECT 1 FROM academico.fn_notas_asignacion(v_id_asignacion, p_semestre) n WHERE n.nota IS NULL) THEN
        PERFORM api.fn_lanzar_excepcion('EV006', 'Hay estudiantes sin nota.');
    END IF;

    INSERT INTO academico.confirmaciones_notas (id_asignacion, semestre) VALUES (v_id_asignacion, p_semestre)
    ON CONFLICT (id_asignacion, semestre) DO NOTHING;

    RETURN CASE WHEN FOUND THEN 'OK' ELSE 'SIN_CAMBIOS' END;
END;
$$;

CREATE OR REPLACE FUNCTION academico.fn_coordinador_enviar_reporte_monografia(
    p_id_usuario UUID,
    p_cedula_estudiante TEXT,
    p_anio INTEGER,
    p_semestre academico.numero_semestre,
    p_observaciones TEXT,
    OUT out_status TEXT,
    OUT out_datos_anteriores JSONB
)
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_mono academico.monografias := academico.fn_obtener_mi_monografia(p_id_usuario, p_cedula_estudiante);
    v_id_matricula BIGINT := academico.fn_obtener_id_matricula(p_anio, p_cedula_estudiante);
    v_periodo academico.periodos_academicos%ROWTYPE;
    v_prev academico.reportes_monografia%ROWTYPE;
    v_observaciones TEXT := api.fn_limpiar(p_observaciones);
BEGIN
    SELECT p.* INTO v_periodo FROM academico.periodos_academicos p
    JOIN academico.matriculas m ON m.id_periodo = p.id_periodo WHERE m.id_matricula = v_id_matricula;
    PERFORM academico.fn_validar_plazo_notas(v_mono.id_coordinador, v_periodo, p_semestre);

    IF v_observaciones IS NULL OR length(trim(v_observaciones)) < 3 OR length(v_observaciones) > 1000 THEN
        PERFORM api.fn_lanzar_excepcion('MO009', 'No se puede confirmar el reporte de monografía: la información está incompleta.');
    END IF;

    SELECT * INTO v_prev FROM academico.reportes_monografia
    WHERE id_monografia = v_mono.id_monografia AND id_periodo = v_periodo.id_periodo AND semestre = p_semestre
    FOR UPDATE;

    IF FOUND THEN
        IF v_prev.enviado_en IS NOT NULL THEN
            PERFORM api.fn_lanzar_excepcion('MO008', 'Este reporte ya fue confirmado al Profesor Guía y su edición está bloqueada. Solo el Profesor Guía puede reactivarlo para que usted pueda corregirlo y confirmarlo nuevamente.');
        END IF;
        out_datos_anteriores := jsonb_build_object('anio', p_anio, 'semestre', p_semestre, 'observaciones', v_prev.observaciones);
        UPDATE academico.reportes_monografia SET observaciones = v_observaciones, enviado_en = NOW()
        WHERE id_monografia = v_mono.id_monografia AND id_periodo = v_periodo.id_periodo AND semestre = p_semestre;
    ELSE
        INSERT INTO academico.reportes_monografia (id_monografia, id_periodo, semestre, observaciones, enviado_en)
        VALUES (v_mono.id_monografia, v_periodo.id_periodo, p_semestre, v_observaciones, NOW());
    END IF;

    out_status := 'OK';
END;
$$;

CREATE OR REPLACE FUNCTION academico.fn_coordinador_guardar_borrador_reporte_monografia(
    p_id_usuario UUID,
    p_cedula_estudiante TEXT,
    p_anio INTEGER,
    p_semestre academico.numero_semestre,
    p_observaciones TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_mono academico.monografias := academico.fn_obtener_mi_monografia(p_id_usuario, p_cedula_estudiante);
    v_id_matricula BIGINT := academico.fn_obtener_id_matricula(p_anio, p_cedula_estudiante);
    v_periodo academico.periodos_academicos%ROWTYPE;
    v_prev academico.reportes_monografia%ROWTYPE;
    v_observaciones TEXT := api.fn_limpiar(p_observaciones);
BEGIN
    SELECT p.* INTO v_periodo
    FROM academico.periodos_academicos p
    JOIN academico.matriculas m ON m.id_periodo = p.id_periodo
    WHERE m.id_matricula = v_id_matricula;
    PERFORM academico.fn_validar_plazo_notas(v_mono.id_coordinador, v_periodo, p_semestre);

    IF v_observaciones IS NULL OR length(trim(v_observaciones)) < 3 OR length(v_observaciones) > 1000 THEN
        PERFORM api.fn_lanzar_excepcion('MO009', 'Las observaciones del reporte deben tener entre 3 y 1000 caracteres.');
    END IF;

    SELECT * INTO v_prev FROM academico.reportes_monografia
    WHERE id_monografia = v_mono.id_monografia AND id_periodo = v_periodo.id_periodo AND semestre = p_semestre
    FOR UPDATE;
    IF FOUND AND v_prev.enviado_en IS NOT NULL THEN
        PERFORM api.fn_lanzar_excepcion('MO008', 'Este reporte ya fue confirmado al Profesor Guía y su edición está bloqueada. Solo el Profesor Guía puede reactivarlo para que usted pueda corregirlo y confirmarlo nuevamente.');
    END IF;

    INSERT INTO academico.reportes_monografia (id_monografia, id_periodo, semestre, observaciones, enviado_en)
    VALUES (v_mono.id_monografia, v_periodo.id_periodo, p_semestre, v_observaciones, NULL)
    ON CONFLICT (id_monografia, id_periodo, semestre) DO UPDATE
       SET observaciones = EXCLUDED.observaciones, enviado_en = NULL;
END;
$$;

CREATE OR REPLACE FUNCTION academico.fn_coordinador_eliminar_reporte_monografia(
    p_id_usuario UUID, p_cedula_estudiante TEXT, p_anio INTEGER, p_semestre academico.numero_semestre)
RETURNS JSONB
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_mono academico.monografias := academico.fn_obtener_mi_monografia(p_id_usuario, p_cedula_estudiante);
    v_periodo academico.periodos_academicos%ROWTYPE;
    v_prev academico.reportes_monografia%ROWTYPE;
BEGIN
    SELECT * INTO v_periodo FROM academico.periodos_academicos WHERE anio = p_anio;
    IF NOT FOUND THEN
        PERFORM api.fn_lanzar_excepcion('NF004', 'El periodo académico no existe.');
    END IF;
    PERFORM academico.fn_validar_plazo_notas(v_mono.id_coordinador, v_periodo, p_semestre);

    SELECT * INTO v_prev FROM academico.reportes_monografia
    WHERE id_monografia = v_mono.id_monografia AND id_periodo = v_periodo.id_periodo AND semestre = p_semestre
    FOR UPDATE;
    IF NOT FOUND THEN
        PERFORM api.fn_lanzar_excepcion('NF017', 'El reporte de monografía no existe.');
    END IF;
    IF v_prev.enviado_en IS NOT NULL THEN
        PERFORM api.fn_lanzar_excepcion('MO008', 'Este reporte ya fue confirmado al Profesor Guía y su edición está bloqueada. Solo el Profesor Guía puede reactivarlo para que usted pueda corregirlo y confirmarlo nuevamente.');
    END IF;

    DELETE FROM academico.reportes_monografia
    WHERE id_monografia = v_mono.id_monografia AND id_periodo = v_periodo.id_periodo AND semestre = p_semestre;

    RETURN jsonb_build_object('anio', p_anio, 'semestre', p_semestre, 'observaciones', v_prev.observaciones);
END;
$$;

CREATE OR REPLACE FUNCTION academico.fn_guia_permitir_cambios_reporte_monografia(
    p_id_usuario UUID,
    p_anio INTEGER,
    p_nivel INTEGER,
    p_numero INTEGER,
    p_cedula_estudiante TEXT,
    p_semestre academico.numero_semestre)
RETURNS JSONB
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_id_seccion BIGINT := academico.fn_validar_guia_seccion(p_id_usuario, p_anio, p_nivel, p_numero);
    v_periodo academico.periodos_academicos%ROWTYPE;
    v_id_monografia BIGINT;
    v_id_coordinador BIGINT;
    v_prev academico.reportes_monografia%ROWTYPE;
BEGIN
    SELECT p.* INTO v_periodo FROM academico.periodos_academicos p WHERE p.anio = p_anio;

    SELECT mo.id_monografia, mo.id_coordinador INTO v_id_monografia, v_id_coordinador
    FROM academico.monografias mo
    JOIN academico.matriculas m ON m.id_estudiante = mo.id_estudiante
    WHERE m.id_seccion = v_id_seccion
      AND mo.id_estudiante = (SELECT id_estudiante FROM academico.estudiantes WHERE cedula = api.fn_limpiar_cedula(p_cedula_estudiante));
    IF NOT FOUND THEN
        PERFORM api.fn_lanzar_excepcion('NF013', 'El estudiante no tiene monografía.');
    END IF;

    PERFORM academico.fn_validar_plazo_notas(v_id_coordinador, v_periodo, p_semestre);

    SELECT * INTO v_prev
    FROM academico.reportes_monografia
    WHERE id_monografia = v_id_monografia AND id_periodo = v_periodo.id_periodo AND semestre = p_semestre
    FOR UPDATE;
    IF NOT FOUND THEN
        PERFORM api.fn_lanzar_excepcion('NF017', 'El reporte de monografía no existe.');
    END IF;
    IF v_prev.enviado_en IS NULL THEN
        RETURN NULL;
    END IF;

    UPDATE academico.reportes_monografia
    SET enviado_en = NULL
    WHERE id_monografia = v_id_monografia AND id_periodo = v_periodo.id_periodo AND semestre = p_semestre;

    RETURN jsonb_build_object('anio', p_anio, 'semestre', p_semestre, 'observaciones', v_prev.observaciones,
                              'enviadoEn', v_prev.enviado_en);
END;
$$;

CREATE OR REPLACE FUNCTION academico.fn_guia_reactivar_bandas_seccion(
    p_id_usuario UUID,
    p_anio INTEGER,
    p_nivel INTEGER,
    p_numero INTEGER,
    p_semestre academico.numero_semestre)
RETURNS JSONB
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_id_seccion BIGINT := academico.fn_validar_guia_seccion(p_id_usuario, p_anio, p_nivel, p_numero);
    v_periodo academico.periodos_academicos%ROWTYPE;
    v_confirmadas INTEGER;
    v_reactivadas JSONB;
BEGIN
    IF p_semestre IS NULL THEN
        PERFORM api.fn_lanzar_excepcion('22P02', 'Falta el semestre.');
    END IF;
    SELECT p.* INTO v_periodo FROM academico.periodos_academicos p WHERE p.anio = p_anio;

    -- RP-57: las asignaciones de la sección se bloquean (confirmar y corregir esperan).
    PERFORM 1 FROM academico.asignaciones_docentes WHERE id_seccion = v_id_seccion ORDER BY id_asignacion FOR UPDATE;

    SELECT count(*) INTO v_confirmadas
    FROM academico.confirmaciones_notas cn
    JOIN academico.asignaciones_docentes a ON a.id_asignacion = cn.id_asignacion
    WHERE a.id_seccion = v_id_seccion AND cn.semestre = p_semestre;
    IF v_confirmadas = 0 THEN
        RETURN NULL;
    END IF;

    WITH borradas AS (
        DELETE FROM academico.confirmaciones_notas cn
        USING academico.asignaciones_docentes a
        WHERE cn.id_asignacion = a.id_asignacion
          AND a.id_seccion = v_id_seccion
          AND cn.semestre = p_semestre
          AND api.fn_hoy() BETWEEN academico.fn_inicio_semestre(v_periodo, p_semestre)
                               AND academico.fn_cierre_notas(a.id_profesor, v_periodo, p_semestre)
        RETURNING a.id_asignatura, a.id_profesor
    )
    SELECT jsonb_agg(jsonb_build_object('asignatura', asg.codigo, 'cedulaProfesor', pr.cedula) ORDER BY asg.codigo)
    INTO v_reactivadas
    FROM borradas b
    JOIN academico.asignaturas asg ON asg.id_asignatura = b.id_asignatura
    JOIN academico.profesores pr ON pr.id_profesor = b.id_profesor;

    IF v_reactivadas IS NULL THEN
        PERFORM api.fn_lanzar_excepcion('EV003', 'El plazo de notas del semestre cerró para todas las asignaturas confirmadas.');
    END IF;

    RETURN jsonb_build_object('seccion', format('%s-%s', p_nivel, p_numero), 'semestre', p_semestre,
                              'reactivadas', v_reactivadas);
END;
$$;

-- 14: el ausentismo confirmado no cambia (EV009).
CREATE OR REPLACE FUNCTION academico.fn_bloquear_cambios_confirmados()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_fila RECORD;
    v_id_asignacion BIGINT;
    v_fecha DATE;
    v_semestre academico.numero_semestre;
    v_confirmado DATE;
BEGIN
    IF TG_OP = 'DELETE' THEN v_fila := OLD; ELSE v_fila := NEW; END IF;
    IF TG_TABLE_NAME = 'lecciones' THEN
        v_id_asignacion := v_fila.id_asignacion;
        v_fecha := v_fila.fecha;
    ELSE
        SELECT l.id_asignacion, l.fecha INTO v_id_asignacion, v_fecha
        FROM academico.lecciones l WHERE l.id_leccion = v_fila.id_leccion;
    END IF;
    IF v_id_asignacion IS NULL THEN
        RETURN v_fila;
    END IF;

    v_semestre := academico.fn_semestre_en_fecha(academico.fn_periodo_de_asignacion(v_id_asignacion), v_fecha);
    SELECT (cn.confirmado_en AT TIME ZONE 'America/Costa_Rica')::DATE INTO v_confirmado
    FROM academico.confirmaciones_notas cn
    WHERE cn.id_asignacion = v_id_asignacion AND cn.semestre = v_semestre;
    IF v_confirmado IS NOT NULL AND v_fecha <= v_confirmado THEN
        PERFORM api.fn_lanzar_excepcion('EV009', 'El ausentismo de esa fecha ya quedó confirmado con las notas del semestre.');
    END IF;
    RETURN v_fila;
END;
$$;

DROP TRIGGER IF EXISTS trg_bloquear_cambios_confirmados_lecciones ON academico.lecciones;
CREATE TRIGGER trg_bloquear_cambios_confirmados_lecciones
BEFORE INSERT OR UPDATE OR DELETE ON academico.lecciones
FOR EACH ROW EXECUTE FUNCTION academico.fn_bloquear_cambios_confirmados();

DROP TRIGGER IF EXISTS trg_bloquear_cambios_confirmados_ausencias ON academico.ausencias;
CREATE TRIGGER trg_bloquear_cambios_confirmados_ausencias
BEFORE INSERT OR UPDATE OR DELETE ON academico.ausencias
FOR EACH ROW EXECUTE FUNCTION academico.fn_bloquear_cambios_confirmados();

COMMIT;
