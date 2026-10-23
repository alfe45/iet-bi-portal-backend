-- Permite al Profesor Guía reactivar la edición de las bandas de un estudiante.
CREATE OR REPLACE FUNCTION academico.fn_guia_reactivar_bandas(
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
    v_id_matricula BIGINT;
    v_reactivadas INTEGER;
BEGIN
    SELECT ms.id_matricula INTO v_id_matricula
    FROM academico.fn_matriculas_del_semestre(v_id_seccion, p_semestre) ms
    JOIN academico.estudiantes e ON e.id_estudiante = ms.id_estudiante
    WHERE e.cedula = api.fn_limpiar_cedula(p_cedula_estudiante);
    IF NOT FOUND THEN
        PERFORM api.fn_lanzar_excepcion('NF009', 'El estudiante no está matriculado en la sección ese semestre.');
    END IF;

    DELETE FROM academico.confirmaciones_notas cn
    USING academico.asignaciones_docentes a
    WHERE cn.id_asignacion = a.id_asignacion
      AND a.id_seccion = v_id_seccion
      AND cn.semestre = p_semestre
      AND EXISTS (
          SELECT 1 FROM academico.evaluaciones ev
          WHERE ev.id_asignacion = a.id_asignacion
            AND ev.id_matricula = v_id_matricula
            AND ev.semestre = p_semestre
      );
    GET DIAGNOSTICS v_reactivadas = ROW_COUNT;

    RETURN jsonb_build_object('cedulaEstudiante', api.fn_limpiar_cedula(p_cedula_estudiante),
                              'semestre', p_semestre, 'confirmacionesReactivadas', v_reactivadas);
END;
$$;
