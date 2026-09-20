-----------------------------------------------------------------------
-- ASIGNATURAS
-----------------------------------------------------------------------
CALL academico.registrar_asignatura('HIS', 'SUPERIOR', 'Historia', 'Asignatura de Historia', NULL);
CALL academico.registrar_asignatura('LEA', 'SUPERIOR', 'Lengua A Literatura', 'Asignatura de Lengua A Literatura', NULL);
CALL academico.registrar_asignatura('LEB', 'MEDIO', 'Lengua B Inglés', 'Asignatura de Lengua B Inglés', NULL);
CALL academico.registrar_asignatura('SOD', 'SUPERIOR', 'Sociedad Digital', 'Asignatura de Sociedad Digital', NULL);
CALL academico.registrar_asignatura('MAT', 'MEDIO', 'Matemática', 'Asignatura de Matemática', NULL);
CALL academico.registrar_asignatura('BIO', 'MEDIO', 'Biología', 'Asignatura de Biología', NULL);
CALL academico.registrar_asignatura('MON', 'TRONCAL', 'Monografía', 'Asignatura de Monografía', NULL);
CALL academico.registrar_asignatura('TOK', 'TRONCAL', 'Teoría del Conocimiento', 'Asignatura de Teoría del Conocimiento', NULL);
CALL academico.registrar_asignatura('CAS', 'TRONCAL', 'Asignatura de Creatividad, Actividad y Servicio', NULL, NULL);
CALL academico.registrar_asignatura('EST', 'MEP', 'Asignatura de Estudios Sociales', 'Asignatura de Estudios Sociales', NULL);
CALL academico.registrar_asignatura('CIV', 'MEP', 'Asignatura de Civica', 'Asignatura de Civica', NULL);

-- consulta todas las asignaturas
SELECT * FROM academico.asignaturas ORDER BY codigo;


-- insert matriculas
INSERT INTO academico.matriculas (
    id_estudiante, 
    id_seccion)
VALUES
    (1, 1),
    (2, 1),
    (3, 2),
    (4, 2),
    (5, 2);

-- consulta estudiantes matriculados en cada sección
SELECT c.year_ciclo,
    s.id_seccion,
    s.nivel || '-' || s.numero_seccion as seccion, 
    e.id_estudiante,
    e.nombre || ' ' || e.primer_apellido || ' ' || COALESCE(e.segundo_apellido, '') AS nombre_estudiante
FROM academico.secciones s
JOIN academico.cursos_lectivos c ON s.id_curso_lectivo = c.id_curso_lectivo
LEFT JOIN academico.matriculas m ON s.id_seccion = m.id_seccion
LEFT JOIN academico.estudiantes e ON m.id_estudiante = e.id_estudiante
ORDER BY c.year_ciclo, s.nivel, s.numero_seccion, e.id_estudiante;



-- insert asignaciones docentes
INSERT INTO academico.asignaciones_docentes (
    id_profesor, 
    id_asignatura, 
    id_seccion, 
    activa)
VALUES
    (1, 1, 1, TRUE),
    (2, 2, 1, TRUE),
    (3, 3, 2, TRUE),
    (4, 4, 2, TRUE),
    (5, 5, 2, TRUE);

-- consulta todas las asignaciones docentes
SELECT c.year_ciclo,
    s.id_seccion,
    s.nivel || '-' || s.numero_seccion as seccion, 
    p.id_profesor,
    p.nombre || ' ' || p.primer_apellido || ' ' || COALESCE(p.segundo_apellido, '') AS nombre_profesor, 
    a.id_asignatura,
    a.codigo AS codigo_asignatura,
    a.nombre AS nombre_asignatura,
    ad.activa AS asignacion_activa
FROM academico.asignaciones_docentes ad
JOIN academico.secciones s ON ad.id_seccion = s.id_seccion
JOIN academico.cursos_lectivos c ON s.id_curso_lectivo = c.id_curso_lectivo
JOIN academico.profesores p ON ad.id_profesor = p.id_profesor
JOIN academico.asignaturas a ON ad.id_asignatura = a.id_asignatura
ORDER BY c.year_ciclo, s.nivel, s.numero_seccion, a.codigo;

-- insertar guías de sección
INSERT INTO academico.guias_seccion (
    id_seccion, 
    id_profesor, 
    fecha_inicio)
VALUES
    (1, 1, '2026-01-01'),
    (2, 2, '2026-01-01');

-- consulta historica detodas las secciones y sus profesores asignados como guías
SELECT c.year_ciclo,
    s.id_seccion,
    s.nivel || '-' || s.numero_seccion as seccion, 
    p.id_profesor,
    p.nombre || ' ' || p.primer_apellido || ' ' || COALESCE(p.segundo_apellido, '') AS nombre_profesor, 
    g.fecha_inicio AS fecha_inicio_guia,
    g.fecha_fin AS fecha_fin_guia
FROM academico.secciones s
JOIN academico.cursos_lectivos c ON s.id_curso_lectivo = c.id_curso_lectivo
LEFT JOIN academico.guias_seccion g ON s.id_seccion = g.id_seccion
LEFT JOIN academico.profesores p ON g.id_profesor = p.id_profesor
ORDER BY c.year_ciclo, s.nivel, s.numero_seccion;