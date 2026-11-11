-- ============================================================
-- Migración 2026-11-11 (revalidación, DV-008): el catálogo de asignaturas del Instituto es obligatorio.
-- CAS y MON son parte del sistema: no se pueden eliminar (AS009) y MON debe ser TRONCAL (AS010).
-- Reemplaza dos funciones y agrega las asignaturas del catálogo que falten (no duplica ni modifica las existentes).
-- No borra datos. Después de ejecutarla, reiniciar la API.
-- ============================================================
SET search_path = academico, api, auth, public;

-- RN-82: AS008 si la asignatura CAS no es TRONCAL (su nota usa la escala A a E y tiene su propio informe).
-- RN-88: AS010 si la asignatura de la monografía (MON) no es TRONCAL.
CREATE OR REPLACE FUNCTION academico.fn_validar_tipo_asignatura(p_codigo TEXT, p_tipo academico.tipo_asignatura)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_codigo = 'CAS' AND p_tipo IS DISTINCT FROM 'TRONCAL' THEN
        PERFORM api.fn_lanzar_excepcion('AS008', 'La asignatura CAS debe ser de tipo TRONCAL.');
    END IF;
    IF p_codigo = 'MON' AND p_tipo IS DISTINCT FROM 'TRONCAL' THEN
        PERFORM api.fn_lanzar_excepcion('AS010', 'La asignatura de Monografía (MON) debe ser de tipo TRONCAL.');
    END IF;
END;
$$;

-- CU 24 - Eliminar asignatura. Devuelve el snapshot previo. Si otras entidades la referencian
-- (asignaciones docentes) con FK RESTRICT, Postgres lanza 23001.
CREATE OR REPLACE FUNCTION academico.fn_admin_eliminar_asignatura(
    p_id_usuario_actor UUID,
    p_codigo TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_prev academico.asignaturas%ROWTYPE;
BEGIN
    PERFORM api.fn_validar_admin_activo(p_id_usuario_actor);

    SELECT * INTO v_prev
    FROM academico.asignaturas
    WHERE codigo = academico.fn_normalizar_codigo_asignatura(p_codigo)
    FOR UPDATE;

    IF NOT FOUND THEN
        PERFORM api.fn_lanzar_excepcion('NF007', 'La asignatura no existe.');
    END IF;

    -- RN-82/RN-88: CAS y MON vienen del catálogo (20_catalogo_asignaturas.sql) y el sistema depende de ellas.
    IF v_prev.codigo IN ('CAS', 'MON') THEN
        PERFORM api.fn_lanzar_excepcion('AS009', 'Las asignaturas CAS y Monografía (MON) son parte del sistema: no se pueden eliminar.');
    END IF;

    DELETE FROM academico.asignaturas WHERE id_asignatura = v_prev.id_asignatura;

    RETURN to_jsonb(v_prev) - 'id_asignatura';
END;
$$;

-- Catálogo del Instituto (20_catalogo_asignaturas.sql): solo las que todavía no existan por código.
-- Si una asignatura ya existe con otro código pero el mismo nombre, el INSERT falla por uq_asignaturas_nombre: revisar a mano.
INSERT INTO academico.asignaturas (codigo, nombre, tipo, descripcion, imparte_nivel_11, imparte_nivel_12) VALUES
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
    ('CIV', 'Cívica', 'MEP', 'Asignatura de Cívica', TRUE, FALSE)
ON CONFLICT (codigo) DO NOTHING;
