-- Permite al Profesor Guía reactivar la edición de un reporte de monografía confirmado.
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
    v_id_periodo BIGINT;
    v_id_monografia BIGINT;
    v_prev academico.reportes_monografia%ROWTYPE;
BEGIN
    SELECT id_periodo INTO v_id_periodo
    FROM academico.periodos_academicos
    WHERE anio = p_anio;
    IF NOT FOUND THEN
        PERFORM api.fn_lanzar_excepcion('NF004', 'El periodo académico no existe.');
    END IF;

    SELECT mo.id_monografia INTO v_id_monografia
    FROM academico.monografias mo
    JOIN academico.matriculas m ON m.id_estudiante = mo.id_estudiante
    WHERE m.id_seccion = v_id_seccion
      AND mo.id_estudiante = (SELECT id_estudiante FROM academico.estudiantes WHERE cedula = api.fn_limpiar_cedula(p_cedula_estudiante));
    IF NOT FOUND THEN
        PERFORM api.fn_lanzar_excepcion('NF013', 'El estudiante no tiene monografía.');
    END IF;

    SELECT * INTO v_prev
    FROM academico.reportes_monografia
    WHERE id_monografia = v_id_monografia AND id_periodo = v_id_periodo AND semestre = p_semestre
    FOR UPDATE;
    IF NOT FOUND THEN
        PERFORM api.fn_lanzar_excepcion('NF017', 'El reporte de monografía no existe.');
    END IF;

    UPDATE academico.reportes_monografia
    SET enviado_en = NULL
    WHERE id_monografia = v_id_monografia AND id_periodo = v_id_periodo AND semestre = p_semestre;

    RETURN jsonb_build_object('anio', p_anio, 'semestre', p_semestre, 'observaciones', v_prev.observaciones,
                              'enviadoEn', v_prev.enviado_en, 'confirmacionAnulada', v_prev.enviado_en IS NOT NULL);
END;
$$;
