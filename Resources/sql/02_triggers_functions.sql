SET search_path = academico, pg_catalog;

-----------------------------------------------------------------------
-- LANZAR EXCEPCION ✅
-----------------------------------------------------------------------
CREATE OR REPLACE FUNCTION academico.fn_lanzar_excepcion(
    p_message TEXT,
    p_detail JSONB DEFAULT NULL,
    p_hint TEXT DEFAULT NULL,
    p_error_code TEXT DEFAULT '00000'
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION USING
        MESSAGE = p_message,
        DETAIL = COALESCE(p_detail::TEXT, ''),
        HINT = COALESCE(p_hint, ''),
        ERRCODE = COALESCE(p_error_code, '00000');
END;
$$;

-----------------------------------------------------------------------
-- CURSOS LECTIVOS
-----------------------------------------------------------------------

-- DEVUELVE EL CURSO LECTIVO ACTUAL ✅
CREATE OR REPLACE FUNCTION academico.fn_obtener_curso_lectivo_actual()
RETURNS SETOF academico.curso_lectivo_publico
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    RETURN QUERY
    SELECT c.id_curso_lectivo, c.year_ciclo, c.fecha_inicio, c.fecha_fin
    FROM academico.cursos_lectivos c
    WHERE c.year_ciclo = EXTRACT(YEAR FROM CURRENT_DATE)
        AND CURRENT_DATE BETWEEN c.fecha_inicio AND c.fecha_fin;

    IF NOT FOUND THEN
        PERFORM academico.fn_lanzar_excepcion(
            'No existe un curso lectivo actual para la fecha.',
            jsonb_build_object(
                'count(*) cursos_lectivos', (SELECT COUNT(*) FROM academico.cursos_lectivos),
                'fecha_actual', CURRENT_DATE    
            ),
            'Debe agregar un curso lectivo',
            'CL001'
        );
    END IF;   
END;
$$;

-----------------------------------------------------------------------
-- SEMESTRES
-----------------------------------------------------------------------

-- VALIDACIÓN DE SEMESTRES
CREATE OR REPLACE FUNCTION academico.fn_semestres_validar_fechas()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_fecha_inicio_curso DATE;
    v_fecha_fin_curso DATE;
BEGIN
    SELECT c.fecha_inicio, c.fecha_fin
        INTO v_fecha_inicio_curso, v_fecha_fin_curso
        FROM academico.cursos_lectivos c
    WHERE c.id_curso_lectivo = NEW.id_curso_lectivo;

    IF v_fecha_inicio_curso IS NULL THEN--🕛
        PERFORM academico.fn_lanzar_excepcion(
            'El curso lectivo indicado no existe.',
            jsonb_build_object(
                'id_curso_lectivo', NEW.id_curso_lectivo
            ),
            NULL,
            'SM001'
        );
    ELSIF NEW.numero_semestre = 'I_SEMESTRE'--🕛
        AND NEW.fecha_inicio IS DISTINCT FROM v_fecha_inicio_curso THEN
        PERFORM academico.fn_lanzar_excepcion(
            'La fecha de inicio del I semestre debe coincidir con la fecha de inicio del curso lectivo.',
            jsonb_build_object(
                'id_curso_lectivo', NEW.id_curso_lectivo,
                'fecha_inicio_curso', v_fecha_inicio_curso,
                'fecha_inicio_semestre', NEW.fecha_inicio
            ),
            NULL,
            'SM002'
        );
    ELSIF NEW.numero_semestre = 'I_SEMESTRE'--🕛
        AND NEW.fecha_fin >= v_fecha_fin_curso THEN
        PERFORM academico.fn_lanzar_excepcion(
            'La fecha de fin del I semestre debe ser anterior a la fecha de fin del curso lectivo.',
            jsonb_build_object(
                'id_curso_lectivo', NEW.id_curso_lectivo,
                'fecha_fin_curso', v_fecha_fin_curso,
                'fecha_fin_semestre', NEW.fecha_fin
            ),
            NULL,
            'SM003'
        );
    ELSIF NEW.numero_semestre = 'II_SEMESTRE'--🕛
        AND NEW.fecha_inicio <= v_fecha_inicio_curso THEN
        PERFORM academico.fn_lanzar_excepcion(
            'La fecha de inicio del II semestre debe ser posterior a la fecha de inicio del curso lectivo.',
            jsonb_build_object(
                'id_curso_lectivo', NEW.id_curso_lectivo,
                'fecha_inicio_curso', v_fecha_inicio_curso,
                'fecha_inicio_semestre', NEW.fecha_inicio
            ),
            NULL,
            'SM004'
        );
    ELSIF NEW.numero_semestre = 'II_SEMESTRE'--🕛
        AND NEW.fecha_fin IS DISTINCT FROM v_fecha_fin_curso THEN
        PERFORM academico.fn_lanzar_excepcion(
            'La fecha de fin del II semestre debe coincidir con la fecha de fin del curso lectivo.',
            jsonb_build_object(
                'id_curso_lectivo', NEW.id_curso_lectivo,
                'fecha_fin_curso', v_fecha_fin_curso,
                'fecha_fin_semestre', NEW.fecha_fin
            ),
            NULL,
            'SM005'
        );
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_semestres_validar_fechas ON academico.semestres;
CREATE TRIGGER trg_semestres_validar_fechas
BEFORE INSERT OR UPDATE
ON academico.semestres
FOR EACH ROW
EXECUTE FUNCTION academico.fn_semestres_validar_fechas();

-----------------------------------------------------------------------
-- MATRICULAS
-----------------------------------------------------------------------
CREATE OR REPLACE FUNCTION academico.fn_matriculas_validas()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_curso_lectivo BIGINT;
    v_id_curso_lectivo_actual BIGINT;
    v_year_ciclo INTEGER;
    v_year_ciclo_actual INTEGER;
    v_nivel INTEGER;
    v_numero_seccion INTEGER;
    v_tiene_nivel_10_anterior BOOLEAN;
    v_detalle JSONB;
BEGIN
    PERFORM pg_advisory_xact_lock(NEW.id_estudiante);

    SELECT s.id_curso_lectivo, s.nivel, s.numero_seccion, c.year_ciclo
    INTO v_id_curso_lectivo, v_nivel, v_numero_seccion, v_year_ciclo
    FROM academico.secciones s
    JOIN academico.cursos_lectivos c ON c.id_curso_lectivo = s.id_curso_lectivo
    WHERE s.id_seccion = NEW.id_seccion;

    SELECT jsonb_build_object(
        'id_matricula', m.id_matricula,
        'id_seccion', m.id_seccion,
        'id_curso_lectivo', s.id_curso_lectivo,
        'year_ciclo', c.year_ciclo,
        'estado', m.estado
    )
    INTO v_detalle
    FROM academico.matriculas_secciones m
    JOIN academico.secciones s ON s.id_seccion = m.id_seccion
    JOIN academico.cursos_lectivos c ON c.id_curso_lectivo = s.id_curso_lectivo
    WHERE m.id_estudiante = NEW.id_estudiante
        AND s.id_curso_lectivo = v_id_curso_lectivo
        AND m.id_matricula IS DISTINCT FROM NEW.id_matricula
    LIMIT 1;

    -- ✅
    IF FOUND THEN
        PERFORM academico.fn_lanzar_excepcion(
            'El estudiante ya tiene una matrícula en este curso lectivo.',
            jsonb_build_object(
                'id_matricula_nueva', NEW.id_matricula,
                'id_curso_lectivo', v_id_curso_lectivo,
                'matricula_existente', v_detalle
            ),
            'No puede tener dos matrículas en el mismo curso lectivo.',
            'CL001'
        );
    END IF;

    SELECT jsonb_build_object(
        'id_matricula', m.id_matricula,
        'id_seccion', m.id_seccion,
        'nivel', s.nivel,
        'year_ciclo', c.year_ciclo,
        'estado', m.estado
    )
    INTO v_detalle
    FROM academico.matriculas_secciones m
    JOIN academico.secciones s ON s.id_seccion = m.id_seccion
    JOIN academico.cursos_lectivos c ON c.id_curso_lectivo = s.id_curso_lectivo
    WHERE m.id_estudiante = NEW.id_estudiante
        AND s.nivel = v_nivel
        AND m.id_matricula IS DISTINCT FROM NEW.id_matricula
    LIMIT 1;

    -- ✅
    IF FOUND THEN
        PERFORM academico.fn_lanzar_excepcion(
            'El estudiante ya tiene una matrícula del mismo nivel en otro curso lectivo.',
            jsonb_build_object('matricula_mismo_nivel', v_detalle),
            'No puede repetir el mismo nivel en otro curso lectivo.',
            'CL002'
        );
    END IF;

    IF v_nivel = 10 THEN
        SELECT jsonb_build_object(
            'id_matricula', m.id_matricula,
            'id_seccion', m.id_seccion,
            'nivel', s.nivel,
            'numero_seccion', s.numero_seccion,
            'year_ciclo', c.year_ciclo,
            'estado', m.estado
        )
        INTO v_detalle
        FROM academico.matriculas_secciones m
        JOIN academico.secciones s ON s.id_seccion = m.id_seccion
        JOIN academico.cursos_lectivos c ON c.id_curso_lectivo = s.id_curso_lectivo
        WHERE m.id_estudiante = NEW.id_estudiante
            AND s.nivel = 11
            AND (c.year_ciclo <> v_year_ciclo + 1 OR s.numero_seccion <> v_numero_seccion)
            AND m.id_matricula IS DISTINCT FROM NEW.id_matricula
        LIMIT 1;
        
        -- ✅ se puede separar year y numero_seccion
        IF FOUND THEN
            PERFORM academico.fn_lanzar_excepcion(
                'Los años de nivel 10 y nivel 11 deben ser consecutivos y conservar el número de sección.',
                jsonb_build_object('existente matricula_nivel_11', v_detalle,
                    'new matricula_nivel_10', jsonb_build_object(
                        'id_matricula', NEW.id_matricula,
                        'id_seccion', NEW.id_seccion,
                        'nivel', v_nivel,
                        'numero_seccion', v_numero_seccion,
                        'year_ciclo', v_year_ciclo,
                        'estado', NEW.estado
                    )
                ),
                'El nivel 11 debe pertenecer al año posterior al nivel 10 y conservar el mismo número de sección.',
                'CL003'
            );
        END IF;
    END IF;

    IF v_nivel = 11 THEN
        SELECT EXISTS (
            SELECT 1
            FROM academico.matriculas_secciones m
            JOIN academico.secciones s ON s.id_seccion = m.id_seccion
            JOIN academico.cursos_lectivos c ON c.id_curso_lectivo = s.id_curso_lectivo
            WHERE m.id_estudiante = NEW.id_estudiante
                AND s.nivel = 10
                AND s.numero_seccion = v_numero_seccion
                AND m.estado = 'FINALIZADA'
                AND c.year_ciclo = v_year_ciclo - 1
        )
        INTO v_tiene_nivel_10_anterior;

        -- ✅ se puede separar year y numero_seccion
        IF NOT v_tiene_nivel_10_anterior THEN
            PERFORM academico.fn_lanzar_excepcion(
                'El estudiante no puede matricularse en nivel 11 sin haber finalizado nivel 10 en el año anterior con el mismo número de sección.',
                jsonb_build_object(
                    'id_seccion', NEW.id_seccion,
                    'nivel_requerido', 10,
                    'year_ciclo_requerido', v_year_ciclo - 1,
                    'numero_seccion_requerido', v_numero_seccion
                ),
                'Primero debe existir una matrícula de nivel 10 finalizada en el año anterior con el mismo número de sección.',
                'CL004'
            );
        END IF;
    END IF;

    IF NEW.estado = 'ACTIVA' THEN
        SELECT jsonb_build_object(
            'id_matricula', m.id_matricula,
            'id_seccion', m.id_seccion,
            'year_ciclo', c.year_ciclo,
            'estado', m.estado
        )
        INTO v_detalle
        FROM academico.matriculas_secciones m
        JOIN academico.secciones s ON s.id_seccion = m.id_seccion
        JOIN academico.cursos_lectivos c ON c.id_curso_lectivo = s.id_curso_lectivo
        WHERE m.id_estudiante = NEW.id_estudiante
            AND m.estado = 'ACTIVA'
            AND m.id_matricula IS DISTINCT FROM NEW.id_matricula
        LIMIT 1;
        
        -- ✅
        IF FOUND THEN
            PERFORM academico.fn_lanzar_excepcion(
                'El estudiante ya tiene una matrícula ACTIVA.',
                jsonb_build_object(
                    'id_matricula_nueva', NEW.id_matricula,
                    'matricula_activa_existente', v_detalle
                ),
                'Un estudiante solo puede tener una matrícula ACTIVA a la vez.',
                'CL005'
            );
        END IF;

        SELECT curso_actual.id_curso_lectivo, curso_actual.year_ciclo
        INTO v_id_curso_lectivo_actual, v_year_ciclo_actual
        FROM academico.fn_obtener_curso_lectivo_actual() curso_actual;

        -- ✅
        IF v_id_curso_lectivo <> v_id_curso_lectivo_actual THEN
            PERFORM academico.fn_lanzar_excepcion(
                'Una matrícula ACTIVA debe pertenecer al curso lectivo actual.',
                jsonb_build_object(
                    'id_curso_lectivo', v_id_curso_lectivo,
                    'year_ciclo', v_year_ciclo,
                    'id_curso_lectivo_actual', v_id_curso_lectivo_actual,
                    'year_ciclo_actual', v_year_ciclo_actual
                ),
                'Cambie el curso lectivo o registre la matrícula con otro estado.',
                'CL006'
            );
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validar_matricula ON academico.matriculas_secciones;
CREATE TRIGGER trg_validar_matricula
BEFORE INSERT OR UPDATE ON academico.matriculas_secciones
FOR EACH ROW
EXECUTE FUNCTION academico.fn_matriculas_validas();

CREATE OR REPLACE FUNCTION academico.fn_matriculas_borrado_valido()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_detalle JSONB;
    v_detalle_matricula_nivel_11 JSONB;
    v_id_matricula_nivel_11 BIGINT;
BEGIN

    SELECT jsonb_build_object(
        'id_matricula', OLD.id_matricula,
        'id_seccion', OLD.id_seccion,
        'seccion', s.nivel || '-' || s.numero_seccion,
        'nivel', s.nivel,
        'id_curso_lectivo', s.id_curso_lectivo,
        'year_ciclo', c.year_ciclo,
        'estado', OLD.estado
    )
    INTO v_detalle
    FROM academico.secciones s
    JOIN academico.cursos_lectivos c ON c.id_curso_lectivo = s.id_curso_lectivo
    WHERE s.id_seccion = OLD.id_seccion;

    IF OLD.estado = 'FINALIZADA' OR OLD.estado = 'ACTIVA' THEN
        PERFORM academico.fn_lanzar_excepcion(
            'No se puede borrar una matrícula que esté en estado FINALIZADA o ACTIVA.',
            v_detalle,
            NULL,
            'MA012'
        );
    END IF;

    SELECT m.id_matricula
    INTO v_id_matricula_nivel_11
    FROM academico.matriculas_secciones m
    JOIN academico.secciones s ON s.id_seccion = m.id_seccion
    WHERE m.id_estudiante = OLD.id_estudiante
        AND s.nivel = 11
    LIMIT 1;

    IF v_detalle->>'nivel' = '10' AND v_id_matricula_nivel_11 IS NOT NULL
    THEN
        SELECT jsonb_build_object(
            'id_matricula', m.id_matricula,
            'id_seccion', m.id_seccion,
            'seccion', s.nivel || '-' || s.numero_seccion,
            'id_curso_lectivo', s.id_curso_lectivo,
            'year_ciclo', c.year_ciclo,
            'estado', m.estado
        )
        INTO v_detalle_matricula_nivel_11
        FROM academico.matriculas_secciones m
        JOIN academico.secciones s ON s.id_seccion = m.id_seccion
        JOIN academico.cursos_lectivos c ON c.id_curso_lectivo = s.id_curso_lectivo
        WHERE m.id_matricula = v_id_matricula_nivel_11;

        PERFORM academico.fn_lanzar_excepcion(
            'No se puede borrar una matrícula de nivel 10 si el estudiante ya tiene una matrícula de nivel 11 asociada.',
            jsonb_build_object(
                'matricula_nivel_10', v_detalle,
                'matricula_nivel_11', v_detalle_matricula_nivel_11
            ),
            NULL,
            'MA014'
        );
    END IF;

    RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS trg_validar_borrado_matricula ON academico.matriculas_secciones;
CREATE TRIGGER trg_validar_borrado_matricula
BEFORE DELETE ON academico.matriculas_secciones
FOR EACH ROW
EXECUTE FUNCTION academico.fn_matriculas_borrado_valido();