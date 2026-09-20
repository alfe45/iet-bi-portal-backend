-----------------------------------------------------------------------
-- PROFESORES ✅
-----------------------------------------------------------------------
TRUNCATE TABLE academico.profesores RESTART IDENTITY CASCADE;

-- CREATE
CALL api.registrar_profesor(
    'Juan', 'Pérez', 'Gómez', '11111111', '0987654321',
    'juan.perez@example.com', DATE '1980-01-01', 'hashed_password_1', NULL
);

CALL api.registrar_profesor(
    'María', 'López', 'Rodríguez', '22222222', '0123456789',
    'maria.lopez@example.com', DATE '1985-05-15', 'hashed_password_2', NULL
);

CALL api.registrar_profesor(
    'Carlos', 'García', 'Fernández', '33333333', '0987123456',
    'carlos.garcia@example.com', DATE '1990-12-10', 'hashed_password_3', NULL
);

CALL api.registrar_profesor(
    'Ana', 'Martínez', 'Sánchez', '44444444', '0987234567',
    'ana.martinez@example.com', DATE '1995-08-20', 'hashed_password_4', NULL
);

CALL api.registrar_profesor(
    'Luis', 'Hernández', 'Díaz', '55555555', '0987345678',
    'luis.hernandez@example.com', DATE '1990-05-10', 'hashed_password_5', NULL
);

-- READ 1
SELECT * FROM api.obtener_profesor('11111111');

-- READ ALL
SELECT * FROM api.obtener_profesores();

-- UPDATE
CALL api.actualizar_profesor(
    '11111111', 'Juan Carlos', 'Pérez', 'Gómez', '11111111', '0987654321',
    'juan.carlos@example.com', DATE '1980-01-01', 'hashed_password_updated', NULL
);

-- DEACTIVATE
CALL api.desactivar_profesor('11111111', NULL);

-- ACTIVATE
CALL api.activar_profesor('11111111', NULL);

-- DELETE
CALL api.borrar_profesor('55555555', NULL);


-----------------------------------------------------------------------
-- ESTUDIANTES ✅
-----------------------------------------------------------------------
TRUNCATE TABLE academico.estudiantes RESTART IDENTITY CASCADE;

-- CREATE
CALL api.registrar_estudiante(
    'Alexander', 'Fernández', 'Dinarte', '604790027', '61262100',
    'afernandezdinarte45@gmail.com', DATE '2007-10-15', NULL
);

CALL api.registrar_estudiante(
    'Sofía', 'Ramírez', 'Castro', '604790028', '88880001',
    'sofia.ramirez@example.com', DATE '2008-03-12', NULL
);

CALL api.registrar_estudiante(
    'Valentina', 'Solís', 'Jiménez', '604790029', '88880003',
    'valentina.solis@example.com', DATE '2009-01-18', NULL
);

CALL api.registrar_estudiante(
    'Mateo', 'Rojas', 'Navarro', '604790030', '88880004',
    'mateo.rojas@example.com', DATE '2007-11-30', NULL
);

CALL api.registrar_estudiante(
    'Camila', 'Quesada', 'Pérez', '604790031', '88880005',
    'camila.quesada@example.com', DATE '2010-06-05', NULL
);

-- READ 1
SELECT * FROM api.obtener_estudiante('604790027');

-- READ ALL
SELECT * FROM api.obtener_estudiantes();

-- UPDATE
CALL api.actualizar_estudiante(
    '604790027', 'Alexander José', 'Fernández', 'Dinarte', '604790027', '61262100',
    'alexander.fdez@example.com', DATE '2007-10-15', NULL
);

-- DELETE
CALL api.borrar_estudiante('604790031', NULL);

-----------------------------------------------------------------------
-- CURSOS LECTIVOS ✅
-----------------------------------------------------------------------
TRUNCATE TABLE academico.cursos_lectivos RESTART IDENTITY CASCADE;

-- CREATE
CALL api.abrir_curso_lectivo(
    2025,
    DATE '2025-01-01', DATE '2025-06-30',
    DATE '2025-07-01', DATE '2025-12-31',
    NULL
);

CALL api.abrir_curso_lectivo(
    2026,
    DATE '2026-01-01', DATE '2026-06-30',
    DATE '2026-07-01', DATE '2026-12-31',
    NULL
);

CALL api.abrir_curso_lectivo(
    2027,
    DATE '2027-01-01', DATE '2027-06-30',
    DATE '2027-07-01', DATE '2027-12-31',
    NULL
);

CALL api.abrir_curso_lectivo(
    2028,
    DATE '2028-01-01', DATE '2028-06-30',
    DATE '2028-07-01', DATE '2028-12-31',
    NULL
);

-- READ 1
SELECT * FROM api.obtener_curso_lectivo(2026);

-- READ ALL
SELECT * FROM api.obtener_cursos_lectivos();

-- UPDATE
CALL api.actualizar_curso_lectivo(
    2025,
    DATE '2025-01-15', DATE '2025-06-15',
    DATE '2025-07-15', DATE '2025-12-15',
    NULL
);

-- DELETE
CALL api.borrar_curso_lectivo(2028, NULL);
-- -- consulta con los semestres insertados y sus respectivos cursos lectivos
-- SELECT c.year_ciclo, s.numero_semestre, s.fecha_inicio, s.fecha_fin
-- FROM academico.semestres s
-- JOIN academico.cursos_lectivos c ON s.id_curso_lectivo = c.id_curso_lectivo
-- ORDER BY s.id_curso_lectivo, s.numero_semestre;

-----------------------------------------------------------------------
-- SECCIONES ✅
-----------------------------------------------------------------------
TRUNCATE TABLE academico.secciones RESTART IDENTITY CASCADE;

-- CREATE
CALL api.registrar_seccion(2025, 10, 1, NULL);
CALL api.registrar_seccion(2025, 10, 2, NULL);
CALL api.registrar_seccion(2025, 11, 1, NULL);
CALL api.registrar_seccion(2025, 11, 2, NULL);

CALL api.registrar_seccion(2026, 10, 1, NULL);
CALL api.registrar_seccion(2026, 10, 2, NULL);
CALL api.registrar_seccion(2026, 11, 1, NULL);
CALL api.registrar_seccion(2026, 11, 2, NULL);

CALL api.registrar_seccion(2027, 10, 1, NULL);
CALL api.registrar_seccion(2027, 10, 2, NULL);
CALL api.registrar_seccion(2027, 11, 1, NULL);
CALL api.registrar_seccion(2027, 11, 2, NULL);

-- READ ALL
SELECT * FROM api.obtener_secciones();

-- DELETE
CALL api.borrar_seccion(2027, 11, 2, NULL);

-----------------------------------------------------------------------
-- MATRICULAS
-----------------------------------------------------------------------
TRUNCATE TABLE academico.matriculas_secciones RESTART IDENTITY CASCADE;

-- MATRICULAR NIVEL 10
CALL api.matricular_estudiante_en_nivel_10('604790027', 2025, 1, NULL);
CALL api.matricular_estudiante_en_nivel_10('604790028', 2025, 2, NULL);
CALL api.matricular_estudiante_en_nivel_10('604790029', 2026, 1, NULL);
CALL api.matricular_estudiante_en_nivel_10('604790030', 2026, 2, NULL);

-- FINALIZAR NIVEL 10
CALL api.finalizar_matricula(1, NULL);
CALL api.finalizar_matricula(2, NULL);

-- MATRICULAR NIVEL 11
CALL api.matricular_estudiante_en_nivel_11('604790027', NULL);
CALL api.matricular_estudiante_en_nivel_11('604790028', NULL);

-- READ ALL FROM 1
SELECT * FROM api.obtener_matriculas_estudiante('604790027');
SELECT * FROM api.obtener_matriculas_estudiante('604790028');

-- DELETE
CALL api.borrar_matricula(6, NULL);