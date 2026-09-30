-- ============================================================
-- 18_informes.sql: reporte de bandas del guía (Guía CU08 por estudiante y CU09 de toda la sección).
-- El backend devuelve los datos y el front arma el PDF (RN-85). Por estudiante y asignación del semestre:
-- banda o nota mínima, nota alcanzada (solo si el profesor ya la envió), ausentismo (tardías, injustificadas y
-- justificadas) y observaciones del profesor. CAS no va en este reporte: tiene su propio informe (RN-83).
-- La sección de monografía sale de fn_guia_reportes_monografia (16).
-- ============================================================
SET search_path = academico, api, auth, public;

CREATE TYPE academico.fila_reporte_bandas AS (
    cedula_estudiante VARCHAR(20),
    nombre_estudiante TEXT,
    codigo_asignatura VARCHAR(10),    -- NULL si la sección no tiene asignaciones
    asignatura TEXT,
    tipo_asignatura academico.tipo_asignatura,
    nombre_profesor TEXT,
    nota_minima VARCHAR(3),
    nota VARCHAR(3),
    aprobada BOOLEAN,
    tardias INTEGER,
    injustificadas INTEGER,
    justificadas INTEGER,
    observaciones VARCHAR(500)
);

-- ------------------------------------------------------------
-- Guía CU08 / CU09 - Reporte de bandas de la sección guía en un semestre (AD005). p_cedula_estudiante NULL = toda
-- la sección; NF009 si el estudiante no se califica en la sección ese semestre.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION academico.fn_guia_reporte_bandas(
    p_id_usuario UUID, p_anio INTEGER, p_nivel INTEGER, p_numero INTEGER, p_semestre academico.numero_semestre,
    p_cedula_estudiante TEXT)
RETURNS SETOF academico.fila_reporte_bandas
LANGUAGE plpgsql STABLE
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_id_seccion BIGINT := academico.fn_validar_guia_seccion(p_id_usuario, p_anio, p_nivel, p_numero);
    v_cedula TEXT := api.fn_limpiar(p_cedula_estudiante);
BEGIN
    IF v_cedula IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM academico.fn_matriculas_del_semestre(v_id_seccion, p_semestre) ms
        JOIN academico.estudiantes e ON e.id_estudiante = ms.id_estudiante
        WHERE e.cedula = v_cedula
    ) THEN
        PERFORM api.fn_lanzar_excepcion('NF009', 'El estudiante no está matriculado en la sección ese semestre.');
    END IF;

    RETURN QUERY
    WITH conteo AS (SELECT * FROM academico.fn_conteo_ausentismo(v_id_seccion, NULL, p_semestre))
    SELECT (d.fila).cedula_estudiante, (d.fila).nombre_estudiante,
           asg.codigo, asg.nombre::TEXT, asg.tipo, (ad.fila).nombre_profesor,
           academico.fn_nota_minima(asg.tipo)::VARCHAR(3),
           CASE WHEN en.id_asignacion IS NOT NULL THEN ev.nota END::VARCHAR(3),
           CASE WHEN en.id_asignacion IS NOT NULL THEN academico.fn_nota_aprobada(asg.tipo, ev.nota) END,
           c.tardias, c.ausencias - c.justificadas, c.justificadas,
           CASE WHEN en.id_asignacion IS NOT NULL THEN ev.observaciones END::VARCHAR(500)
    FROM academico.fn_matriculas_del_semestre(v_id_seccion, p_semestre) ms
    JOIN academico.fn_matriculas_detalle() d ON d.id_matricula = ms.id_matricula
    LEFT JOIN (academico.asignaciones_docentes a
               JOIN academico.asignaturas asg ON asg.id_asignatura = a.id_asignatura AND asg.codigo <> 'CAS')
           ON a.id_seccion = v_id_seccion
    LEFT JOIN academico.fn_asignaciones_detalle() ad ON ad.id_asignacion = a.id_asignacion
    LEFT JOIN academico.envios_notas en ON en.id_asignacion = a.id_asignacion AND en.semestre = p_semestre
    LEFT JOIN academico.evaluaciones ev
           ON ev.id_asignacion = a.id_asignacion AND ev.id_matricula = ms.id_matricula AND ev.semestre = p_semestre
    LEFT JOIN conteo c ON c.id_matricula = ms.id_matricula AND c.id_asignacion = a.id_asignacion
    WHERE v_cedula IS NULL OR (d.fila).cedula_estudiante = v_cedula
    ORDER BY d.apellidos_nombre, asg.tipo, asg.nombre, (ad.fila).nombre_profesor;
END;
$$;
