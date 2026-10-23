-- La confirmación de notas se realiza una sola vez por semestre y bloquea
-- cualquier modificación o eliminación posterior de la asignación.

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
    PERFORM academico.fn_bloquear_asignatura((SELECT a.id_asignatura FROM academico.asignaciones_docentes a WHERE a.id_asignacion = v_id_asignacion));
    SELECT * INTO v FROM academico.fn_datos_asignacion(v_id_asignacion);
    PERFORM academico.fn_validar_plazo_notas(v.id_profesor, v.periodo, p_semestre);

    IF EXISTS (SELECT 1 FROM academico.confirmaciones_notas WHERE id_asignacion = v_id_asignacion AND semestre = p_semestre) THEN
        PERFORM api.fn_lanzar_excepcion('EV008', 'Las notas de esta asignatura ya fueron confirmadas al Profesor Guía y están bloqueadas. Solo el Profesor Guía puede reactivar su edición para que usted pueda corregirlas y confirmarlas nuevamente.');
    END IF;

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

-- También bloquea cambios de ausentismo de la asignación confirmada.
CREATE OR REPLACE FUNCTION academico.fn_bloquear_cambios_confirmados()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_id_asignacion BIGINT;
    v_fecha DATE;
    v_periodo academico.periodos_academicos;
    v_semestre academico.numero_semestre;
BEGIN
    IF TG_TABLE_NAME = 'lecciones' THEN
        v_id_asignacion := CASE WHEN TG_OP = 'DELETE' THEN OLD.id_asignacion ELSE NEW.id_asignacion END;
        v_fecha := CASE WHEN TG_OP = 'DELETE' THEN OLD.fecha ELSE NEW.fecha END;
    ELSE
        SELECT l.id_asignacion, l.fecha INTO v_id_asignacion, v_fecha
        FROM academico.lecciones l
        WHERE l.id_leccion = CASE WHEN TG_OP = 'DELETE' THEN OLD.id_leccion ELSE NEW.id_leccion END;
    END IF;

    IF v_id_asignacion IS NULL OR v_fecha IS NULL THEN
        RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
    END IF;

    v_periodo := academico.fn_periodo_de_asignacion(v_id_asignacion);
    v_semestre := academico.fn_semestre_en_fecha(v_periodo, v_fecha);
    IF EXISTS (SELECT 1 FROM academico.confirmaciones_notas WHERE id_asignacion = v_id_asignacion AND semestre = v_semestre) THEN
        PERFORM api.fn_lanzar_excepcion('EV008', 'Las notas de esta asignatura ya fueron confirmadas al Profesor Guía y están bloqueadas. Solo el Profesor Guía puede reactivar su edición para que usted pueda corregirlas y confirmarlas nuevamente.');
    END IF;
    RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
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

CREATE OR REPLACE FUNCTION academico.fn_profesor_eliminar_nota(
    p_id_usuario UUID,
    p_anio INTEGER,
    p_nivel INTEGER,
    p_numero INTEGER,
    p_codigo_asignatura TEXT,
    p_semestre academico.numero_semestre,
    p_cedula_estudiante TEXT)
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

    IF EXISTS (SELECT 1 FROM academico.confirmaciones_notas WHERE id_asignacion = v_id_asignacion AND semestre = p_semestre) THEN
        PERFORM api.fn_lanzar_excepcion('EV008', 'Las notas de esta asignatura ya fueron confirmadas al Profesor Guía y están bloqueadas. Solo el Profesor Guía puede reactivar su edición para que usted pueda corregirlas y confirmarlas nuevamente.');
    END IF;

    DELETE FROM academico.evaluaciones
    WHERE id_asignacion = v_id_asignacion AND id_matricula = v_id_matricula AND semestre = p_semestre
    RETURNING * INTO v_prev;

    IF v_prev.id_evaluacion IS NULL THEN
        PERFORM api.fn_lanzar_excepcion('NF016', 'El estudiante no tiene nota en esa asignación y semestre.');
    END IF;

    RETURN jsonb_build_object('cedulaEstudiante', api.fn_limpiar_cedula(p_cedula_estudiante), 'nota', v_prev.nota,
                              'observaciones', v_prev.observaciones, 'confirmacionAnulada', false);
END;
$$;
