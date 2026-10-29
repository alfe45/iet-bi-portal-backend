-- Migración del 29/10/2026: Profesor Regular CU12, enviar documentos por correo a una sección (RN-92).
-- Para una base con datos (Neon): solo crea una función, no toca tablas ni datos. Ejecutar con el dueño de la base:
--   psql -v ON_ERROR_STOP=1 -f Resources/sql/migraciones/2026-10-29_correo_seccion.sql
-- y luego reiniciar la API. La función es copia del script 13.
BEGIN;
SET search_path = academico, api, auth, public;

-- Profesor Regular CU12 - Destinatarios del correo a una sección (RN-92). Mismo acceso de RN-59 (AD003). Estudiantes
-- matriculados en la sección sin retiro: todos (p_cedulas NULL o vacío) o los elegidos, NF009 si alguna cédula no está
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
        PERFORM api.fn_lanzar_excepcion('NF009', 'El estudiante no está matriculado en esa sección.');
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

COMMIT;
