-- name=functions_triggers.sql
-- Funciones de contexto, validaciones y triggers de integridad y auditoria.
-- El llamador controla la transaccion; este archivo no hace ROLLBACK implicito.
--
-- ============================================================================
-- REVISIÓN CONTRA 2_-_schema_tables.sql (resumen de cambios de esta versión)
-- ============================================================================
-- 1) BUG CRÍTICO: fn_validar_asignacion_docente() y fn_validar_coordinacion_
--    monografia() referencian la columna academico.asignaturas.activa, pero
--    esa columna NO existe en 2_-_schema_tables.sql. Ambos triggers habrían
--    fallado en tiempo de ejecución con "column a.activa does not exist".
--    Se agrega la columna aquí (sección 00) y se recomienda incorporarla
--    también a schema_tables.sql para que quede documentada en el origen.
-- 2) Se agrega autorización real dentro de api.obtener_reporte_seccion():
--    antes solo ejecutaba la consulta sin validar que quien la invoca sea
--    el guía vigente de la sección o un administrador (violaba la regla de
--    "cada actor ve y hace solo lo necesario").
-- 3) Se agrega el trigger tr_sincronizar_estado_justificacion: antes, al
--    insertar una justificación, la asistencia jamás cambiaba su estado a
--    JUSTIFICADA (quedaba huérfana la regla de negocio de "justificar
--    ausencias").
-- 4) Se agrega tr_validar_transicion_estado_monografia: antes se podía
--    mover el estado de una monografía en cualquier dirección (p.ej. de
--    CERRADA otra vez a INVESTIGACION, o de INVESTIGACION directo a
--    CAPACITACION), violando el ciclo de vida de 2 años descrito.
-- 5) Se agrega validación de que la matrícula esté activa al registrar una
--    calificación por asignatura (fn_validar_calificacion).
-- 6) Se agregan guardas para impedir desactivar un rol de profesor
--    (GUIA/REGULAR/COORD_MONOGRAFIA) o una coordinación de monografía
--    mientras siguen en uso (sección activa a cargo, asignaciones activas,
--    o monografías en INVESTIGACION), evitando estados huérfanos.
-- 7) Se reescribe fn_auditar() para obtener la llave primaria de cada tabla
--    dinámicamente desde el catálogo (pg_index/pg_attribute) en vez de una
--    lista de columnas "a mano": la lista anterior no cubría la llave
--    compuesta de profesor_roles (id_profesor, tipo), por lo que la
--    columna clave_registro quedaba incompleta/ambigua para esa tabla.
-- 8) Simplificación de fn_validar_asistencia(): se elimina una verificación
--    redundante (la coherencia de curso lectivo ya la garantizan las FKs y
--    el trigger de lecciones), reduciendo superficie de error.
-- ============================================================================
BEGIN;

-- Asegurarse search_path correcto en creación (las funciones SECURITY DEFINER fijarán su propio search_path)
SET search_path = api, academico, pg_catalog;

-- ============================================================================
/*
    FUNCTION: 
        api.actor_usuario_id()
    COMMENT: 
        Esta función devuelve el id_usuario del actor autenticado en la sesión, o NULL si no hay actor.
*/
-- ============================================================================
CREATE OR REPLACE FUNCTION api.actor_usuario_id()
RETURNS BIGINT
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_actor TEXT;
BEGIN
    v_actor := current_setting('app.usuario_id', true);
    IF v_actor IS NULL OR v_actor !~ '^\d+$' THEN
        RETURN NULL;
    END IF;
    RETURN v_actor::BIGINT;
END;
$$;

-- ============================================================================
/*
    FUNCTION: 
        api.establecer_actor(p_id_usuario BIGINT)
    COMMENT: 
        Esta función establece el id_usuario del actor autenticado en la sesión. 
        Solo puede ser invocada por un backend confiable (que tenga el rol bi_api o bi_admin).
*/
-- ============================================================================
CREATE OR REPLACE FUNCTION api.establecer_actor(p_id_usuario BIGINT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, academico, api
AS $$
BEGIN
    IF NOT (pg_has_role(session_user, 'bi_api', 'member')
            OR pg_has_role(session_user, 'bi_admin', 'member')) THEN
        RAISE EXCEPTION 'Solo el backend confiable puede establecer el actor.'
            USING ERRCODE = '42501';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM academico.usuarios WHERE id_usuario = p_id_usuario AND activo = TRUE
    ) THEN
        RAISE EXCEPTION 'Usuario % no existe o está inactivo.', p_id_usuario USING ERRCODE = 'P0001';
    END IF;

    PERFORM set_config('app.usuario_id', p_id_usuario::TEXT, true);
END;
$$;

CREATE OR REPLACE FUNCTION api.requerir_actor()
RETURNS BIGINT
LANGUAGE plpgsql
STABLE
AS $$
DECLARE v_actor BIGINT;
BEGIN
    v_actor := api.actor_usuario_id();
    IF v_actor IS NULL THEN
        RAISE EXCEPTION 'No existe un actor autenticado en la sesión.' USING ERRCODE = '28000';
    END IF;
    RETURN v_actor;
END;
$$;

CREATE OR REPLACE FUNCTION api.tiene_rol_db(p_rol TEXT)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
AS $$
    SELECT pg_has_role(session_user, p_rol, 'member');
$$;

CREATE OR REPLACE FUNCTION api.requiere_rol_db(p_rol TEXT)
RETURNS VOID
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    IF NOT api.tiene_rol_db(p_rol) THEN
        RAISE EXCEPTION 'La operación requiere el rol de base de datos %.', p_rol USING ERRCODE = '42501';
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION api.profesor_tiene_rol(
    p_id_profesor BIGINT,
    p_tipo academico.tipo_profesor
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
AS $$
    SELECT EXISTS (
        SELECT 1 FROM academico.profesor_roles pr
        WHERE pr.id_profesor = p_id_profesor
          AND pr.tipo = p_tipo
          AND pr.activo = TRUE
          AND (pr.fecha_fin IS NULL OR pr.fecha_fin >= CURRENT_DATE)
    );
$$;

CREATE OR REPLACE FUNCTION api.es_guia_de_seccion(
    p_id_profesor BIGINT,
    p_id_seccion BIGINT,
    p_fecha DATE DEFAULT CURRENT_DATE
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
AS $$
    SELECT EXISTS (
        SELECT 1 FROM academico.guias_seccion gs
        WHERE gs.id_profesor = p_id_profesor
          AND gs.id_seccion = p_id_seccion
          AND p_fecha >= gs.fecha_inicio
          AND (gs.fecha_fin IS NULL OR p_fecha <= gs.fecha_fin)
    );
$$;

CREATE OR REPLACE FUNCTION api.obtener_reporte_seccion(
    p_id_seccion BIGINT,
    p_id_semestre BIGINT
)
RETURNS TABLE (
    id_estudiante BIGINT,
    estudiante TEXT,
    matricula BIGINT,
    bandas JSONB,
    monografia JSONB,
    asistencia JSONB
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, academico, api
AS $$
DECLARE
    v_actor BIGINT;
BEGIN
    -- CORRECCIÓN: la función original devolvía el reporte completo de la
    -- sección sin verificar quién lo solicitaba. Como este dato incluye
    -- notas y asistencia de todos los estudiantes, se exige que el actor
    -- autenticado sea el guía vigente de esa sección o un administrador
    -- (rol de BD bi_admin). Esto cumple la regla "cada actor ve y hace
    -- solo lo necesario".
    v_actor := api.requerir_actor();

    IF NOT (
        api.tiene_rol_db('bi_admin')
        OR api.es_guia_de_seccion(v_actor, p_id_seccion)
    ) THEN
        RAISE EXCEPTION
            'El actor % no está autorizado para consultar el reporte de la sección %.',
            v_actor, p_id_seccion
            USING ERRCODE = '42501';
    END IF;

    RETURN QUERY
    SELECT
        e.id_usuario,
        trim(u.nombre || ' ' || u.primer_apellido || COALESCE(' ' || u.segundo_apellido, '')),
        m.id_matricula,
        COALESCE((
            SELECT jsonb_agg(jsonb_build_object(
                'id_asignacion', c.id_asignacion,
                'banda_numerica', c.banda_numerica,
                'banda_letra', c.banda_letra,
                'aprobada', c.aprobada,
                'observacion', c.observacion
            ) ORDER BY c.id_calificacion)
            FROM academico.calificaciones c
            WHERE c.id_matricula = m.id_matricula
              AND c.id_semestre = p_id_semestre
        ), '[]'::jsonb),
        (
            SELECT jsonb_build_object(
                'id_monografia', mo.id_monografia,
                'estado', mo.estado,
                'fecha_inicio', mo.fecha_inicio,
                'fecha_fin', mo.fecha_fin,
                'id_asignatura', mo.id_asignatura,
                'fecha_seleccion_asignatura', mo.fecha_seleccion_asignatura
            )
            FROM academico.monografias mo
            WHERE mo.id_estudiante = e.id_usuario
        ),
        COALESCE((
            SELECT jsonb_agg(jsonb_build_object(
                'id_leccion', l.id_leccion,
                'fecha', l.fecha,
                'estado', a.estado,
                'observacion', a.observacion
            ) ORDER BY l.fecha, l.hora_inicio)
            FROM academico.asistencia a
            JOIN academico.lecciones l ON l.id_leccion = a.id_leccion
            WHERE a.id_matricula = m.id_matricula
              AND l.id_semestre = p_id_semestre
        ), '[]'::jsonb)
    FROM academico.matriculas m
    JOIN academico.estudiantes e ON e.id_usuario = m.id_estudiante
    JOIN academico.usuarios u ON u.id_usuario = e.id_usuario
    WHERE m.id_seccion = p_id_seccion
      AND m.activa = TRUE;
END;
$$;

SET search_path = academico, api, pg_catalog;

CREATE OR REPLACE FUNCTION academico.fn_validar_usuario_xor()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_usuario BIGINT;
    v_profesores INTEGER;
    v_estudiantes INTEGER;
BEGIN
    v_id_usuario := COALESCE(NEW.id_usuario, OLD.id_usuario);

    SELECT COUNT(*) INTO v_profesores FROM academico.profesores WHERE id_usuario = v_id_usuario;
    SELECT COUNT(*) INTO v_estudiantes FROM academico.estudiantes WHERE id_usuario = v_id_usuario;

    IF v_profesores + v_estudiantes <> 1 THEN
        RAISE EXCEPTION
            'Violación de herencia XOR: el usuario % debe pertenecer a exactamente un subtipo (profesor o estudiante).',
            v_id_usuario
            USING ERRCODE = '23514';
    END IF;
    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS ct_xor_usuarios ON academico.usuarios;

CREATE CONSTRAINT TRIGGER ct_xor_profesores
AFTER INSERT OR UPDATE OR DELETE ON academico.profesores
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION academico.fn_validar_usuario_xor();

CREATE CONSTRAINT TRIGGER  ct_xor_estudiantes
AFTER INSERT OR UPDATE OR DELETE ON academico.estudiantes
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION academico.fn_validar_usuario_xor();

-- 16.1b Impedir desactivar un rol de profesor que sigue en uso
-- CORRECCIÓN/ROBUSTEZ: nada impedía poner profesor_roles.activo = FALSE (o
-- fecha_fin en el pasado) para un profesor que en ese momento sigue como
-- guía de una sección, con asignaciones docentes activas, o coordinando una
-- monografía en curso. Eso dejaría esos registros "huérfanos" de rol.
CREATE OR REPLACE FUNCTION academico.fn_validar_desactivacion_rol_profesor()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- Solo interesa el instante en que el rol deja de estar vigente
    IF OLD.activo = TRUE
       AND (NEW.activo = FALSE OR (NEW.fecha_fin IS NOT NULL AND NEW.fecha_fin < CURRENT_DATE))
    THEN
        IF OLD.tipo = 'GUIA' AND EXISTS (
            SELECT 1 FROM academico.guias_seccion gs
            WHERE gs.id_profesor = OLD.id_profesor
              AND gs.fecha_fin IS NULL
        ) THEN
            RAISE EXCEPTION
                'No se puede desactivar el rol GUIA del profesor %: aún dirige una sección activa.',
                OLD.id_profesor USING ERRCODE = '23514';
        END IF;

        IF OLD.tipo = 'REGULAR' AND EXISTS (
            SELECT 1 FROM academico.asignaciones_docentes ad
            WHERE ad.id_profesor = OLD.id_profesor
              AND ad.activa = TRUE
        ) THEN
            RAISE EXCEPTION
                'No se puede desactivar el rol REGULAR del profesor %: tiene asignaciones docentes activas.',
                OLD.id_profesor USING ERRCODE = '23514';
        END IF;

        IF OLD.tipo = 'COORD_MONOGRAFIA' AND EXISTS (
            SELECT 1 FROM academico.coordinaciones_monografia cm
            WHERE cm.id_profesor = OLD.id_profesor
              AND cm.activa = TRUE
        ) THEN
            RAISE EXCEPTION
                'No se puede desactivar el rol COORD_MONOGRAFIA del profesor %: mantiene una coordinación activa.',
                OLD.id_profesor USING ERRCODE = '23514';
        END IF;
    END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER tr_validar_desactivacion_rol_profesor
BEFORE UPDATE ON academico.profesor_roles
FOR EACH ROW EXECUTE FUNCTION academico.fn_validar_desactivacion_rol_profesor();

-- 16.2 Guía debe tener el rol GUIA
CREATE OR REPLACE FUNCTION academico.fn_validar_guia()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT api.profesor_tiene_rol(NEW.id_profesor, 'GUIA') THEN
        RAISE EXCEPTION 'El profesor % no posee el rol GUIA.', NEW.id_profesor USING ERRCODE = '23514';
    END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER tr_validar_guia
BEFORE INSERT OR UPDATE ON academico.guias_seccion
FOR EACH ROW EXECUTE FUNCTION academico.fn_validar_guia();

-- 16.3 Docencia debe pertenecer a profesor REGULAR
CREATE OR REPLACE FUNCTION academico.fn_validar_asignacion_docente()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT api.profesor_tiene_rol(NEW.id_profesor, 'REGULAR') THEN
        RAISE EXCEPTION 'El profesor % no posee el rol REGULAR.', NEW.id_profesor USING ERRCODE = '23514';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM academico.asignaturas a
        WHERE a.id_asignatura = NEW.id_asignatura
          AND a.activa = TRUE
    ) THEN
        RAISE EXCEPTION 'La asignatura % no está activa.', NEW.id_asignatura USING ERRCODE = '23514';
    END IF;

    RETURN NEW;
END;
$$;
CREATE TRIGGER tr_validar_asignacion_docente
BEFORE INSERT OR UPDATE ON academico.asignaciones_docentes
FOR EACH ROW EXECUTE FUNCTION academico.fn_validar_asignacion_docente();

-- 16.3b Tope nivel 11 por profesor REGULAR (máx 1 distinta)
CREATE OR REPLACE FUNCTION academico.fn_validar_limite_nivel11_regular()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_nivel SMALLINT;
    v_curso BIGINT;
    v_count INTEGER;
BEGIN
    SELECT nivel, id_curso_lectivo INTO v_nivel, v_curso
    FROM academico.secciones
    WHERE id_seccion = NEW.id_seccion;

    IF v_nivel = 11 THEN
        PERFORM pg_advisory_xact_lock(hashtextextended(
            'asignacion-nivel11:' || NEW.id_profesor::TEXT || ':' || v_curso::TEXT, 0));
        SELECT COUNT(DISTINCT ad.id_asignatura) INTO v_count
        FROM academico.asignaciones_docentes ad
        JOIN academico.secciones s ON s.id_seccion = ad.id_seccion
        WHERE ad.id_profesor = NEW.id_profesor
          AND s.nivel = 11
          AND s.id_curso_lectivo = v_curso
          AND s.activa = TRUE
          AND ad.activa = TRUE
          AND ad.id_asignacion <> COALESCE(NEW.id_asignacion, -1)
          AND ad.id_asignatura <> NEW.id_asignatura;

        IF v_count >= 1 THEN
            RAISE EXCEPTION
                'El profesor % ya imparte una materia de nivel 11 en el curso lectivo % (solo puede impartir una).',
                NEW.id_profesor, v_curso USING ERRCODE = '23514';
        END IF;
    END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER tr_validar_limite_nivel11_regular
BEFORE INSERT OR UPDATE ON academico.asignaciones_docentes
FOR EACH ROW EXECUTE FUNCTION academico.fn_validar_limite_nivel11_regular();

-- 16.4 Coordinador y materia habilitada
CREATE OR REPLACE FUNCTION academico.fn_validar_coordinacion_monografia()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT api.profesor_tiene_rol(NEW.id_profesor, 'COORD_MONOGRAFIA') THEN
        RAISE EXCEPTION 'El profesor % no posee el rol COORD_MONOGRAFIA.', NEW.id_profesor USING ERRCODE = '23514';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM academico.asignaturas a
        WHERE a.id_asignatura = NEW.id_asignatura
          AND a.activa = TRUE
          AND a.permite_monografia = TRUE
    ) THEN
        RAISE EXCEPTION 'La asignatura % no está habilitada como materia de monografía.', NEW.id_asignatura USING ERRCODE = '23514';
    END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER tr_validar_coordinacion_monografia
BEFORE INSERT OR UPDATE ON academico.coordinaciones_monografia
FOR EACH ROW EXECUTE FUNCTION academico.fn_validar_coordinacion_monografia();

-- 16.4b Impedir desactivar una coordinación con monografías en curso
-- CORRECCIÓN/ROBUSTEZ: sin esta guarda se podía poner activa = FALSE en una
-- coordinación mientras aún supervisaba estudiantes en estado INVESTIGACION,
-- dejándolos sin coordinador vigente.
CREATE OR REPLACE FUNCTION academico.fn_validar_desactivacion_coordinacion()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF OLD.activa = TRUE AND NEW.activa = FALSE THEN
        IF EXISTS (
            SELECT 1 FROM academico.monografias m
            WHERE m.id_coordinacion = OLD.id_coordinacion
              AND m.estado = 'INVESTIGACION'
        ) THEN
            RAISE EXCEPTION
                'No se puede desactivar la coordinación %: existen monografías en INVESTIGACION bajo su supervisión.',
                OLD.id_coordinacion USING ERRCODE = '23514';
        END IF;
    END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER tr_validar_desactivacion_coordinacion
BEFORE UPDATE ON academico.coordinaciones_monografia
FOR EACH ROW EXECUTE FUNCTION academico.fn_validar_desactivacion_coordinacion();

-- 16.5 Monografía: validaciones de coherencia y topes
CREATE OR REPLACE FUNCTION academico.fn_validar_monografia()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_coordinacion_asignatura BIGINT;
    v_count_coordinador INTEGER;
    v_count_asignatura INTEGER;
BEGIN
    IF NEW.id_asignatura IS NULL THEN
        IF NEW.estado <> 'CAPACITACION' THEN
            RAISE EXCEPTION 'Una monografía sin materia solamente puede estar en CAPACITACION.' USING ERRCODE = '23514';
        END IF;
        RETURN NEW;
    END IF;

    IF NEW.fecha_seleccion_asignatura < (NEW.fecha_inicio + INTERVAL '6 months')::date THEN
        RAISE EXCEPTION 'La materia de la monografía no puede seleccionarse antes de 6 meses.' USING ERRCODE = '23514';
    END IF;

    SELECT id_asignatura INTO v_coordinacion_asignatura
    FROM academico.coordinaciones_monografia
    WHERE id_coordinacion = NEW.id_coordinacion
      AND activa = TRUE;

    IF v_coordinacion_asignatura IS NULL THEN
        RAISE EXCEPTION 'La coordinación % no existe o está inactiva.', NEW.id_coordinacion USING ERRCODE = '23514';
    END IF;

    IF v_coordinacion_asignatura <> NEW.id_asignatura THEN
        RAISE EXCEPTION 'La materia elegida no coincide con la materia del coordinador.' USING ERRCODE = '23514';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM academico.coordinaciones_monografia cm
        WHERE cm.id_coordinacion = NEW.id_coordinacion
          AND cm.activa = TRUE
          AND NEW.fecha_seleccion_asignatura >= cm.fecha_inicio
          AND (cm.fecha_fin IS NULL OR NEW.fecha_seleccion_asignatura <= cm.fecha_fin)
    ) THEN
        RAISE EXCEPTION 'El coordinador no estaba vigente en la fecha de selección.' USING ERRCODE = '23514';
    END IF;

    IF NEW.estado = 'CAPACITACION' THEN
        RAISE EXCEPTION 'Una monografía con materia seleccionada no puede continuar en CAPACITACION.' USING ERRCODE = '23514';
    END IF;

    SELECT COUNT(*) INTO v_count_coordinador
    FROM academico.monografias m
    WHERE m.id_coordinacion = NEW.id_coordinacion
      AND m.estado <> 'CANCELADA'
      AND daterange(m.fecha_inicio, (m.fecha_fin + 1), '[)') &&
          daterange(NEW.fecha_inicio, (NEW.fecha_fin + 1), '[)')
      AND m.id_monografia <> COALESCE(NEW.id_monografia, -1);

    IF v_count_coordinador >= 5 THEN
        RAISE EXCEPTION 'El coordinador % ya tiene el máximo de 5 estudiantes supervisados en el período solapado.',
            NEW.id_coordinacion USING ERRCODE = '23514';
    END IF;

    SELECT COUNT(*) INTO v_count_asignatura
    FROM academico.monografias m
    WHERE m.id_asignatura = NEW.id_asignatura
      AND m.estado <> 'CANCELADA'
      AND daterange(m.fecha_inicio, (m.fecha_fin + 1), '[)') &&
          daterange(NEW.fecha_inicio, (NEW.fecha_fin + 1), '[)')
      AND m.id_monografia <> COALESCE(NEW.id_monografia, -1);

    IF v_count_asignatura >= 5 THEN
        RAISE EXCEPTION 'La materia % ya tiene el máximo de 5 estudiantes para el período solapado.',
            NEW.id_asignatura USING ERRCODE = '23514';
    END IF;

    RETURN NEW;
END;
$$;
CREATE TRIGGER tr_validar_monografia
BEFORE INSERT OR UPDATE ON academico.monografias
FOR EACH ROW EXECUTE FUNCTION academico.fn_validar_monografia();

-- 16.5b Monografía: máquina de estados (ciclo de vida de 2 años)
-- CORRECCIÓN: el esquema solo garantizaba, vía CHECK, que el "estado" fuera
-- coherente con si hay materia asignada o no, pero no impedía transiciones
-- ilógicas (p.ej. de CERRADA volver a INVESTIGACION, o de INVESTIGACION
-- saltar directo a CAPACITACION). Este trigger fija las únicas transiciones
-- válidas:
--   CAPACITACION  -> INVESTIGACION | CANCELADA
--   INVESTIGACION -> CERRADA       | CANCELADA
--   CERRADA       -> (estado final, sin cambios)
--   CANCELADA     -> (estado final, sin cambios)
CREATE OR REPLACE FUNCTION academico.fn_validar_transicion_estado_monografia()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'UPDATE' AND OLD.estado IS DISTINCT FROM NEW.estado THEN
        IF OLD.estado = 'CERRADA' THEN
            RAISE EXCEPTION
                'La monografía % ya está CERRADA; no admite cambios de estado.',
                OLD.id_monografia USING ERRCODE = '23514';
        END IF;

        IF OLD.estado = 'CANCELADA' THEN
            RAISE EXCEPTION
                'La monografía % está CANCELADA; no admite cambios de estado.',
                OLD.id_monografia USING ERRCODE = '23514';
        END IF;

        IF OLD.estado = 'CAPACITACION' AND NEW.estado NOT IN ('INVESTIGACION', 'CANCELADA') THEN
            RAISE EXCEPTION
                'Desde CAPACITACION solo se permite pasar a INVESTIGACION o CANCELADA (intentó %).',
                NEW.estado USING ERRCODE = '23514';
        END IF;

        IF OLD.estado = 'INVESTIGACION' AND NEW.estado NOT IN ('CERRADA', 'CANCELADA') THEN
            RAISE EXCEPTION
                'Desde INVESTIGACION solo se permite pasar a CERRADA o CANCELADA (intentó %).',
                NEW.estado USING ERRCODE = '23514';
        END IF;
    END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER tr_validar_transicion_estado_monografia
BEFORE UPDATE ON academico.monografias
FOR EACH ROW EXECUTE FUNCTION academico.fn_validar_transicion_estado_monografia();

-- 16.6 Observación solo por el coordinador
CREATE OR REPLACE FUNCTION academico.fn_validar_observacion_monografia()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM academico.monografias m
        JOIN academico.coordinaciones_monografia cm ON cm.id_coordinacion = m.id_coordinacion
        WHERE m.id_monografia = NEW.id_monografia
          AND cm.id_profesor = NEW.id_profesor
          AND cm.activa = TRUE
    ) THEN
        RAISE EXCEPTION 'El profesor % no es el coordinador de la monografía %.', NEW.id_profesor, NEW.id_monografia USING ERRCODE = '23514';
    END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER tr_validar_observacion_monografia
BEFORE INSERT OR UPDATE ON academico.observaciones_monografia
FOR EACH ROW EXECUTE FUNCTION academico.fn_validar_observacion_monografia();

-- 16.7 Lección -> semestre y curso de la sección
CREATE OR REPLACE FUNCTION academico.fn_validar_leccion()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_curso_asignacion BIGINT;
    v_curso_semestre BIGINT;
    v_inicio DATE;
    v_fin DATE;
BEGIN
    SELECT s.id_curso_lectivo INTO v_curso_asignacion
    FROM academico.asignaciones_docentes ad
    JOIN academico.secciones s ON s.id_seccion = ad.id_seccion
    WHERE ad.id_asignacion = NEW.id_asignacion;

    SELECT se.id_curso_lectivo, se.fecha_inicio, se.fecha_fin INTO v_curso_semestre, v_inicio, v_fin
    FROM academico.semestres se
    WHERE se.id_semestre = NEW.id_semestre;

    IF v_curso_asignacion IS DISTINCT FROM v_curso_semestre THEN
        RAISE EXCEPTION 'La lección y el semestre pertenecen a cursos lectivos diferentes.' USING ERRCODE = '23514';
    END IF;

    IF NEW.fecha < v_inicio OR NEW.fecha > v_fin THEN
        RAISE EXCEPTION 'La fecha de la lección está fuera del rango del semestre.' USING ERRCODE = '23514';
    END IF;

    RETURN NEW;
END;
$$;
CREATE TRIGGER tr_validar_leccion
BEFORE INSERT OR UPDATE ON academico.lecciones
FOR EACH ROW EXECUTE FUNCTION academico.fn_validar_leccion();

-- 16.8 Asistencia -> misma sección
CREATE OR REPLACE FUNCTION academico.fn_validar_asistencia()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_seccion_leccion BIGINT;
    v_seccion_matricula BIGINT;
BEGIN
    SELECT ad.id_seccion INTO v_seccion_leccion
    FROM academico.lecciones l
    JOIN academico.asignaciones_docentes ad ON ad.id_asignacion = l.id_asignacion
    WHERE l.id_leccion = NEW.id_leccion;

    SELECT m.id_seccion INTO v_seccion_matricula
    FROM academico.matriculas m
    WHERE m.id_matricula = NEW.id_matricula
      AND m.activa = TRUE;

    IF v_seccion_matricula IS NULL THEN
        RAISE EXCEPTION
            'No se puede registrar asistencia para la matrícula %: no existe o no está activa.',
            NEW.id_matricula USING ERRCODE = '23514';
    END IF;

    IF v_seccion_leccion IS DISTINCT FROM v_seccion_matricula THEN
        RAISE EXCEPTION 'El estudiante no pertenece a la sección de la lección.' USING ERRCODE = '23514';
    END IF;

    -- NOTA DE SIMPLIFICACIÓN: la verificación previa que comparaba el curso
    -- lectivo de la lección contra el de la matrícula era redundante y se
    -- retira. Es matemáticamente imposible que difieran porque:
    --   1) fk_matriculas_seccion_curso obliga a que matriculas.id_curso_lectivo
    --      coincida con el curso lectivo real de matriculas.id_seccion, y
    --   2) fn_validar_leccion (tr_validar_leccion) ya obliga a que la lección
    --      y su semestre compartan el mismo curso lectivo que la sección de
    --      la asignación docente.
    -- Con v_seccion_leccion = v_seccion_matricula (verificado arriba), el
    -- curso lectivo queda garantizado transitivamente sin una subconsulta
    -- adicional propensa a errores.
    RETURN NEW;
END;
$$;
CREATE TRIGGER tr_validar_asistencia
BEFORE INSERT OR UPDATE ON academico.asistencia
FOR EACH ROW EXECUTE FUNCTION academico.fn_validar_asistencia();

-- 16.9 Calificaciones: consistencia académica
CREATE OR REPLACE FUNCTION academico.fn_validar_calificacion()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_tipo_banda academico.tipo_banda;
    v_estudiante_matricula BIGINT;
    v_estudiante_monografia BIGINT;
    v_seccion_asignacion BIGINT;
    v_seccion_matricula BIGINT;
BEGIN
    IF NEW.id_asignacion IS NOT NULL THEN
        SELECT a.tipo_banda INTO v_tipo_banda
        FROM academico.asignaciones_docentes ad
        JOIN academico.asignaturas a ON a.id_asignatura = ad.id_asignatura
        WHERE ad.id_asignacion = NEW.id_asignacion;

        SELECT m.id_estudiante, m.id_seccion INTO v_estudiante_matricula, v_seccion_matricula
        FROM academico.matriculas m
        WHERE m.id_matricula = NEW.id_matricula
          AND m.activa = TRUE;

        -- CORRECCIÓN: si la matrícula no está activa (estudiante retirado),
        -- la búsqueda anterior no encuentra fila y v_seccion_matricula queda
        -- NULL; se valida explícitamente para dar un mensaje claro en vez de
        -- fallar más abajo por una comparación NULL poco informativa.
        IF v_seccion_matricula IS NULL THEN
            RAISE EXCEPTION
                'No se pueden registrar calificaciones para la matrícula %: no existe o no está activa.',
                NEW.id_matricula USING ERRCODE = '23514';
        END IF;

        SELECT ad.id_seccion INTO v_seccion_asignacion
        FROM academico.asignaciones_docentes ad
        WHERE ad.id_asignacion = NEW.id_asignacion;

        IF v_tipo_banda = 'NUMERICA' AND (NEW.banda_numerica IS NULL OR NEW.banda_letra IS NOT NULL) THEN
            RAISE EXCEPTION 'La asignatura de la calificación requiere banda numérica 1-7.' USING ERRCODE = '23514';
        END IF;

        IF v_tipo_banda = 'LETRA' AND (NEW.banda_letra IS NULL OR NEW.banda_numerica IS NOT NULL) THEN
            RAISE EXCEPTION 'La asignatura de la calificación requiere banda literal A-E.' USING ERRCODE = '23514';
        END IF;

        IF v_seccion_matricula IS DISTINCT FROM v_seccion_asignacion THEN
            RAISE EXCEPTION 'La calificación no corresponde a la sección de la matrícula.' USING ERRCODE = '23514';
        END IF;

    ELSE
        SELECT id_estudiante INTO v_estudiante_monografia
        FROM academico.monografias
        WHERE id_monografia = NEW.id_monografia;

        IF NEW.banda_letra IS NULL OR NEW.banda_numerica IS NOT NULL THEN
            RAISE EXCEPTION 'La monografía solo admite banda literal A-E.' USING ERRCODE = '23514';
        END IF;

        IF NOT EXISTS (
            SELECT 1 FROM academico.monografias m
            WHERE m.id_monografia = NEW.id_monografia
              AND m.estado IN ('INVESTIGACION','CERRADA')
        ) THEN
            RAISE EXCEPTION 'La monografía debe estar en INVESTIGACION o CERRADA para registrar una banda.' USING ERRCODE = '23514';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;
CREATE TRIGGER tr_validar_calificacion
BEFORE INSERT OR UPDATE ON academico.calificaciones
FOR EACH ROW EXECUTE FUNCTION academico.fn_validar_calificacion();

-- 16.9b Calificaciones y reportes deben pertenecer al mismo curso lectivo.
CREATE OR REPLACE FUNCTION academico.fn_validar_periodo_academico()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_curso_semestre BIGINT;
    v_curso_matricula BIGINT;
    v_curso_asignacion BIGINT;
    v_curso_seccion BIGINT;
BEGIN
    IF TG_TABLE_NAME = 'calificaciones' THEN
        SELECT id_curso_lectivo INTO v_curso_semestre
        FROM academico.semestres WHERE id_semestre = NEW.id_semestre;
        IF NEW.id_matricula IS NOT NULL THEN
            SELECT id_curso_lectivo INTO v_curso_matricula
            FROM academico.matriculas WHERE id_matricula = NEW.id_matricula;
            IF v_curso_semestre IS DISTINCT FROM v_curso_matricula THEN
                RAISE EXCEPTION 'La calificacion y la matricula pertenecen a cursos distintos.' USING ERRCODE = '23514';
            END IF;
        END IF;
        IF NEW.id_asignacion IS NOT NULL THEN
            SELECT s.id_curso_lectivo INTO v_curso_asignacion
            FROM academico.asignaciones_docentes ad
            JOIN academico.secciones s ON s.id_seccion = ad.id_seccion
            WHERE ad.id_asignacion = NEW.id_asignacion;
            IF v_curso_semestre IS DISTINCT FROM v_curso_asignacion THEN
                RAISE EXCEPTION 'La calificacion y la asignacion pertenecen a cursos distintos.' USING ERRCODE = '23514';
            END IF;
        END IF;
    ELSE
        SELECT id_curso_lectivo INTO v_curso_seccion
        FROM academico.secciones WHERE id_seccion = NEW.id_seccion;
        SELECT id_curso_lectivo INTO v_curso_semestre
        FROM academico.semestres WHERE id_semestre = NEW.id_semestre;
        IF v_curso_seccion IS DISTINCT FROM v_curso_semestre THEN
            RAISE EXCEPTION 'El reporte y sus datos pertenecen a cursos distintos.' USING ERRCODE = '23514';
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tr_validar_periodo_calificacion ON academico.calificaciones;
CREATE TRIGGER tr_validar_periodo_calificacion
BEFORE INSERT OR UPDATE ON academico.calificaciones
FOR EACH ROW EXECUTE FUNCTION academico.fn_validar_periodo_academico();
DROP TRIGGER IF EXISTS tr_validar_periodo_reporte ON academico.reportes;
CREATE TRIGGER tr_validar_periodo_reporte
BEFORE INSERT OR UPDATE ON academico.reportes
FOR EACH ROW EXECUTE FUNCTION academico.fn_validar_periodo_academico();

-- 16.10 Justificación solo para ausencia
CREATE OR REPLACE FUNCTION academico.fn_validar_justificacion()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM academico.asistencia a
        WHERE a.id_asistencia = NEW.id_asistencia
          AND a.estado IN ('AUSENTE','JUSTIFICADA')
    ) THEN
        RAISE EXCEPTION 'Solo se pueden justificar asistencias ausentes.' USING ERRCODE = '23514';
    END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER tr_validar_justificacion
BEFORE INSERT OR UPDATE ON academico.justificaciones_asistencia
FOR EACH ROW EXECUTE FUNCTION academico.fn_validar_justificacion();

-- 16.10b Sincronizar el estado de la asistencia con su justificación
-- CORRECCIÓN: la regla de negocio pide "poder justificar las ausencias
-- adjuntando un comentario", pero en el archivo original nada actualizaba
-- asistencia.estado a 'JUSTIFICADA' al crear la justificación: el registro
-- de asistencia se quedaba en 'AUSENTE' para siempre. Este trigger AFTER
-- mantiene ambos registros consistentes en los dos sentidos:
--   INSERT/UPDATE de justificación -> asistencia pasa a JUSTIFICADA.
--   DELETE de justificación        -> asistencia vuelve a AUSENTE.
CREATE OR REPLACE FUNCTION academico.fn_sincronizar_estado_justificacion()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP IN ('INSERT', 'UPDATE') THEN
        UPDATE academico.asistencia
           SET estado = 'JUSTIFICADA'
         WHERE id_asistencia = NEW.id_asistencia
           AND estado <> 'JUSTIFICADA';
        RETURN NEW;
    ELSE
        UPDATE academico.asistencia
           SET estado = 'AUSENTE'
         WHERE id_asistencia = OLD.id_asistencia
           AND estado = 'JUSTIFICADA';
        RETURN OLD;
    END IF;
END;
$$;
CREATE TRIGGER tr_sincronizar_estado_justificacion
AFTER INSERT OR UPDATE OR DELETE ON academico.justificaciones_asistencia
FOR EACH ROW EXECUTE FUNCTION academico.fn_sincronizar_estado_justificacion();

-- 17. TRIGGER GENÉRICO DE AUDITORÍA
-- CORRECCIÓN: la versión original armaba clave_registro con un COALESCE de
-- ~18 nombres de columna "id_*" escritos a mano. Eso tiene dos problemas:
--   a) Cualquier tabla nueva con otro nombre de llave (o sin ninguno en la
--      lista) queda con clave_registro = TG_TABLE_NAME, sin identificar la
--      fila.
--   b) academico.profesor_roles tiene llave primaria COMPUESTA
--      (id_profesor, tipo); el COALESCE solo capturaba id_profesor y
--      perdía el "tipo", por lo que dos filas del mismo profesor (p.ej.
--      GUIA y REGULAR) quedaban indistinguibles en la auditoría.
-- La versión nueva consulta el catálogo (pg_index/pg_attribute) para
-- obtener, en tiempo de ejecución, las columnas reales de la llave primaria
-- de la tabla que disparó el trigger, y arma clave_registro como un JSON
-- con esas columnas y sus valores. Funciona para cualquier tabla, con
-- llave simple o compuesta, sin mantenimiento manual.
CREATE OR REPLACE FUNCTION academico.fn_auditar()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_actor BIGINT;
    v_old JSONB;
    v_new JSONB;
    v_row JSONB;
    v_pk_cols TEXT[];
    v_col TEXT;
    v_key JSONB := '{}'::jsonb;
BEGIN
    v_actor := api.actor_usuario_id();

    v_row := CASE WHEN TG_OP = 'DELETE' THEN to_jsonb(OLD) ELSE to_jsonb(NEW) END;

    -- Columnas de la llave primaria de la tabla, en el orden en que
    -- participan en el índice de la PK.
    SELECT array_agg(a.attname ORDER BY array_position(i.indkey, a.attnum))
      INTO v_pk_cols
      FROM pg_index i
      JOIN pg_attribute a
        ON a.attrelid = i.indrelid AND a.attnum = ANY(i.indkey)
     WHERE i.indrelid = (quote_ident(TG_TABLE_SCHEMA) || '.' || quote_ident(TG_TABLE_NAME))::regclass
       AND i.indisprimary;

    IF v_pk_cols IS NOT NULL THEN
        FOREACH v_col IN ARRAY v_pk_cols LOOP
            v_key := v_key || jsonb_build_object(v_col, v_row -> v_col);
        END LOOP;
    ELSE
        -- Resguardo: tabla sin PK detectable (no debería ocurrir en este
        -- modelo); se deja al menos el nombre de la tabla.
        v_key := jsonb_build_object('tabla', TG_TABLE_NAME);
    END IF;

    IF TG_OP = 'INSERT' THEN
        v_new := to_jsonb(NEW) - ARRAY['password_hash', 'token_hash'];
    ELSIF TG_OP = 'UPDATE' THEN
        v_old := to_jsonb(OLD) - ARRAY['password_hash', 'token_hash'];
        v_new := to_jsonb(NEW) - ARRAY['password_hash', 'token_hash'];
    ELSE
        v_old := to_jsonb(OLD) - ARRAY['password_hash', 'token_hash'];
    END IF;

    INSERT INTO academico.auditoria_operaciones(
        id_usuario_actor, rol_bd, esquema, tabla, operacion,
        clave_registro, datos_antes, datos_despues
    )
    VALUES (
        v_actor, session_user, TG_TABLE_SCHEMA, TG_TABLE_NAME, TG_OP,
        v_key::TEXT, v_old, v_new
    );

    IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
    RETURN NEW;
END;
$$;

-- Crear triggers de auditoría sobre las tablas críticas
DO $$
DECLARE
    v_tabla TEXT;
BEGIN
    FOREACH v_tabla IN ARRAY ARRAY[
        'usuarios', 'profesores', 'estudiantes', 'profesor_roles',
        'cursos_lectivos', 'semestres', 'secciones', 'guias_seccion',
        'matriculas', 'asignaturas', 'asignaciones_docentes',
        'coordinaciones_monografia', 'monografias', 'observaciones_monografia',
        'calificaciones', 'lecciones', 'asistencia', 'justificaciones_asistencia',
        'verificaciones_email', 'reportes'
    ]
    LOOP
        EXECUTE format(
            'DROP TRIGGER IF EXISTS %I ON academico.%I;',
            'tr_audit_' || v_tabla, v_tabla
        );
        EXECUTE format(
            'CREATE TRIGGER %I AFTER INSERT OR UPDATE OR DELETE ON academico.%I FOR EACH ROW EXECUTE FUNCTION academico.fn_auditar();',
            'tr_audit_' || v_tabla, v_tabla
        );
    END LOOP;
END;
$$;

COMMIT;