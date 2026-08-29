-- expose_api.sql
-- Capa de lectura para la aplicacion y administradores.
-- PostgreSQL 14+. Ejecutar despues de 1, 2, 3, 4 y 7.
--
-- Instalacion: psql -X -v ON_ERROR_STOP=1 -f "Resources/db/expose_api.sql" DBNAME
-- Pruebas de contrato: psql -X -v ON_ERROR_STOP=1 -f "Resources/db/expose_api.sql" DBNAME
-- Las pruebas de negocio requieren fixtures y deben ejecutarse con un actor fijado
-- por el backend confiable: SELECT api.establecer_actor(<id_usuario>);
-- Todas las funciones de lectura usan SECURITY DEFINER y fijan search_path.
-- No se exponen password_hash, token_hash ni contenido de auditoria.

BEGIN;

SET search_path = api, academico, pg_catalog;

-- Indices de soporte para las consultas publicadas.
CREATE INDEX IF NOT EXISTS ix_matriculas_estudiante_seccion
    ON academico.matriculas(id_estudiante, id_seccion);
CREATE INDEX IF NOT EXISTS ix_asistencia_leccion_matricula_fecha
    ON academico.asistencia(id_leccion, id_matricula, fecha_registro);
CREATE INDEX IF NOT EXISTS ix_calificaciones_matricula_semestre
    ON academico.calificaciones(id_matricula, id_semestre);
CREATE INDEX IF NOT EXISTS ix_usuarios_cedula_lower
    ON academico.usuarios(lower(cedula));

-- Vista administrativa: profesores y roles activos. Solo bi_admin puede leerla.
CREATE OR REPLACE VIEW academico.v_profesores_rol AS
SELECT p.id_usuario AS id_profesor,
       trim(u.nombre || ' ' || u.primer_apellido || COALESCE(' ' || u.segundo_apellido, '')) AS nombre,
       p.codigo_empleado,
       COALESCE(array_agg(DISTINCT pr.tipo ORDER BY pr.tipo)
           FILTER (WHERE pr.activo AND (pr.fecha_fin IS NULL OR pr.fecha_fin >= CURRENT_DATE)),
           ARRAY[]::academico.tipo_profesor[]) AS roles
FROM academico.profesores p
JOIN academico.usuarios u ON u.id_usuario = p.id_usuario
LEFT JOIN academico.profesor_roles pr ON pr.id_profesor = p.id_usuario
GROUP BY p.id_usuario, u.nombre, u.primer_apellido, u.segundo_apellido, p.codigo_empleado;

-- Vista administrativa: matriculas activas e historicas sin datos de autenticacion.
-- Se concede unicamente a bi_admin; otros roles usan funciones api.
CREATE OR REPLACE VIEW academico.v_estudiantes_matriculados AS
SELECT m.id_matricula,
       m.id_estudiante,
       trim(u.nombre || ' ' || u.primer_apellido || COALESCE(' ' || u.segundo_apellido, '')) AS estudiante,
       u.cedula,
       e.numero_expediente,
       m.id_curso_lectivo,
       c.nombre AS curso_lectivo,
       m.id_seccion,
       s.nivel,
       s.numero AS seccion_numero,
       m.fecha_matricula,
       m.fecha_retiro,
       m.activa
FROM academico.matriculas m
JOIN academico.estudiantes e ON e.id_usuario = m.id_estudiante
JOIN academico.usuarios u ON u.id_usuario = e.id_usuario
JOIN academico.cursos_lectivos c ON c.id_curso_lectivo = m.id_curso_lectivo
JOIN academico.secciones s ON s.id_seccion = m.id_seccion;

-- Vista de carga docente activa. No se concede SELECT directo a roles operativos.
CREATE OR REPLACE VIEW academico.v_carga_docente_actual AS
SELECT ad.id_asignacion,
       ad.id_profesor,
       a.id_asignatura,
       a.codigo AS codigo_asignatura,
       a.nombre AS asignatura,
       ad.id_seccion,
       s.nivel,
       s.numero AS seccion_numero,
       s.id_curso_lectivo,
       c.nombre AS curso_lectivo
FROM academico.asignaciones_docentes ad
JOIN academico.asignaturas a ON a.id_asignatura = ad.id_asignatura
JOIN academico.secciones s ON s.id_seccion = ad.id_seccion
JOIN academico.cursos_lectivos c ON c.id_curso_lectivo = s.id_curso_lectivo
WHERE ad.activa AND s.activa;

REVOKE ALL ON academico.v_profesores_rol,
                 academico.v_estudiantes_matriculados,
                 academico.v_carga_docente_actual FROM PUBLIC;
GRANT SELECT ON academico.v_profesores_rol,
               academico.v_estudiantes_matriculados,
               academico.v_carga_docente_actual TO bi_admin;

-- Autoriza administracion, o al propio estudiante identificado por actor.
CREATE OR REPLACE FUNCTION api.obtener_bandas_por_cedula(
    p_cedula CITEXT,
    p_id_semestre BIGINT DEFAULT NULL
)
RETURNS TABLE (
    semestre TEXT,
    asignatura TEXT,
    tipo TEXT,
    banda TEXT,
    aprobada BOOLEAN,
    fecha_registro TIMESTAMPTZ,
    observacion TEXT
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = pg_catalog, academico, api
AS $$
DECLARE v_estudiante BIGINT;
BEGIN
    SELECT e.id_usuario INTO v_estudiante
    FROM academico.usuarios u JOIN academico.estudiantes e ON e.id_usuario = u.id_usuario
    WHERE u.cedula = p_cedula;
    IF v_estudiante IS NULL THEN RAISE EXCEPTION 'Estudiante no encontrado.' USING ERRCODE = 'P0002'; END IF;
    IF NOT (api.tiene_rol_db('bi_api') OR api.tiene_rol_db('bi_admin'))
       AND api.requerir_actor() <> v_estudiante THEN
        RAISE EXCEPTION 'El estudiante solo puede consultar sus propias bandas.' USING ERRCODE = '42501';
    END IF;
    RETURN QUERY
    SELECT s.nombre,
           COALESCE(a.nombre, 'Monografia')::TEXT,
           CASE WHEN c.id_monografia IS NULL THEN 'ASIGNATURA' ELSE 'MONOGRAFIA' END,
           COALESCE(c.banda_numerica::TEXT, btrim(c.banda_letra::TEXT)),
           c.aprobada, c.fecha_registro, c.observacion
    FROM academico.calificaciones c
    JOIN academico.semestres s ON s.id_semestre = c.id_semestre
    LEFT JOIN academico.matriculas m ON m.id_matricula = c.id_matricula
    LEFT JOIN academico.asignaciones_docentes ad ON ad.id_asignacion = c.id_asignacion
    LEFT JOIN academico.asignaturas a ON a.id_asignatura = ad.id_asignatura
    WHERE (m.id_estudiante = v_estudiante OR EXISTS (
              SELECT 1 FROM academico.monografias mo
              WHERE mo.id_monografia = c.id_monografia AND mo.id_estudiante = v_estudiante))
      AND (p_id_semestre IS NULL OR c.id_semestre = p_id_semestre)
    ORDER BY c.fecha_registro DESC;
END;
$$;

-- Lista de estudiantes de una seccion. bi_api/admin tienen acceso global;
-- profesores solo acceden a una seccion que guian o donde tienen asignacion.
CREATE OR REPLACE FUNCTION api.lista_estudiantes_por_seccion(
    p_id_seccion BIGINT,
    p_activos_only BOOLEAN DEFAULT TRUE,
    p_limit INT DEFAULT 100,
    p_offset INT DEFAULT 0
)
RETURNS TABLE (
    id_estudiante BIGINT,
    nombre_completo TEXT,
    id_matricula BIGINT,
    numero_expediente VARCHAR,
    nivel SMALLINT,
    seccion_numero INTEGER,
    curso_lectivo TEXT
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = pg_catalog, academico, api
AS $$
DECLARE v_actor BIGINT;
BEGIN
    IF p_limit < 1 OR p_limit > 1000 OR p_offset < 0 THEN
        RAISE EXCEPTION 'Paginacion invalida.' USING ERRCODE = '22023';
    END IF;
    IF NOT (api.tiene_rol_db('bi_api') OR api.tiene_rol_db('bi_admin')) THEN
        v_actor := api.requerir_actor();
        IF NOT (api.es_guia_de_seccion(v_actor, p_id_seccion)
                OR EXISTS (SELECT 1 FROM academico.asignaciones_docentes ad
                           WHERE ad.id_profesor = v_actor AND ad.id_seccion = p_id_seccion AND ad.activa)) THEN
            RAISE EXCEPTION 'El actor no supervisa la seccion.' USING ERRCODE = '42501';
        END IF;
    END IF;
    RETURN QUERY
    SELECT e.id_usuario,
           trim(u.nombre || ' ' || u.primer_apellido || COALESCE(' ' || u.segundo_apellido, '')),
           m.id_matricula, e.numero_expediente, s.nivel, s.numero, c.nombre
    FROM academico.matriculas m
    JOIN academico.estudiantes e ON e.id_usuario = m.id_estudiante
    JOIN academico.usuarios u ON u.id_usuario = e.id_usuario
    JOIN academico.secciones s ON s.id_seccion = m.id_seccion
    JOIN academico.cursos_lectivos c ON c.id_curso_lectivo = m.id_curso_lectivo
    WHERE m.id_seccion = p_id_seccion AND (NOT p_activos_only OR m.activa)
    ORDER BY u.primer_apellido, u.nombre, e.id_usuario
    LIMIT p_limit OFFSET p_offset;
END;
$$;

-- Asistencia detallada. El estudiante solo ve su propia cedula; personal docente
-- solo ve estudiantes de lecciones que imparte o secciones que guia.
CREATE OR REPLACE FUNCTION api.asistencia_por_cedula(
    p_cedula CITEXT,
    p_desde DATE DEFAULT NULL,
    p_hasta DATE DEFAULT NULL
)
RETURNS TABLE (
    fecha DATE,
    leccion_id BIGINT,
    asignatura TEXT,
    profesor TEXT,
    estado academico.estado_asistencia,
    observacion TEXT,
    semestre TEXT
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = pg_catalog, academico, api
AS $$
DECLARE v_estudiante BIGINT; v_actor BIGINT;
BEGIN
    SELECT e.id_usuario INTO v_estudiante FROM academico.usuarios u
    JOIN academico.estudiantes e ON e.id_usuario = u.id_usuario WHERE u.cedula = p_cedula;
    IF v_estudiante IS NULL THEN RAISE EXCEPTION 'Estudiante no encontrado.' USING ERRCODE = 'P0002'; END IF;
    IF NOT (api.tiene_rol_db('bi_api') OR api.tiene_rol_db('bi_admin')) THEN
        v_actor := api.requerir_actor();
        IF v_actor <> v_estudiante AND NOT EXISTS (
            SELECT 1 FROM academico.matriculas m
            JOIN academico.asistencia x ON x.id_matricula = m.id_matricula
            JOIN academico.lecciones l ON l.id_leccion = x.id_leccion
            WHERE m.id_estudiante = v_estudiante AND l.id_asignacion IN
                (SELECT ad.id_asignacion FROM academico.asignaciones_docentes ad WHERE ad.id_profesor = v_actor AND ad.activa)
        ) AND NOT EXISTS (
            SELECT 1 FROM academico.matriculas m JOIN academico.guias_seccion g ON g.id_seccion = m.id_seccion
            WHERE m.id_estudiante = v_estudiante AND g.id_profesor = v_actor
              AND CURRENT_DATE >= g.fecha_inicio AND (g.fecha_fin IS NULL OR CURRENT_DATE <= g.fecha_fin)
        ) THEN RAISE EXCEPTION 'El actor no puede consultar esta asistencia.' USING ERRCODE = '42501'; END IF;
    END IF;
    RETURN QUERY
    SELECT l.fecha, l.id_leccion, a.nombre,
           trim(pu.nombre || ' ' || pu.primer_apellido || COALESCE(' ' || pu.segundo_apellido, '')),
           x.estado, x.observacion, s.nombre
    FROM academico.asistencia x
    JOIN academico.matriculas m ON m.id_matricula = x.id_matricula
    JOIN academico.lecciones l ON l.id_leccion = x.id_leccion
    JOIN academico.semestres s ON s.id_semestre = l.id_semestre
    JOIN academico.asignaciones_docentes ad ON ad.id_asignacion = l.id_asignacion
    JOIN academico.asignaturas a ON a.id_asignatura = ad.id_asignatura
    JOIN academico.usuarios pu ON pu.id_usuario = ad.id_profesor
    WHERE m.id_estudiante = v_estudiante
      AND (p_desde IS NULL OR l.fecha >= p_desde) AND (p_hasta IS NULL OR l.fecha <= p_hasta)
    ORDER BY l.fecha DESC, l.hora_inicio DESC;
END;
$$;

CREATE OR REPLACE FUNCTION api.resumen_asistencia_estudiante(
    p_id_estudiante BIGINT, p_id_semestre BIGINT
)
RETURNS TABLE (total_lecciones BIGINT, presentes BIGINT, ausentes BIGINT,
               justificadas BIGINT, porcentaje_asistencia NUMERIC)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = pg_catalog, academico, api
AS $$
DECLARE v_actor BIGINT;
BEGIN
    IF NOT (api.tiene_rol_db('bi_api') OR api.tiene_rol_db('bi_admin')) THEN
        v_actor := api.requerir_actor();
        IF v_actor <> p_id_estudiante AND NOT EXISTS (
            SELECT 1 FROM academico.asignaciones_docentes ad WHERE ad.id_profesor = v_actor AND ad.activa
        ) AND NOT api.profesor_tiene_rol(v_actor, 'GUIA') THEN
            RAISE EXCEPTION 'El actor no puede consultar este resumen.' USING ERRCODE = '42501';
        END IF;
    END IF;
    RETURN QUERY SELECT COUNT(x.id_asistencia), COUNT(*) FILTER (WHERE x.estado = 'PRESENTE'),
        COUNT(*) FILTER (WHERE x.estado = 'AUSENTE'), COUNT(*) FILTER (WHERE x.estado = 'JUSTIFICADA'),
        ROUND(100.0 * COUNT(*) FILTER (WHERE x.estado IN ('PRESENTE','JUSTIFICADA')) /
              NULLIF(COUNT(x.id_asistencia), 0), 2)
    FROM academico.asistencia x JOIN academico.matriculas m ON m.id_matricula = x.id_matricula
    JOIN academico.lecciones l ON l.id_leccion = x.id_leccion
    WHERE m.id_estudiante = p_id_estudiante AND l.id_semestre = p_id_semestre;
END;
$$;

-- Lista de una leccion, autorizada para su profesor asignado o administracion.
CREATE OR REPLACE FUNCTION api.obtener_lista_leccion(p_id_leccion BIGINT)
RETURNS TABLE (id_matricula BIGINT, id_estudiante BIGINT, estudiante TEXT,
               estado academico.estado_asistencia, observacion TEXT)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = pg_catalog, academico, api
AS $$
DECLARE v_actor BIGINT; v_profesor BIGINT;
BEGIN
    SELECT ad.id_profesor INTO v_profesor FROM academico.lecciones l
    JOIN academico.asignaciones_docentes ad ON ad.id_asignacion = l.id_asignacion
    WHERE l.id_leccion = p_id_leccion;
    IF v_profesor IS NULL THEN RAISE EXCEPTION 'Leccion no encontrada.' USING ERRCODE = 'P0002'; END IF;
    IF NOT (api.tiene_rol_db('bi_api') OR api.tiene_rol_db('bi_admin')) THEN
        v_actor := api.requerir_actor();
        IF v_actor <> v_profesor THEN RAISE EXCEPTION 'El actor no es el profesor de la leccion.' USING ERRCODE = '42501'; END IF;
    END IF;
    RETURN QUERY SELECT x.id_matricula, m.id_estudiante,
        trim(u.nombre || ' ' || u.primer_apellido || COALESCE(' ' || u.segundo_apellido, '')),
        x.estado, x.observacion
    FROM academico.asistencia x JOIN academico.matriculas m ON m.id_matricula = x.id_matricula
    JOIN academico.usuarios u ON u.id_usuario = m.id_estudiante
    WHERE x.id_leccion = p_id_leccion ORDER BY u.primer_apellido, u.nombre;
END;
$$;

CREATE OR REPLACE FUNCTION api.obtener_historial_calificaciones_estudiante(
    p_id_estudiante BIGINT, p_id_curso BIGINT DEFAULT NULL
)
RETURNS TABLE (semestre TEXT, asignatura TEXT, tipo_banda academico.tipo_banda,
               banda TEXT, aprobada BOOLEAN, observacion TEXT)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = pg_catalog, academico, api
AS $$
BEGIN
    IF NOT (api.tiene_rol_db('bi_api') OR api.tiene_rol_db('bi_admin') OR api.requerir_actor() = p_id_estudiante) THEN
        RAISE EXCEPTION 'El actor no puede consultar este historial.' USING ERRCODE = '42501';
    END IF;
    RETURN QUERY SELECT s.nombre, COALESCE(a.nombre, 'Monografia')::TEXT, a.tipo_banda,
        COALESCE(c.banda_numerica::TEXT, btrim(c.banda_letra::TEXT)), c.aprobada, c.observacion
    FROM academico.calificaciones c JOIN academico.semestres s ON s.id_semestre = c.id_semestre
    LEFT JOIN academico.matriculas m ON m.id_matricula = c.id_matricula
    LEFT JOIN academico.asignaciones_docentes ad ON ad.id_asignacion = c.id_asignacion
    LEFT JOIN academico.asignaturas a ON a.id_asignatura = ad.id_asignatura
    WHERE (m.id_estudiante = p_id_estudiante OR EXISTS
        (SELECT 1 FROM academico.monografias mo WHERE mo.id_monografia = c.id_monografia AND mo.id_estudiante = p_id_estudiante))
      AND (p_id_curso IS NULL OR m.id_curso_lectivo = p_id_curso)
    ORDER BY s.fecha_inicio, a.nombre;
END;
$$;

CREATE OR REPLACE FUNCTION api.obtener_calificaciones_por_asignatura(
    p_id_asignacion BIGINT, p_id_semestre BIGINT
)
RETURNS TABLE (id_estudiante BIGINT, estudiante TEXT, banda TEXT, aprobada BOOLEAN,
               observacion TEXT, fecha_registro TIMESTAMPTZ)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = pg_catalog, academico, api
AS $$
DECLARE v_actor BIGINT; v_profesor BIGINT;
BEGIN
    SELECT id_profesor INTO v_profesor FROM academico.asignaciones_docentes
    WHERE id_asignacion = p_id_asignacion AND activa;
    IF v_profesor IS NULL THEN RAISE EXCEPTION 'Asignacion no encontrada o inactiva.' USING ERRCODE = 'P0002'; END IF;
    IF NOT (api.tiene_rol_db('bi_api') OR api.tiene_rol_db('bi_admin')) THEN
        v_actor := api.requerir_actor();
        IF v_actor <> v_profesor THEN RAISE EXCEPTION 'El actor no es el profesor asignado.' USING ERRCODE = '42501'; END IF;
    END IF;
    RETURN QUERY SELECT m.id_estudiante,
        trim(u.nombre || ' ' || u.primer_apellido || COALESCE(' ' || u.segundo_apellido, '')),
        COALESCE(c.banda_numerica::TEXT, btrim(c.banda_letra::TEXT)), c.aprobada, c.observacion, c.fecha_registro
    FROM academico.calificaciones c JOIN academico.matriculas m ON m.id_matricula = c.id_matricula
    JOIN academico.usuarios u ON u.id_usuario = m.id_estudiante
    WHERE c.id_asignacion = p_id_asignacion AND c.id_semestre = p_id_semestre
    ORDER BY u.primer_apellido, u.nombre;
END;
$$;

CREATE OR REPLACE FUNCTION api.obtener_monografias_por_estudiante(p_id_estudiante BIGINT)
RETURNS TABLE (id_monografia BIGINT, estado academico.estado_monografia, materia TEXT,
               coordinador TEXT, fecha_inicio DATE, fecha_seleccion DATE, fecha_fin DATE,
               cantidad_observaciones BIGINT)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = pg_catalog, academico, api
AS $$
BEGIN
    IF NOT (api.tiene_rol_db('bi_api') OR api.tiene_rol_db('bi_admin') OR api.requerir_actor() = p_id_estudiante) THEN
        RAISE EXCEPTION 'El actor no puede consultar esta monografia.' USING ERRCODE = '42501';
    END IF;
    RETURN QUERY SELECT mo.id_monografia, mo.estado, a.nombre,
        trim(pu.nombre || ' ' || pu.primer_apellido || COALESCE(' ' || pu.segundo_apellido, '')),
        mo.fecha_inicio, mo.fecha_seleccion_asignatura, mo.fecha_fin, COUNT(om.id_observacion)
    FROM academico.monografias mo LEFT JOIN academico.asignaturas a ON a.id_asignatura = mo.id_asignatura
    LEFT JOIN academico.coordinaciones_monografia cm ON cm.id_coordinacion = mo.id_coordinacion
    LEFT JOIN academico.usuarios pu ON pu.id_usuario = cm.id_profesor
    LEFT JOIN academico.observaciones_monografia om ON om.id_monografia = mo.id_monografia
    WHERE mo.id_estudiante = p_id_estudiante
    GROUP BY mo.id_monografia, mo.estado, a.nombre, pu.nombre, pu.primer_apellido, pu.segundo_apellido;
END;
$$;

CREATE OR REPLACE FUNCTION api.obtener_observaciones_monografia(p_id_monografia BIGINT)
RETURNS TABLE (id_observacion BIGINT, fecha_observacion TIMESTAMPTZ,
               id_profesor BIGINT, profesor TEXT, observacion TEXT)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = pg_catalog, academico, api
AS $$
DECLARE v_actor BIGINT; v_estudiante BIGINT; v_coordinador BIGINT;
BEGIN
    SELECT mo.id_estudiante, cm.id_profesor INTO v_estudiante, v_coordinador
    FROM academico.monografias mo LEFT JOIN academico.coordinaciones_monografia cm ON cm.id_coordinacion = mo.id_coordinacion
    WHERE mo.id_monografia = p_id_monografia;
    IF v_estudiante IS NULL THEN RAISE EXCEPTION 'Monografia no encontrada.' USING ERRCODE = 'P0002'; END IF;
    IF NOT (api.tiene_rol_db('bi_api') OR api.tiene_rol_db('bi_admin')) THEN
        v_actor := api.requerir_actor();
        IF v_actor <> v_estudiante AND v_actor <> v_coordinador THEN
            RAISE EXCEPTION 'Solo el estudiante o coordinador puede consultar observaciones.' USING ERRCODE = '42501';
        END IF;
    END IF;
    RETURN QUERY SELECT om.id_observacion, om.fecha_observacion, om.id_profesor,
        trim(u.nombre || ' ' || u.primer_apellido || COALESCE(' ' || u.segundo_apellido, '')),
        om.observacion
    FROM academico.observaciones_monografia om JOIN academico.usuarios u ON u.id_usuario = om.id_profesor
    WHERE om.id_monografia = p_id_monografia ORDER BY om.fecha_observacion DESC;
END;
$$;

CREATE OR REPLACE FUNCTION api.obtener_asignaciones_por_profesor(p_id_profesor BIGINT)
RETURNS TABLE (id_asignacion BIGINT, asignatura TEXT, seccion INTEGER, nivel SMALLINT,
               id_seccion BIGINT, curso_lectivo TEXT)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = pg_catalog, academico, api
AS $$
BEGIN
    IF NOT (api.tiene_rol_db('bi_api') OR api.tiene_rol_db('bi_admin') OR api.requerir_actor() = p_id_profesor) THEN
        RAISE EXCEPTION 'El actor no puede consultar estas asignaciones.' USING ERRCODE = '42501';
    END IF;
    RETURN QUERY SELECT v.id_asignacion, v.asignatura, v.seccion_numero, v.nivel,
        v.id_seccion, v.curso_lectivo FROM academico.v_carga_docente_actual v
    WHERE v.id_profesor = p_id_profesor ORDER BY v.curso_lectivo, v.nivel, v.seccion_numero, v.asignatura;
END;
$$;

-- Version paginada del reporte de guia. p_incluir_monografias evita calcular el bloque sensible.
CREATE OR REPLACE FUNCTION api.obtener_reporte_seccion(
    p_id_seccion BIGINT, p_id_semestre BIGINT, p_limit INT DEFAULT 100,
    p_offset INT DEFAULT 0, p_incluir_monografias BOOLEAN DEFAULT TRUE
)
RETURNS TABLE (id_estudiante BIGINT, estudiante TEXT, id_matricula BIGINT,
               bandas JSONB, monografia JSONB, asistencia JSONB)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = pg_catalog, academico, api
AS $$
DECLARE v_actor BIGINT;
BEGIN
    IF p_limit < 1 OR p_limit > 1000 OR p_offset < 0 THEN RAISE EXCEPTION 'Paginacion invalida.' USING ERRCODE = '22023'; END IF;
    IF NOT (api.tiene_rol_db('bi_api') OR api.tiene_rol_db('bi_admin')) THEN
        v_actor := api.requerir_actor();
        IF NOT (api.es_guia_de_seccion(v_actor, p_id_seccion) OR EXISTS
            (SELECT 1 FROM academico.asignaciones_docentes ad WHERE ad.id_profesor = v_actor AND ad.id_seccion = p_id_seccion AND ad.activa))
        THEN RAISE EXCEPTION 'El actor no supervisa la seccion.' USING ERRCODE = '42501'; END IF;
    END IF;
    RETURN QUERY SELECT m.id_estudiante,
        trim(u.nombre || ' ' || u.primer_apellido || COALESCE(' ' || u.segundo_apellido, '')),
        m.id_matricula,
        COALESCE((SELECT jsonb_agg(jsonb_build_object('id_asignacion', c.id_asignacion,
            'banda_numerica', c.banda_numerica, 'banda_letra', c.banda_letra,
            'aprobada', c.aprobada, 'observacion', c.observacion) ORDER BY c.id_calificacion)
            FROM academico.calificaciones c WHERE c.id_matricula = m.id_matricula AND c.id_semestre = p_id_semestre), '[]'::jsonb),
        CASE WHEN p_incluir_monografias THEN (SELECT jsonb_build_object('id_monografia', mo.id_monografia,
            'estado', mo.estado, 'fecha_inicio', mo.fecha_inicio, 'fecha_fin', mo.fecha_fin,
            'id_asignatura', mo.id_asignatura) FROM academico.monografias mo WHERE mo.id_estudiante = m.id_estudiante) ELSE NULL END,
        COALESCE((SELECT jsonb_agg(jsonb_build_object('id_leccion', l.id_leccion, 'fecha', l.fecha,
            'estado', x.estado, 'observacion', x.observacion) ORDER BY l.fecha, l.hora_inicio)
            FROM academico.asistencia x JOIN academico.lecciones l ON l.id_leccion = x.id_leccion
            WHERE x.id_matricula = m.id_matricula AND l.id_semestre = p_id_semestre), '[]'::jsonb)
    FROM academico.matriculas m JOIN academico.usuarios u ON u.id_usuario = m.id_estudiante
    WHERE m.id_seccion = p_id_seccion AND m.activa
    ORDER BY u.primer_apellido, u.nombre LIMIT p_limit OFFSET p_offset;
END;
$$;

-- Compatibilidad con la firma historica de functions_triggers.sql. Mantiene el
-- contrato anterior, pero hereda la autorizacion de la version paginada.
CREATE OR REPLACE FUNCTION api.obtener_reporte_seccion(
    p_id_seccion BIGINT, p_id_semestre BIGINT
)
RETURNS TABLE (id_estudiante BIGINT, estudiante TEXT, matricula BIGINT,
               bandas JSONB, monografia JSONB, asistencia JSONB)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = pg_catalog, academico, api
AS $$
    SELECT r.id_estudiante, r.estudiante, r.id_matricula,
           r.bandas, r.monografia, r.asistencia
    FROM api.obtener_reporte_seccion(p_id_seccion, p_id_semestre, 100, 0, TRUE) r;
$$;

CREATE OR REPLACE FUNCTION api.buscar_estudiante_por_cedula_o_expediente(p_text TEXT)
RETURNS TABLE (id_estudiante BIGINT, nombre_completo TEXT, cedula VARCHAR, numero_expediente VARCHAR)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = pg_catalog, academico, api
AS $$
BEGIN
    PERFORM api.requiere_rol_db('bi_api');
    RETURN QUERY SELECT e.id_usuario,
        trim(u.nombre || ' ' || u.primer_apellido || COALESCE(' ' || u.segundo_apellido, '')),
        u.cedula, e.numero_expediente
    FROM academico.estudiantes e JOIN academico.usuarios u ON u.id_usuario = e.id_usuario
    WHERE u.cedula ILIKE '%' || trim(p_text) || '%' OR e.numero_expediente ILIKE '%' || trim(p_text) || '%'
    ORDER BY u.primer_apellido, u.nombre LIMIT 100;
END;
$$;

CREATE OR REPLACE FUNCTION api.buscar_profesor_por_nombre_o_codigo(p_text TEXT)
RETURNS TABLE (id_profesor BIGINT, nombre_completo TEXT, codigo_empleado VARCHAR)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = pg_catalog, academico, api
AS $$
BEGIN
    PERFORM api.requiere_rol_db('bi_api');
    RETURN QUERY SELECT p.id_usuario,
        trim(u.nombre || ' ' || u.primer_apellido || COALESCE(' ' || u.segundo_apellido, '')),
        p.codigo_empleado
    FROM academico.profesores p JOIN academico.usuarios u ON u.id_usuario = p.id_usuario
    WHERE trim(u.nombre || ' ' || u.primer_apellido || COALESCE(' ' || u.segundo_apellido, '')) ILIKE '%' || trim(p_text) || '%'
       OR p.codigo_empleado ILIKE '%' || trim(p_text) || '%'
    ORDER BY u.primer_apellido, u.nombre LIMIT 100;
END;
$$;

-- Permisos: las tablas siguen protegidas; la aplicacion obtiene datos por EXECUTE.
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA api FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.obtener_bandas_por_cedula(CITEXT, BIGINT) TO bi_api, bi_admin, bi_estudiante;
GRANT EXECUTE ON FUNCTION api.lista_estudiantes_por_seccion(BIGINT, BOOLEAN, INT, INT) TO bi_api, bi_admin, bi_profesor, bi_guia;
GRANT EXECUTE ON FUNCTION api.asistencia_por_cedula(CITEXT, DATE, DATE) TO bi_api, bi_admin, bi_profesor, bi_guia, bi_estudiante;
GRANT EXECUTE ON FUNCTION api.resumen_asistencia_estudiante(BIGINT, BIGINT) TO bi_api, bi_admin, bi_profesor, bi_guia, bi_estudiante;
GRANT EXECUTE ON FUNCTION api.obtener_lista_leccion(BIGINT) TO bi_api, bi_admin, bi_profesor;
GRANT EXECUTE ON FUNCTION api.obtener_historial_calificaciones_estudiante(BIGINT, BIGINT) TO bi_api, bi_admin, bi_estudiante;
GRANT EXECUTE ON FUNCTION api.obtener_calificaciones_por_asignatura(BIGINT, BIGINT) TO bi_api, bi_admin, bi_profesor;
GRANT EXECUTE ON FUNCTION api.obtener_monografias_por_estudiante(BIGINT) TO bi_api, bi_admin, bi_estudiante;
GRANT EXECUTE ON FUNCTION api.obtener_observaciones_monografia(BIGINT) TO bi_api, bi_admin, bi_coord_monografia, bi_estudiante;
GRANT EXECUTE ON FUNCTION api.obtener_asignaciones_por_profesor(BIGINT) TO bi_api, bi_admin, bi_profesor;
GRANT EXECUTE ON FUNCTION api.obtener_reporte_seccion(BIGINT, BIGINT, INT, INT, BOOLEAN) TO bi_api, bi_admin, bi_profesor, bi_guia;
GRANT EXECUTE ON FUNCTION api.obtener_reporte_seccion(BIGINT, BIGINT) TO bi_api, bi_admin, bi_profesor, bi_guia;
GRANT EXECUTE ON FUNCTION api.buscar_estudiante_por_cedula_o_expediente(TEXT) TO bi_api;
GRANT EXECUTE ON FUNCTION api.buscar_profesor_por_nombre_o_codigo(TEXT) TO bi_api;

-- Tests de contrato reproducibles sin fixtures. Resultado esperado: sin excepcion.
DO $$
BEGIN
    ASSERT to_regclass('academico.v_profesores_rol') IS NOT NULL, 'falta v_profesores_rol';
    ASSERT to_regclass('academico.v_estudiantes_matriculados') IS NOT NULL, 'falta v_estudiantes_matriculados';
    ASSERT to_regclass('academico.v_carga_docente_actual') IS NOT NULL, 'falta v_carga_docente_actual';
    ASSERT to_regprocedure('api.obtener_bandas_por_cedula(citext,bigint)') IS NOT NULL, 'falta obtener_bandas_por_cedula';
    ASSERT to_regprocedure('api.obtener_reporte_seccion(bigint,bigint,integer,integer,boolean)') IS NOT NULL, 'falta reporte paginado';
    ASSERT NOT EXISTS (SELECT 1 FROM pg_attribute a JOIN pg_class c ON c.oid = a.attrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'academico' AND c.relkind = 'v'
          AND a.attname IN ('password_hash', 'token_hash')),
        'una vista expone datos sensibles';
    RAISE NOTICE 'expose_api: contrato OK';
END;
$$;

COMMIT;

-- Ejemplos (requieren un actor fijado por bi_api/bi_admin):
-- SELECT api.establecer_actor(2);
-- SELECT * FROM api.obtener_bandas_por_cedula('COLEGIO-001', NULL);
-- SELECT * FROM api.lista_estudiantes_por_seccion(1, TRUE, 100, 0);
-- SELECT * FROM api.asistencia_por_cedula('00000000', DATE '2026-01-01', NULL);
-- SELECT * FROM api.resumen_asistencia_estudiante(2, 1);
-- SELECT * FROM api.obtener_lista_leccion(1);
-- SELECT * FROM api.obtener_historial_calificaciones_estudiante(2, NULL);
-- SELECT * FROM api.obtener_calificaciones_por_asignatura(1, 1);
-- SELECT * FROM api.obtener_monografias_por_estudiante(2);
-- SELECT * FROM api.obtener_observaciones_monografia(1);
-- SELECT * FROM api.obtener_asignaciones_por_profesor(3);
-- SELECT * FROM api.obtener_reporte_seccion(1, 1, 100, 0, TRUE);
-- SELECT * FROM api.buscar_estudiante_por_cedula_o_expediente('0000');
-- SELECT * FROM api.buscar_profesor_por_nombre_o_codigo('DOC-001');
--
-- Para pruebas de negocio en una transaccion:
-- BEGIN;
-- SELECT api.establecer_actor(<id_usuario>);
-- SELECT * FROM api.obtener_historial_calificaciones_estudiante(<id_usuario>, NULL);
-- ROLLBACK;
