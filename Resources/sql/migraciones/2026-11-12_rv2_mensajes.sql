-- ============================================================
-- Migración 2026-11-12 (revalidación ronda 2): mensajes de error que piden las specs.
--  * Profesor Regular CU12 (correo): una cédula elegida que no está matriculada en la sección (o se retiró) responde
--    CO006 "Un estudiante elegido no está matriculado en la sección o se retiró." (antes NF009 "La matrícula no existe.").
--  * Guía CU08 (reporte de bandas de un estudiante): el estudiante que no se califica en la sección ese semestre responde
--    EV004 (antes NF009 "La matrícula no existe.").
-- Solo reemplaza funciones; no toca datos. Después de ejecutarla, reiniciar la API.
-- ============================================================
SET search_path = academico, api, auth, public;

-- Profesor Regular CU12 - Destinatarios del correo a una sección (RN-92). Mismo acceso de RN-59 (AD003). Estudiantes
-- matriculados en la sección sin retiro: todos (p_cedulas NULL o vacío) o los elegidos, CO006 si alguna cédula no está
-- matriculada en la sección o está retirada; CO003 si no queda nadie. Cada fila trae también el nombre y el correo del
-- profesor (remitente para responder). El envío lo hace el backend: esta función no modifica datos.
CREATE OR REPLACE FUNCTION academico.fn_profesor_destinatarios_correo(
    p_id_usuario UUID, p_anio INTEGER, p_nivel INTEGER, p_numero INTEGER, p_cedulas TEXT[])
RETURNS TABLE (cedula VARCHAR(20), nombre_estudiante TEXT, email CITEXT, nombre_profesor TEXT, email_profesor CITEXT)
LANGUAGE plpgsql STABLE
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_id_seccion BIGINT := academico.fn_obtener_id_seccion(p_anio, p_nivel, p_numero);
    v_cedulas TEXT[] := (SELECT array_agg(DISTINCT api.fn_limpiar_cedula(c)) FROM unnest(p_cedulas) c
                         WHERE nullif(trim(c), '') IS NOT NULL);
BEGIN
    PERFORM academico.fn_validar_acceso_seccion(p_id_usuario, v_id_seccion);

    IF v_cedulas IS NOT NULL AND EXISTS (
        SELECT 1 FROM unnest(v_cedulas) c
        WHERE NOT EXISTS (SELECT 1 FROM academico.matriculas m
                          JOIN academico.estudiantes e ON e.id_estudiante = m.id_estudiante
                          WHERE m.id_seccion = v_id_seccion AND m.fecha_retiro IS NULL AND e.cedula = c)) THEN
        PERFORM api.fn_lanzar_excepcion('CO006', 'El estudiante no está matriculado en esa sección.');
    END IF;

    RETURN QUERY
    SELECT e.cedula, concat_ws(' ', e.nombre, e.primer_apellido, e.segundo_apellido), e.email,
           concat_ws(' ', pr.nombre, pr.primer_apellido, pr.segundo_apellido), u.email
    FROM academico.matriculas m
    JOIN academico.estudiantes e ON e.id_estudiante = m.id_estudiante
    CROSS JOIN academico.profesores pr
    JOIN api.usuarios u ON u.id_usuario = pr.id_usuario
    WHERE m.id_seccion = v_id_seccion AND m.fecha_retiro IS NULL
      AND pr.id_usuario = p_id_usuario
      AND (v_cedulas IS NULL OR e.cedula = ANY (v_cedulas))
    ORDER BY e.primer_apellido, e.segundo_apellido, e.nombre;

    IF NOT FOUND THEN
        PERFORM api.fn_lanzar_excepcion('CO003', 'La sección no tiene estudiantes a quienes enviar.');
    END IF;
END;
$$;

-- ------------------------------------------------------------
-- Guía CU08 / CU09 - Reporte de bandas de la sección guía en un semestre (AD005). p_cedula_estudiante NULL = toda
-- la sección; EV004 si el estudiante no se califica en la sección ese semestre.
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
    v_cedula TEXT := api.fn_limpiar_cedula(p_cedula_estudiante);
    v_id_matricula BIGINT;
    v_nombre_guia TEXT := (SELECT concat_ws(' ', pr.nombre, pr.primer_apellido, pr.segundo_apellido)
                           FROM academico.secciones s JOIN academico.profesores pr ON pr.id_profesor = s.id_profesor_guia
                           WHERE s.id_seccion = v_id_seccion);
BEGIN
    SELECT ms.id_matricula INTO v_id_matricula
    FROM academico.fn_matriculas_del_semestre(v_id_seccion, p_semestre) ms
    JOIN academico.estudiantes e ON e.id_estudiante = ms.id_estudiante
    WHERE e.cedula = v_cedula;

    IF v_cedula IS NOT NULL AND v_id_matricula IS NULL THEN
        PERFORM api.fn_lanzar_excepcion('EV004', 'El estudiante no se califica en la sección ese semestre.');
    END IF;

    RETURN QUERY
    WITH conteo AS (SELECT * FROM academico.fn_conteo_ausentismo(v_id_seccion, NULL, p_semestre, v_id_matricula))
    SELECT (d.fila).cedula_estudiante, (d.fila).nombre_estudiante,
           asg.codigo, asg.nombre::TEXT, asg.tipo, (ad.fila).nombre_profesor,
           academico.fn_nota_minima(asg.tipo)::VARCHAR(3),
           ev.nota,
           academico.fn_nota_aprobada(asg.tipo, ev.nota),
           c.tardias, c.ausencias - c.justificadas, c.justificadas,
           ev.observaciones,
           CASE WHEN a.id_asignacion IS NOT NULL THEN cn.id_asignacion IS NOT NULL END,
           v_nombre_guia
    FROM academico.fn_matriculas_del_semestre(v_id_seccion, p_semestre) ms
    JOIN academico.fn_matriculas_detalle() d ON d.id_matricula = ms.id_matricula
    LEFT JOIN (academico.asignaciones_docentes a
               JOIN academico.asignaturas asg ON asg.id_asignatura = a.id_asignatura AND asg.codigo <> 'CAS')
           ON a.id_seccion = v_id_seccion
    LEFT JOIN academico.fn_asignaciones_detalle() ad ON ad.id_asignacion = a.id_asignacion
    LEFT JOIN academico.confirmaciones_notas cn ON cn.id_asignacion = a.id_asignacion AND cn.semestre = p_semestre
    LEFT JOIN academico.evaluaciones ev
           ON ev.id_asignacion = a.id_asignacion AND ev.id_matricula = ms.id_matricula AND ev.semestre = p_semestre
    LEFT JOIN conteo c ON c.id_matricula = ms.id_matricula AND c.id_asignacion = a.id_asignacion
    WHERE v_cedula IS NULL OR (d.fila).cedula_estudiante = v_cedula
    ORDER BY d.apellidos_nombre, asg.tipo, asg.nombre, (ad.fila).nombre_profesor;
END;
$$;
