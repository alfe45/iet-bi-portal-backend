-- ============================================================
-- 20_catalogo_asignaturas.sql (opcional): catálogo de asignaturas del Instituto. Se ejecuta después de 01..19
-- al preparar una base nueva; las pruebas no lo usan (crean sus propias asignaturas).
-- CAS se identifica por el código 'CAS' y es TRONCAL (RN-82, AS008). MON es la asignatura TRONCAL de la monografía (RN-88). Estudios Sociales y Cívica solo en nivel 10 (RN-39).
-- ============================================================
SET search_path = academico, api, auth, public;

INSERT INTO academico.asignaturas (codigo, nombre, tipo, descripcion, imparte_nivel_10, imparte_nivel_11) VALUES
    ('HIS', 'Historia', 'SUPERIOR', 'Asignatura de Historia', TRUE, TRUE),
    ('LEA', 'Lengua A Literatura', 'SUPERIOR', 'Asignatura de Lengua A Literatura', TRUE, TRUE),
    ('LEB', 'Lengua B Inglés', 'MEDIO', 'Asignatura de Lengua B Inglés', TRUE, TRUE),
    ('SOD', 'Sociedad Digital', 'SUPERIOR', 'Asignatura de Sociedad Digital', TRUE, TRUE),
    ('MAT', 'Matemática', 'MEDIO', 'Asignatura de Matemática', TRUE, TRUE),
    ('BIO', 'Biología', 'MEDIO', 'Asignatura de Biología', TRUE, TRUE),
    ('MON', 'Monografía', 'TRONCAL', 'Asignatura de Monografía', TRUE, TRUE),
    ('TOK', 'Teoría del Conocimiento', 'TRONCAL', 'Asignatura de Teoría del Conocimiento', TRUE, TRUE),
    ('CAS', 'Creatividad, Actividad y Servicio', 'TRONCAL', 'Asignatura de Creatividad, Actividad y Servicio', TRUE, TRUE),
    ('EST', 'Estudios Sociales', 'MEP', 'Asignatura de Estudios Sociales', TRUE, FALSE),
    ('CIV', 'Cívica', 'MEP', 'Asignatura de Cívica', TRUE, FALSE);
