----------------------------------------------------------------------------
-- PROFESORES
----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE api.registrar_profesor(
	p_nombre VARCHAR(100),
	p_primer_apellido VARCHAR(100),
	p_segundo_apellido VARCHAR(100),
	p_cedula VARCHAR(20),
	p_numero_celular VARCHAR(20),
	p_email TEXT,
	p_fecha_nacimiento DATE,
    p_password_hash VARCHAR(255),
    OUT p_id_profesor BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, academico, api
AS $$
BEGIN
    IF NOT (
        pg_has_role(session_user::text, 'bi_api', 'member')
        OR pg_has_role(session_user::text, 'bi_admin', 'member')
    ) THEN
        RAISE EXCEPTION 'No tiene permisos para registrar un profesor'
            USING ERRCODE = '42501';
    END IF;

    CALL academico.registrar_profesor(
        p_nombre,
        p_primer_apellido,
        p_segundo_apellido,
        p_cedula,
        p_numero_celular,
        p_email,
        p_fecha_nacimiento,
        p_password_hash,
        p_id_profesor
    );
END;
$$;

CREATE OR REPLACE FUNCTION api.obtener_profesor(
    p_cedula VARCHAR(20)
)
RETURNS SETOF academico.profesor_publico
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, academico, api
AS $$
BEGIN
    IF NOT (
        pg_has_role(session_user::text, 'bi_api', 'member')
        OR pg_has_role(session_user::text, 'bi_admin', 'member')
    ) THEN
        RAISE EXCEPTION 'No tiene permisos para consultar un profesor'
            USING ERRCODE = '42501';
    END IF;

    RETURN QUERY
    SELECT *
    FROM academico.obtener_profesor(p_cedula);
END;
$$;

CREATE OR REPLACE FUNCTION api.obtener_profesores()
RETURNS SETOF academico.profesor_publico
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, academico, api
AS $$
BEGIN
    IF NOT (
        pg_has_role(session_user::text, 'bi_api', 'member')
        OR pg_has_role(session_user::text, 'bi_admin', 'member')
    ) THEN
        RAISE EXCEPTION 'No tiene permisos para consultar profesores'
            USING ERRCODE = '42501';
    END IF;

    RETURN QUERY
    SELECT *
    FROM academico.obtener_profesores();
END;
$$;

CREATE OR REPLACE PROCEDURE api.actualizar_profesor(
	p_cedula_actual VARCHAR(20),
	p_nombre VARCHAR(100),
	p_primer_apellido VARCHAR(100),
	p_segundo_apellido VARCHAR(100),
	p_cedula VARCHAR(20),
	p_numero_celular VARCHAR(20),
	p_email TEXT,
	p_fecha_nacimiento DATE,
	p_password_hash VARCHAR(255),
	OUT p_id_profesor BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, academico, api
AS $$
BEGIN
    IF NOT (
        pg_has_role(session_user::text, 'bi_api', 'member')
        OR pg_has_role(session_user::text, 'bi_admin', 'member')
    ) THEN
        RAISE EXCEPTION 'No tiene permisos para actualizar un profesor'
            USING ERRCODE = '42501';
    END IF;

    CALL academico.actualizar_profesor(
        p_cedula_actual,
        p_nombre,
        p_primer_apellido,
        p_segundo_apellido,
        p_cedula,
        p_numero_celular,
        p_email,
        p_fecha_nacimiento,
        p_password_hash,
        p_id_profesor
    );
END;
$$;

CREATE OR REPLACE PROCEDURE api.desactivar_profesor(
	p_cedula VARCHAR(20),
	OUT p_id_profesor BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, academico, api
AS $$
BEGIN
    IF NOT (
        pg_has_role(session_user::text, 'bi_api', 'member')
        OR pg_has_role(session_user::text, 'bi_admin', 'member')
    ) THEN
        RAISE EXCEPTION 'No tiene permisos para desactivar un profesor'
            USING ERRCODE = '42501';
    END IF;

    CALL academico.desactivar_profesor(p_cedula, p_id_profesor);
END;
$$;

CREATE OR REPLACE PROCEDURE api.activar_profesor(
	p_cedula VARCHAR(20),
	OUT p_id_profesor BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, academico, api
AS $$
BEGIN
    IF NOT (
        pg_has_role(session_user::text, 'bi_api', 'member')
        OR pg_has_role(session_user::text, 'bi_admin', 'member')
    ) THEN
        RAISE EXCEPTION 'No tiene permisos para activar un profesor'
            USING ERRCODE = '42501';
    END IF;

    CALL academico.activar_profesor(p_cedula, p_id_profesor);
END;
$$;

CREATE OR REPLACE PROCEDURE api.borrar_profesor(
	p_cedula VARCHAR(20),
	OUT p_id_profesor BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, academico, api
AS $$
BEGIN
    IF NOT (
        pg_has_role(session_user::text, 'bi_api', 'member')
        OR pg_has_role(session_user::text, 'bi_admin', 'member')
    ) THEN
        RAISE EXCEPTION 'No tiene permisos para borrar un profesor'
            USING ERRCODE = '42501';
    END IF;

    CALL academico.borrar_profesor(p_cedula, p_id_profesor);
END;
$$;

----------------------------------------------------------------------------
-- ESTUDIANTES
----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE api.registrar_estudiante(
	p_nombre VARCHAR(100),
	p_primer_apellido VARCHAR(100),
	p_segundo_apellido VARCHAR(100),
	p_cedula VARCHAR(20),
	p_numero_celular VARCHAR(20),
	p_email TEXT,
	p_fecha_nacimiento DATE,
	OUT p_id_estudiante BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, academico, api
AS $$
BEGIN
    IF NOT (
        pg_has_role(session_user::text, 'bi_api', 'member')
        OR pg_has_role(session_user::text, 'bi_admin', 'member')
    ) THEN
        RAISE EXCEPTION 'No tiene permisos para registrar un estudiante'
            USING ERRCODE = '42501';
    END IF;

    CALL academico.registrar_estudiante(
        p_nombre, p_primer_apellido, p_segundo_apellido, p_cedula,
        p_numero_celular, p_email, p_fecha_nacimiento, p_id_estudiante
    );
END;
$$;

CREATE OR REPLACE FUNCTION api.obtener_estudiante(
	p_cedula VARCHAR(20)
)
RETURNS SETOF academico.estudiante_publico
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, academico, api
AS $$
BEGIN
    IF NOT (
        pg_has_role(session_user::text, 'bi_api', 'member')
        OR pg_has_role(session_user::text, 'bi_admin', 'member')
    ) THEN
        RAISE EXCEPTION 'No tiene permisos para consultar un estudiante'
            USING ERRCODE = '42501';
    END IF;

    RETURN QUERY SELECT * FROM academico.obtener_estudiante(p_cedula);
END;
$$;

CREATE OR REPLACE FUNCTION api.obtener_estudiantes()
RETURNS SETOF academico.estudiante_publico
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, academico, api
AS $$
BEGIN
    IF NOT (
        pg_has_role(session_user::text, 'bi_api', 'member')
        OR pg_has_role(session_user::text, 'bi_admin', 'member')
    ) THEN
        RAISE EXCEPTION 'No tiene permisos para consultar estudiantes'
            USING ERRCODE = '42501';
    END IF;

    RETURN QUERY SELECT * FROM academico.obtener_estudiantes();
END;
$$;

CREATE OR REPLACE PROCEDURE api.actualizar_estudiante(
	p_cedula_actual VARCHAR(20),
	p_nombre VARCHAR(100),
	p_primer_apellido VARCHAR(100),
	p_segundo_apellido VARCHAR(100),
	p_cedula VARCHAR(20),
	p_numero_celular VARCHAR(20),
	p_email TEXT,
	p_fecha_nacimiento DATE,
	OUT p_id_estudiante BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, academico, api
AS $$
BEGIN
    IF NOT (
        pg_has_role(session_user::text, 'bi_api', 'member')
        OR pg_has_role(session_user::text, 'bi_admin', 'member')
    ) THEN
        RAISE EXCEPTION 'No tiene permisos para actualizar un estudiante'
            USING ERRCODE = '42501';
    END IF;

    CALL academico.actualizar_estudiante(
        p_cedula_actual, p_nombre, p_primer_apellido, p_segundo_apellido,
        p_cedula, p_numero_celular, p_email, p_fecha_nacimiento,
        p_id_estudiante
    );
END;
$$;

CREATE OR REPLACE PROCEDURE api.borrar_estudiante(
	p_cedula VARCHAR(20),
	OUT p_id_estudiante BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, academico, api
AS $$
BEGIN
    IF NOT (
        pg_has_role(session_user::text, 'bi_api', 'member')
        OR pg_has_role(session_user::text, 'bi_admin', 'member')
    ) THEN
        RAISE EXCEPTION 'No tiene permisos para borrar un estudiante'
            USING ERRCODE = '42501';
    END IF;

    CALL academico.borrar_estudiante(p_cedula, p_id_estudiante);
END;
$$;

----------------------------------------------------------------------------
-- CURSOS_LECTIVOS
----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE api.abrir_curso_lectivo(
	p_year_ciclo INTEGER,
	p_fecha_inicio_i DATE,
	p_fecha_fin_i DATE,
	p_fecha_inicio_ii DATE,
	p_fecha_fin_ii DATE,
	OUT p_id_curso_lectivo BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, academico, api
AS $$
BEGIN
    IF NOT (
        pg_has_role(session_user::text, 'bi_api', 'member')
        OR pg_has_role(session_user::text, 'bi_admin', 'member')
    ) THEN
        RAISE EXCEPTION 'No tiene permisos para abrir un curso lectivo'
            USING ERRCODE = '42501';
    END IF;

    CALL academico.abrir_curso_lectivo(
        p_year_ciclo,
        p_fecha_inicio_i,
        p_fecha_fin_i,
        p_fecha_inicio_ii,
        p_fecha_fin_ii,
        p_id_curso_lectivo
    );
END;
$$;

CREATE OR REPLACE FUNCTION api.obtener_curso_lectivo(
	p_year_ciclo INTEGER
)
RETURNS SETOF academico.curso_lectivo_publico
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, academico, api
AS $$
BEGIN
    IF NOT (
        pg_has_role(session_user::text, 'bi_api', 'member')
        OR pg_has_role(session_user::text, 'bi_admin', 'member')
    ) THEN
        RAISE EXCEPTION 'No tiene permisos para consultar un curso lectivo'
            USING ERRCODE = '42501';
    END IF;

    RETURN QUERY SELECT * FROM academico.obtener_curso_lectivo(p_year_ciclo);
END;
$$;

CREATE OR REPLACE FUNCTION api.obtener_cursos_lectivos()
RETURNS SETOF academico.curso_lectivo_publico
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, academico, api
AS $$
BEGIN
    IF NOT (
        pg_has_role(session_user::text, 'bi_api', 'member')
        OR pg_has_role(session_user::text, 'bi_admin', 'member')
    ) THEN
        RAISE EXCEPTION 'No tiene permisos para consultar cursos lectivos'
            USING ERRCODE = '42501';
    END IF;

    RETURN QUERY SELECT * FROM academico.obtener_cursos_lectivos();
END;
$$;

CREATE OR REPLACE PROCEDURE api.actualizar_curso_lectivo(
	p_year_ciclo INTEGER,
	p_fecha_inicio_i DATE,
	p_fecha_fin_i DATE,
	p_fecha_inicio_ii DATE,
	p_fecha_fin_ii DATE,
	OUT p_id_curso_lectivo BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, academico, api
AS $$
BEGIN
    IF NOT (
        pg_has_role(session_user::text, 'bi_api', 'member')
        OR pg_has_role(session_user::text, 'bi_admin', 'member')
    ) THEN
        RAISE EXCEPTION 'No tiene permisos para actualizar un curso lectivo'
            USING ERRCODE = '42501';
    END IF;

    CALL academico.actualizar_curso_lectivo(
        p_year_ciclo,
        p_fecha_inicio_i,
        p_fecha_fin_i,
        p_fecha_inicio_ii,
        p_fecha_fin_ii,
        p_id_curso_lectivo
    );
END;
$$;

CREATE OR REPLACE PROCEDURE api.borrar_curso_lectivo(
	p_year_ciclo INTEGER,
	OUT p_id_curso_lectivo BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, academico, api
AS $$
BEGIN
    IF NOT (
        pg_has_role(session_user::text, 'bi_api', 'member')
        OR pg_has_role(session_user::text, 'bi_admin', 'member')
    ) THEN
        RAISE EXCEPTION 'No tiene permisos para borrar un curso lectivo'
            USING ERRCODE = '42501';
    END IF;

    CALL academico.borrar_curso_lectivo(p_year_ciclo, p_id_curso_lectivo);
END;
$$;

----------------------------------------------------------------------------
-- SECCIONES
----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE api.registrar_seccion(
    p_year_ciclo INTEGER,
    p_nivel INTEGER,
    p_numero_seccion INTEGER,
    OUT p_id_seccion BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, academico, api
AS $$
BEGIN
    IF NOT (
        pg_has_role(session_user::text, 'bi_api', 'member')
        OR pg_has_role(session_user::text, 'bi_admin', 'member')
    ) THEN
        RAISE EXCEPTION 'No tiene permisos para registrar una sección'
            USING ERRCODE = '42501';
    END IF;

    CALL academico.registrar_seccion(
        p_year_ciclo,
        p_nivel,
        p_numero_seccion,
        p_id_seccion
    );
END;
$$;

CREATE OR REPLACE FUNCTION api.obtener_secciones()
RETURNS SETOF academico.seccion_publica
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, academico, api
AS $$
BEGIN
    IF NOT (
        pg_has_role(session_user::text, 'bi_api', 'member')
        OR pg_has_role(session_user::text, 'bi_admin', 'member')
    ) THEN
        RAISE EXCEPTION 'No tiene permisos para consultar secciones'
            USING ERRCODE = '42501';
    END IF;

    RETURN QUERY
    SELECT *
    FROM academico.obtener_secciones();
END;
$$;

CREATE OR REPLACE PROCEDURE api.borrar_seccion(
    p_year_ciclo INTEGER,
    p_nivel INTEGER,
    p_numero_seccion INTEGER,
    OUT p_id_seccion BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, academico, api
AS $$
BEGIN
    IF NOT (
        pg_has_role(session_user::text, 'bi_api', 'member')
        OR pg_has_role(session_user::text, 'bi_admin', 'member')
    ) THEN
        RAISE EXCEPTION 'No tiene permisos para borrar una sección'
            USING ERRCODE = '42501';
    END IF;

    CALL academico.borrar_seccion(
        p_year_ciclo,
        p_nivel,
        p_numero_seccion,
        p_id_seccion
    );
END;
$$;

----------------------------------------------------------------------------
-- MATRICULAS_SECCIONES
----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE api.matricular_estudiante_en_nivel_10(
    p_cedula_estudiante VARCHAR(20),
    p_year_ciclo INTEGER,
    p_numero_seccion INTEGER,
    OUT p_id_matricula BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, academico, api
AS $$
BEGIN
    IF NOT (
        pg_has_role(session_user::text, 'bi_api', 'member')
        OR pg_has_role(session_user::text, 'bi_admin', 'member')
    ) THEN
        RAISE EXCEPTION 'No tiene permisos para matricular a un estudiante en una sección'
            USING ERRCODE = '42501';
    END IF;

    CALL academico.registrar_matricula(
        p_cedula_estudiante,
        p_year_ciclo,
        10,
        p_numero_seccion,
        p_id_matricula
    );
END;
$$;

CREATE OR REPLACE PROCEDURE api.finalizar_matricula(
    p_id_matricula BIGINT,
    OUT p_id_matricula_finalizada BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, academico, api
AS $$
BEGIN
    IF NOT (
        pg_has_role(session_user::text, 'bi_api', 'member')
        OR pg_has_role(session_user::text, 'bi_admin', 'member')
    ) THEN
        RAISE EXCEPTION 'No tiene permisos para finalizar una matrícula'
            USING ERRCODE = '42501';
    END IF;

    CALL academico.finalizar_matricula(
        p_id_matricula,
        p_id_matricula_finalizada
    );
END;
$$;

CREATE OR REPLACE PROCEDURE api.matricular_estudiante_en_nivel_11(
    p_cedula_estudiante VARCHAR(20),
    OUT p_id_matricula BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, academico, api
AS $$
BEGIN
    IF NOT (
        pg_has_role(session_user::text, 'bi_api', 'member')
        OR pg_has_role(session_user::text, 'bi_admin', 'member')
    ) THEN
        RAISE EXCEPTION 'No tiene permisos para matricular a un estudiante en una sección'
            USING ERRCODE = '42501';
    END IF;

    CALL academico.subir_a_nivel_11(
        p_cedula_estudiante,
        p_id_matricula
    );
END;
$$;

CREATE OR REPLACE FUNCTION api.obtener_matriculas_estudiante(
    p_cedula_estudiante VARCHAR(20)
)
RETURNS SETOF academico.matricula_estudiante_publica
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, academico, api
AS $$
BEGIN
    IF NOT (
        pg_has_role(session_user::text, 'bi_api', 'member')
        OR pg_has_role(session_user::text, 'bi_admin', 'member')
    ) THEN
        RAISE EXCEPTION 'No tiene permisos para obtener las matrículas de un estudiante'
            USING ERRCODE = '42501';
    END IF;

    RETURN QUERY
    SELECT *
    FROM academico.obtener_matriculas_estudiante(p_cedula_estudiante);
END;
$$;

CREATE OR REPLACE PROCEDURE api.borrar_matricula(
    p_id_matricula BIGINT,
    OUT p_id_matricula_borrada BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, academico, api
AS $$
BEGIN
    IF NOT (
        pg_has_role(session_user::text, 'bi_api', 'member')
        OR pg_has_role(session_user::text, 'bi_admin', 'member')
    ) THEN
        RAISE EXCEPTION 'No tiene permisos para borrar una matrícula'
            USING ERRCODE = '42501';
    END IF;

    CALL academico.borrar_matricula(
        p_id_matricula,
        p_id_matricula_borrada
    );
END;
$$;

----------------------------------------------------------------------------
-- RESTRICCIONES DE ACCESO
----------------------------------------------------------------------------

-- PROFESORES
REVOKE ALL ON PROCEDURE api.registrar_profesor(
    VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, TEXT, DATE, VARCHAR
) FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE api.registrar_profesor(
    VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, TEXT, DATE, VARCHAR
) TO bi_api, bi_admin;

REVOKE ALL ON FUNCTION api.obtener_profesor(VARCHAR) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.obtener_profesor(VARCHAR) TO bi_api, bi_admin;

REVOKE ALL ON FUNCTION api.obtener_profesores() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.obtener_profesores() TO bi_api, bi_admin;

REVOKE ALL ON PROCEDURE api.actualizar_profesor(
    VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, TEXT, DATE, VARCHAR
) FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE api.actualizar_profesor(
    VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, TEXT, DATE, VARCHAR
) TO bi_api, bi_admin;

REVOKE ALL ON PROCEDURE api.desactivar_profesor(VARCHAR) FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE api.desactivar_profesor(VARCHAR) TO bi_api, bi_admin;

REVOKE ALL ON PROCEDURE api.activar_profesor(VARCHAR) FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE api.activar_profesor(VARCHAR) TO bi_api, bi_admin;

REVOKE ALL ON PROCEDURE api.borrar_profesor(VARCHAR) FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE api.borrar_profesor(VARCHAR) TO bi_api, bi_admin;

-- ESTUDIANTES
REVOKE ALL ON PROCEDURE api.registrar_estudiante(
    VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, TEXT, DATE
) FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE api.registrar_estudiante(
    VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, TEXT, DATE
) TO bi_api, bi_admin;

REVOKE ALL ON FUNCTION api.obtener_estudiante(VARCHAR) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.obtener_estudiante(VARCHAR) TO bi_api, bi_admin;

REVOKE ALL ON FUNCTION api.obtener_estudiantes() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.obtener_estudiantes() TO bi_api, bi_admin;

REVOKE ALL ON PROCEDURE api.actualizar_estudiante(
    VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, TEXT, DATE
) FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE api.actualizar_estudiante(
    VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, TEXT, DATE
) TO bi_api, bi_admin;

REVOKE ALL ON PROCEDURE api.borrar_estudiante(VARCHAR) FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE api.borrar_estudiante(VARCHAR) TO bi_api, bi_admin;

-- CURSOS LECTIVOS
REVOKE ALL ON PROCEDURE api.abrir_curso_lectivo(
    INTEGER, DATE, DATE, DATE, DATE
) FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE api.abrir_curso_lectivo(
    INTEGER, DATE, DATE, DATE, DATE
) TO bi_api, bi_admin;

REVOKE ALL ON FUNCTION api.obtener_curso_lectivo(INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.obtener_curso_lectivo(INTEGER) TO bi_api, bi_admin;

REVOKE ALL ON FUNCTION api.obtener_cursos_lectivos() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.obtener_cursos_lectivos() TO bi_api, bi_admin;

REVOKE ALL ON PROCEDURE api.borrar_curso_lectivo(INTEGER) FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE api.borrar_curso_lectivo(INTEGER) TO bi_api, bi_admin;

-- SECCIONES
REVOKE ALL ON PROCEDURE api.registrar_seccion(
    INTEGER, INTEGER, INTEGER
) FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE api.registrar_seccion(
    INTEGER, INTEGER, INTEGER
) TO bi_api, bi_admin;

REVOKE ALL ON FUNCTION api.obtener_secciones() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.obtener_secciones() TO bi_api, bi_admin;

REVOKE ALL ON PROCEDURE api.borrar_seccion(
    INTEGER, INTEGER, INTEGER
) FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE api.borrar_seccion(
    INTEGER, INTEGER, INTEGER
) TO bi_api, bi_admin;

-- MATRICULAS_SECCIONES
REVOKE ALL ON PROCEDURE api.matricular_estudiante_en_nivel_10(
    VARCHAR, INTEGER, INTEGER
) FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE api.matricular_estudiante_en_nivel_10(
    VARCHAR, INTEGER, INTEGER
) TO bi_api, bi_admin;
REVOKE ALL ON PROCEDURE api.matricular_estudiante_en_nivel_11(
    VARCHAR
) FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE api.matricular_estudiante_en_nivel_11(
    VARCHAR
) TO bi_api, bi_admin;
REVOKE ALL ON PROCEDURE api.finalizar_matricula(
    BIGINT
) FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE api.finalizar_matricula(
    BIGINT
) TO bi_api, bi_admin;
REVOKE ALL ON FUNCTION api.obtener_matriculas_estudiante(
    VARCHAR
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.obtener_matriculas_estudiante(
    VARCHAR
) TO bi_api, bi_admin;
REVOKE ALL ON PROCEDURE api.borrar_matricula(
    BIGINT
) FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE api.borrar_matricula(
    BIGINT
) TO bi_api, bi_admin;