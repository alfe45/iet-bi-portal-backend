-- name=views.sql
-- Vistas útiles para administración y diagnóstico.
-- Ejecutar al final (depende de todo lo demás)

BEGIN;
SET search_path = academico, api, pg_catalog;

-- Vista: profesores activos con roles
CREATE OR REPLACE VIEW academico.v_profesores_activos AS
SELECT p.id_usuario AS id_profesor,
       trim(u.nombre || ' ' || u.primer_apellido || COALESCE(' '||u.segundo_apellido,'')) AS nombre,
       p.codigo_empleado,
       array_agg(pr.tipo ORDER BY pr.tipo) FILTER (WHERE pr.activo = TRUE) AS roles_activos
FROM academico.profesores p
JOIN academico.usuarios u ON u.id_usuario = p.id_usuario
LEFT JOIN academico.profesor_roles pr ON pr.id_profesor = p.id_usuario
GROUP BY p.id_usuario, u.nombre, u.primer_apellido, u.segundo_apellido, p.codigo_empleado;

-- Vista: asignaciones actuales por profesor
CREATE OR REPLACE VIEW academico.v_asignaciones_actuales AS
SELECT ad.id_asignacion, ad.id_profesor, a.nombre AS asignatura, s.nivel, s.numero AS seccion_numero, ad.activa
FROM academico.asignaciones_docentes ad
JOIN academico.asignaturas a ON a.id_asignatura = ad.id_asignatura
JOIN academico.secciones s ON s.id_seccion = ad.id_seccion
WHERE ad.activa = TRUE;

-- Vista: estudiantes activos con sección y curso
CREATE OR REPLACE VIEW academico.v_estudiantes_activos AS
SELECT e.id_usuario AS id_estudiante,
       trim(u.nombre || ' ' || u.primer_apellido || COALESCE(' '||u.segundo_apellido,'')) AS nombre,
       m.id_matricula, m.id_seccion, s.nivel, s.numero AS seccion_numero, m.id_curso_lectivo, c.nombre AS curso_nombre
FROM academico.estudiantes e
JOIN academico.usuarios u ON u.id_usuario = e.id_usuario
LEFT JOIN academico.matriculas m ON m.id_estudiante = e.id_usuario AND m.activa = TRUE
LEFT JOIN academico.secciones s ON s.id_seccion = m.id_seccion
LEFT JOIN academico.cursos_lectivos c ON c.id_curso_lectivo = m.id_curso_lectivo;

-- Vista: cursos lectivos y semestres.
CREATE OR REPLACE VIEW academico.v_periodos_academicos AS
SELECT c.id_curso_lectivo,
    c.nombre AS curso,
    c.fecha_inicio AS curso_inicio,
    c.fecha_fin AS curso_fin,
    c.activo AS curso_activo,
    s.id_semestre,
    s.nombre AS semestre,
    s.fecha_inicio AS semestre_inicio,
    s.fecha_fin AS semestre_fin,
    s.activo AS semestre_activo
FROM academico.cursos_lectivos c
LEFT JOIN academico.semestres s ON s.id_curso_lectivo = c.id_curso_lectivo;

-- Vista: secciones con guía y cantidad de estudiantes.
CREATE OR REPLACE VIEW academico.v_secciones_detalle AS
SELECT s.id_seccion,
    c.id_curso_lectivo,
    c.nombre AS curso,
    s.nivel,
    s.numero,
    s.activa,
    gs.id_profesor AS id_guia,
    trim(gu.nombre || ' ' || gu.primer_apellido || COALESCE(' ' || gu.segundo_apellido, '')) AS guia,
    COUNT(m.id_matricula) FILTER (WHERE m.activa) AS estudiantes_activos
FROM academico.secciones s
JOIN academico.cursos_lectivos c ON c.id_curso_lectivo = s.id_curso_lectivo
LEFT JOIN academico.guias_seccion gs
    ON gs.id_seccion = s.id_seccion
      AND CURRENT_DATE >= gs.fecha_inicio
      AND (gs.fecha_fin IS NULL OR CURRENT_DATE <= gs.fecha_fin)
LEFT JOIN academico.usuarios gu ON gu.id_usuario = gs.id_profesor
LEFT JOIN academico.matriculas m ON m.id_seccion = s.id_seccion
GROUP BY s.id_seccion, c.id_curso_lectivo, c.nombre, s.nivel, s.numero, s.activa,
      gs.id_profesor, gu.nombre, gu.primer_apellido, gu.segundo_apellido;

-- Vista: profesores, sus roles y asignaciones.
CREATE OR REPLACE VIEW academico.v_docentes_asignaciones AS
SELECT p.id_usuario AS id_profesor,
    trim(u.nombre || ' ' || u.primer_apellido || COALESCE(' ' || u.segundo_apellido, '')) AS profesor,
    p.codigo_empleado,
    COALESCE(array_agg(DISTINCT pr.tipo ORDER BY pr.tipo)
          FILTER (WHERE pr.activo), ARRAY[]::academico.tipo_profesor[]) AS roles,
    ad.id_asignacion,
    a.codigo AS codigo_asignatura,
    a.nombre AS asignatura,
    s.id_seccion,
    s.nivel,
    s.numero AS numero_seccion,
    ad.activa AS asignacion_activa
FROM academico.profesores p
JOIN academico.usuarios u ON u.id_usuario = p.id_usuario
LEFT JOIN academico.profesor_roles pr ON pr.id_profesor = p.id_usuario
LEFT JOIN academico.asignaciones_docentes ad ON ad.id_profesor = p.id_usuario
LEFT JOIN academico.asignaturas a ON a.id_asignatura = ad.id_asignatura
LEFT JOIN academico.secciones s ON s.id_seccion = ad.id_seccion
GROUP BY p.id_usuario, u.nombre, u.primer_apellido, u.segundo_apellido,
      p.codigo_empleado, ad.id_asignacion, a.codigo, a.nombre,
      s.id_seccion, s.nivel, s.numero, ad.activa;

-- Vista: matrícula con estudiante, sección y curso.
CREATE OR REPLACE VIEW academico.v_matriculas_detalle AS
SELECT m.id_matricula,
    m.id_estudiante,
    trim(u.nombre || ' ' || u.primer_apellido || COALESCE(' ' || u.segundo_apellido, '')) AS estudiante,
    u.email,
    m.id_curso_lectivo,
    c.nombre AS curso,
    m.id_seccion,
    s.nivel,
    s.numero AS numero_seccion,
    m.fecha_matricula,
    m.fecha_retiro,
    m.activa
FROM academico.matriculas m
JOIN academico.estudiantes e ON e.id_usuario = m.id_estudiante
JOIN academico.usuarios u ON u.id_usuario = e.id_usuario
JOIN academico.cursos_lectivos c ON c.id_curso_lectivo = m.id_curso_lectivo
JOIN academico.secciones s ON s.id_seccion = m.id_seccion;

-- Vista: calificaciones de asignaturas y monografías.
CREATE OR REPLACE VIEW academico.v_calificaciones_detalle AS
SELECT c.id_calificacion,
    c.id_semestre,
    s.nombre AS semestre,
    c.id_matricula,
    m.id_estudiante,
    c.id_asignacion,
    a.nombre AS asignatura,
    c.id_monografia,
    c.banda_numerica,
    c.banda_letra,
    c.aprobada,
    c.observacion,
    c.fecha_registro
FROM academico.calificaciones c
JOIN academico.semestres s ON s.id_semestre = c.id_semestre
LEFT JOIN academico.matriculas m ON m.id_matricula = c.id_matricula
LEFT JOIN academico.asignaciones_docentes ad ON ad.id_asignacion = c.id_asignacion
LEFT JOIN academico.asignaturas a ON a.id_asignatura = ad.id_asignatura;

-- Vista: resumen de asistencia por estudiante y semestre.
CREATE OR REPLACE VIEW academico.v_asistencia_resumen AS
SELECT m.id_estudiante,
    m.id_seccion,
    l.id_semestre,
    COUNT(a.id_asistencia) AS lecciones_registradas,
    COUNT(*) FILTER (WHERE a.estado = 'PRESENTE') AS presentes,
    COUNT(*) FILTER (WHERE a.estado = 'AUSENTE') AS ausencias,
    COUNT(*) FILTER (WHERE a.estado = 'TARDANZA') AS tardanzas,
    COUNT(*) FILTER (WHERE a.estado = 'JUSTIFICADA') AS ausencias_justificadas,
    ROUND(100.0 * COUNT(*) FILTER (WHERE a.estado IN ('PRESENTE', 'JUSTIFICADA')) /
          NULLIF(COUNT(a.id_asistencia), 0), 2) AS porcentaje_asistencia
FROM academico.matriculas m
JOIN academico.asistencia a ON a.id_matricula = m.id_matricula
JOIN academico.lecciones l ON l.id_leccion = a.id_leccion
GROUP BY m.id_estudiante, m.id_seccion, l.id_semestre;

-- Vista: seguimiento de monografías y coordinación responsable.
CREATE OR REPLACE VIEW academico.v_monografias_seguimiento AS
SELECT mo.id_monografia,
    mo.id_estudiante,
    trim(u.nombre || ' ' || u.primer_apellido || COALESCE(' ' || u.segundo_apellido, '')) AS estudiante,
    mo.id_curso_lectivo_inicio,
    mo.fecha_inicio,
    mo.fecha_fin,
    mo.estado,
    mo.id_asignatura,
    a.nombre AS asignatura,
    mo.id_coordinacion,
    cm.id_profesor AS id_coordinador,
    trim(pu.nombre || ' ' || pu.primer_apellido || COALESCE(' ' || pu.segundo_apellido, '')) AS coordinador,
    mo.fecha_seleccion_asignatura
FROM academico.monografias mo
JOIN academico.estudiantes e ON e.id_usuario = mo.id_estudiante
JOIN academico.usuarios u ON u.id_usuario = e.id_usuario
LEFT JOIN academico.asignaturas a ON a.id_asignatura = mo.id_asignatura
LEFT JOIN academico.coordinaciones_monografia cm ON cm.id_coordinacion = mo.id_coordinacion
LEFT JOIN academico.usuarios pu ON pu.id_usuario = cm.id_profesor;

-- Vista: justificaciones y estado actual de la asistencia.
CREATE OR REPLACE VIEW academico.v_justificaciones_asistencia AS
SELECT ja.id_justificacion,
    ja.id_asistencia,
    a.id_matricula,
    m.id_estudiante,
    l.id_leccion,
    l.fecha AS fecha_leccion,
    a.estado AS estado_asistencia,
    ja.id_usuario_autor,
    trim(u.nombre || ' ' || u.primer_apellido || COALESCE(' ' || u.segundo_apellido, '')) AS autor,
    ja.fecha_justificacion,
    ja.comentario,
    ja.adjunto_url
FROM academico.justificaciones_asistencia ja
JOIN academico.asistencia a ON a.id_asistencia = ja.id_asistencia
JOIN academico.matriculas m ON m.id_matricula = a.id_matricula
JOIN academico.lecciones l ON l.id_leccion = a.id_leccion
JOIN academico.usuarios u ON u.id_usuario = ja.id_usuario_autor;

-- Vista: reporte académico completo por estudiante y asignatura.
CREATE OR REPLACE VIEW academico.v_reporte_estudiante_asignaturas AS
SELECT m.id_estudiante,
    trim(u.nombre || ' ' || u.primer_apellido || COALESCE(' ' || u.segundo_apellido, '')) AS estudiante,
    m.id_matricula,
    m.id_curso_lectivo,
    c.nombre AS curso,
    se.id_semestre,
    se.nombre AS semestre,
    ad.id_asignacion,
    ad.id_asignatura,
    asig.codigo AS codigo_asignatura,
    asig.nombre AS asignatura,
    asig.tipo_banda,
    CASE WHEN asig.tipo_banda = 'NUMERICA' THEN '1' ELSE 'A' END AS banda_minima,
    CASE
        WHEN cal.banda_numerica IS NOT NULL THEN cal.banda_numerica::TEXT
        ELSE btrim(cal.banda_letra::TEXT)
    END AS banda_alcanzada,
    cal.aprobada,
    COALESCE(asis.lecciones_registradas, 0) AS lecciones_registradas,
    COALESCE(asis.presentes, 0) AS presentes,
    COALESCE(asis.ausencias, 0) AS ausencias,
    COALESCE(asis.tardanzas, 0) AS tardanzas,
    COALESCE(asis.ausencias_justificadas, 0) AS ausencias_justificadas,
    COALESCE(asis.porcentaje_asistencia, 0) AS porcentaje_asistencia,
    cal.observacion AS observacion_calificacion,
    asis.observaciones_asistencia
FROM academico.matriculas m
JOIN academico.usuarios u ON u.id_usuario = m.id_estudiante
JOIN academico.cursos_lectivos c ON c.id_curso_lectivo = m.id_curso_lectivo
JOIN academico.semestres se ON se.id_curso_lectivo = m.id_curso_lectivo
JOIN academico.asignaciones_docentes ad ON ad.id_seccion = m.id_seccion
JOIN academico.asignaturas asig ON asig.id_asignatura = ad.id_asignatura
LEFT JOIN academico.calificaciones cal
    ON cal.id_semestre = se.id_semestre
   AND cal.id_matricula = m.id_matricula
   AND cal.id_asignacion = ad.id_asignacion
LEFT JOIN LATERAL (
    SELECT COUNT(a.id_asistencia) AS lecciones_registradas,
        COUNT(*) FILTER (WHERE a.estado = 'PRESENTE') AS presentes,
        COUNT(*) FILTER (WHERE a.estado = 'AUSENTE') AS ausencias,
        COUNT(*) FILTER (WHERE a.estado = 'TARDANZA') AS tardanzas,
        COUNT(*) FILTER (WHERE a.estado = 'JUSTIFICADA') AS ausencias_justificadas,
        ROUND(100.0 * COUNT(*) FILTER (WHERE a.estado IN ('PRESENTE', 'JUSTIFICADA')) /
              NULLIF(COUNT(a.id_asistencia), 0), 2) AS porcentaje_asistencia,
        jsonb_agg(jsonb_build_object(
            'fecha', l.fecha,
            'estado', a.estado,
            'observacion', a.observacion
        ) ORDER BY l.fecha, l.hora_inicio) FILTER (WHERE a.id_asistencia IS NOT NULL) AS observaciones_asistencia
    FROM academico.lecciones l
    LEFT JOIN academico.asistencia a
        ON a.id_leccion = l.id_leccion
       AND a.id_matricula = m.id_matricula
    WHERE l.id_asignacion = ad.id_asignacion
      AND l.id_semestre = se.id_semestre
) ASIS ON TRUE
WHERE m.activa = TRUE
  AND ad.activa = TRUE;

COMMIT;

