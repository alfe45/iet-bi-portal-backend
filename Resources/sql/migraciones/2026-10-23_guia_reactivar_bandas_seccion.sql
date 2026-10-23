-- Permite al Profesor Guía reactivar la edición de las bandas de toda su sección.
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
    v_reactivadas INTEGER;
BEGIN
    DELETE FROM academico.confirmaciones_notas cn
    USING academico.asignaciones_docentes a
    WHERE cn.id_asignacion = a.id_asignacion
      AND a.id_seccion = v_id_seccion
      AND cn.semestre = p_semestre;
    GET DIAGNOSTICS v_reactivadas = ROW_COUNT;

    RETURN jsonb_build_object('seccion', format('%s-%s', p_nivel, p_numero),
                              'semestre', p_semestre, 'confirmacionesReactivadas', v_reactivadas);
END;
$$;
