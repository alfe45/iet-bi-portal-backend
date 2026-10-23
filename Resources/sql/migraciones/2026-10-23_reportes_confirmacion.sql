-- Permite distinguir un reporte de monografía guardado de uno confirmado al Profesor Guía.
ALTER TABLE academico.reportes_monografia
    ALTER COLUMN enviado_en DROP NOT NULL,
    ALTER COLUMN enviado_en DROP DEFAULT;

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
    SELECT p.* INTO v_periodo
    FROM academico.periodos_academicos p
    JOIN academico.matriculas m ON m.id_periodo = p.id_periodo
    WHERE m.id_matricula = v_id_matricula;
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
    v_observaciones TEXT := api.fn_limpiar(p_observaciones);
BEGIN
    SELECT p.* INTO v_periodo
    FROM academico.periodos_academicos p
    JOIN academico.matriculas m ON m.id_periodo = p.id_periodo
    WHERE m.id_matricula = v_id_matricula;
    PERFORM academico.fn_validar_plazo_notas(v_mono.id_coordinador, v_periodo, p_semestre);

    IF v_observaciones IS NULL OR length(trim(v_observaciones)) < 3 OR length(v_observaciones) > 1000 THEN
        PERFORM api.fn_lanzar_excepcion('MO009', 'No se puede guardar el reporte de monografía: la información está incompleta.');
    END IF;

    IF EXISTS (
        SELECT 1 FROM academico.reportes_monografia
        WHERE id_monografia = v_mono.id_monografia AND id_periodo = v_periodo.id_periodo AND semestre = p_semestre
          AND enviado_en IS NOT NULL
    ) THEN
        PERFORM api.fn_lanzar_excepcion('MO008', 'Este reporte ya fue confirmado al Profesor Guía y su edición está bloqueada. Solo el Profesor Guía puede reactivarlo para que usted pueda corregirlo y confirmarlo nuevamente.');
    END IF;

    INSERT INTO academico.reportes_monografia (id_monografia, id_periodo, semestre, observaciones, enviado_en)
    VALUES (v_mono.id_monografia, v_periodo.id_periodo, p_semestre, v_observaciones, NULL)
    ON CONFLICT (id_monografia, id_periodo, semestre) DO UPDATE
       SET observaciones = EXCLUDED.observaciones, enviado_en = NULL;
END;
$$;
