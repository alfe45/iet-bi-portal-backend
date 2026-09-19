----------------------------------------------------------------------------
-- PROFESORES
----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE academico.registrar_profesor(
	IN p_nombre VARCHAR(100),
	IN p_primer_apellido VARCHAR(100),
	IN p_segundo_apellido VARCHAR(100),
	IN p_cedula VARCHAR(20),
	IN p_numero_celular VARCHAR(20),
	IN p_email TEXT,
	IN p_fecha_nacimiento DATE,
	IN p_password_hash VARCHAR(255),
	OUT p_id_profesor BIGINT
)
LANGUAGE plpgsql
AS $$
BEGIN
	-- ✅
	IF NULLIF(trim(p_nombre), '') IS NULL
		OR NULLIF(trim(p_primer_apellido), '') IS NULL
		OR NULLIF(trim(p_cedula), '') IS NULL
		OR p_email IS NULL
		OR NULLIF(trim(p_email::TEXT), '') IS NULL
		OR p_fecha_nacimiento IS NULL
		OR NULLIF(trim(p_password_hash), '') IS NULL THEN
		PERFORM academico.fn_lanzar_excepcion(
			'El nombre, el primer apellido, la cédula, el correo, la fecha de nacimiento y la contraseña son obligatorios.',
			jsonb_build_object(
				'nombre', p_nombre,
				'primer_apellido', p_primer_apellido,
				'cedula', p_cedula,
				'email', p_email,
				'fecha_nacimiento', p_fecha_nacimiento,
				'password_hash', NULLIF(trim(p_password_hash), '')
			),
			'Complete todos los datos requeridos del profesor.',
			'PR001'
		);
	END IF;

	-- ✅
	IF length(trim(p_nombre)) < 2
		OR length(trim(p_primer_apellido)) < 2 THEN
		PERFORM academico.fn_lanzar_excepcion(
			'El nombre y el primer apellido deben tener al menos 2 caracteres.',
			jsonb_build_object(
				'nombre', p_nombre,
				'primer_apellido', p_primer_apellido
			),
			NULL,
			'PR002'
		);
	END IF;

	-- ✅
	IF length(trim(p_cedula)) < 5 THEN
		PERFORM academico.fn_lanzar_excepcion(
			'La cédula debe tener al menos 5 caracteres.',
			jsonb_build_object('cedula', p_cedula),
			NULL,
			'PR003'
		);
	END IF;

	-- ✅
	IF p_email::TEXT !~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' THEN
		PERFORM academico.fn_lanzar_excepcion(
			'El correo electrónico no tiene un formato válido.',
			jsonb_build_object('email', p_email),
			NULL,
			'PR004'
		);
	END IF;

	-- ✅
	IF p_fecha_nacimiento < DATE '1900-01-01'
		OR p_fecha_nacimiento > CURRENT_DATE THEN
		PERFORM academico.fn_lanzar_excepcion(
			'La fecha de nacimiento debe estar entre el 01/01/1900 y la fecha actual.',
			jsonb_build_object('fecha_nacimiento', p_fecha_nacimiento),
			NULL,
			'PR005'
		);
	END IF;

	-- ✅
	IF EXISTS (
		SELECT 1
		FROM academico.profesores
		WHERE cedula = trim(p_cedula)
	) THEN
		PERFORM academico.fn_lanzar_excepcion(
			'Ya existe un profesor con esa cédula.',
			jsonb_build_object('cedula', p_cedula),
			NULL,
			'PR006'
		);
	END IF;

	-- ✅
	IF EXISTS (
		SELECT 1
		FROM academico.profesores
		WHERE lower(trim(email::TEXT)) = lower(trim(p_email))
	) THEN
		PERFORM academico.fn_lanzar_excepcion(
			'Ya existe un profesor con ese correo electrónico.',
			jsonb_build_object('email', p_email),
			NULL,
			'PR007'
		);
	END IF;

	INSERT INTO academico.profesores (
		nombre,
		primer_apellido,
		segundo_apellido,
		cedula,
		numero_celular,
		email,
		fecha_nacimiento,
		password_hash
	)
	VALUES (
		NULLIF(trim(p_nombre), ''),
		NULLIF(trim(p_primer_apellido), ''),
		NULLIF(trim(p_segundo_apellido), ''),
		NULLIF(trim(p_cedula), ''),
		NULLIF(trim(p_numero_celular), ''),
		NULLIF(trim(p_email), ''),
		p_fecha_nacimiento,
		NULLIF(trim(p_password_hash), '')
	)
	RETURNING id_profesor INTO p_id_profesor;
END;
$$;

CREATE OR REPLACE FUNCTION academico.obtener_profesor(
	p_cedula VARCHAR(20)
)
RETURNS SETOF academico.profesor_publico
LANGUAGE plpgsql
AS $$
BEGIN
	RETURN QUERY
	SELECT p.id_profesor,
		p.nombre,
		p.primer_apellido,
		p.segundo_apellido,
		p.cedula,
		p.numero_celular,
		p.email::TEXT,
		p.fecha_nacimiento,
		p.fecha_registro,
		p.activo
	FROM academico.profesores p
	WHERE p.cedula = trim(p_cedula);

	-- ✅
	IF NOT FOUND THEN
		PERFORM academico.fn_lanzar_excepcion(
			'No existe un profesor con la cédula indicada.',
			jsonb_build_object('cedula', p_cedula),
			'Verifique la cédula del profesor.',
			'PR008'
		);
	END IF;
END;
$$;

CREATE OR REPLACE FUNCTION academico.obtener_profesores()
RETURNS SETOF academico.profesor_publico
LANGUAGE plpgsql
AS $$
BEGIN
	RETURN QUERY
	SELECT p.id_profesor,
		p.nombre,
		p.primer_apellido,
		p.segundo_apellido,
		p.cedula,
		p.numero_celular,
		p.email::TEXT,
		p.fecha_nacimiento,
		p.fecha_registro,
		p.activo
	FROM academico.profesores p
	ORDER BY p.id_profesor;
END;
$$;

CREATE OR REPLACE PROCEDURE academico.actualizar_profesor(
	IN p_cedula_actual VARCHAR(20),
	IN p_nombre VARCHAR(100),
	IN p_primer_apellido VARCHAR(100),
	IN p_segundo_apellido VARCHAR(100),
	IN p_cedula VARCHAR(20),
	IN p_numero_celular VARCHAR(20),
	IN p_email TEXT,
	IN p_fecha_nacimiento DATE,
	IN p_password_hash VARCHAR(255),
	OUT p_id_profesor BIGINT
)
LANGUAGE plpgsql
AS $$
BEGIN
	-- ✅
	IF NOT EXISTS (
		SELECT 1
		FROM academico.profesores
		WHERE cedula = trim(p_cedula_actual)
	) THEN
		PERFORM academico.fn_lanzar_excepcion(
			'No existe un profesor con la cédula indicada.',
			jsonb_build_object('cedula', p_cedula_actual),
			'Verifique la cédula actual del profesor.',
			'PR008'
		);
	END IF;

	-- ✅
	IF NULLIF(trim(p_nombre), '') IS NULL
		OR NULLIF(trim(p_primer_apellido), '') IS NULL
		OR NULLIF(trim(p_cedula), '') IS NULL
		OR p_email IS NULL
		OR NULLIF(trim(p_email::TEXT), '') IS NULL
		OR p_fecha_nacimiento IS NULL
		OR NULLIF(trim(p_password_hash), '') IS NULL THEN
		PERFORM academico.fn_lanzar_excepcion(
			'El nombre, el primer apellido, la cédula, el correo, la fecha de nacimiento y la contraseña son obligatorios.',
			jsonb_build_object(
				'nombre', p_nombre,
				'primer_apellido', p_primer_apellido,
				'cedula', p_cedula,
				'email', p_email,
				'fecha_nacimiento', p_fecha_nacimiento,
				'password_hash', NULLIF(trim(p_password_hash), '')
			),
			'Complete todos los datos requeridos del profesor.',
			'PR001'
		);
	END IF;

	-- ✅
	IF length(trim(p_nombre)) < 2
		OR length(trim(p_primer_apellido)) < 2 THEN
		PERFORM academico.fn_lanzar_excepcion(
			'El nombre y el primer apellido deben tener al menos 2 caracteres.',
			jsonb_build_object('nombre', p_nombre, 'primer_apellido', p_primer_apellido),
			NULL,
			'PR002'
		);
	END IF;

	-- ✅
	IF length(trim(p_cedula)) < 5 THEN
		PERFORM academico.fn_lanzar_excepcion(
			'La cédula debe tener al menos 5 caracteres.',
			jsonb_build_object('cedula', p_cedula),
			NULL,
			'PR003'
		);
	END IF;

	-- ✅
	IF p_email::TEXT !~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' THEN
		PERFORM academico.fn_lanzar_excepcion(
			'El correo electrónico no tiene un formato válido.',
			jsonb_build_object('email', p_email),
			NULL,
			'PR004'
		);
	END IF;

	-- ✅
	IF p_fecha_nacimiento < DATE '1900-01-01'
		OR p_fecha_nacimiento > CURRENT_DATE THEN
		PERFORM academico.fn_lanzar_excepcion(
			'La fecha de nacimiento debe estar entre el 01/01/1900 y la fecha actual.',
			jsonb_build_object('fecha_nacimiento', p_fecha_nacimiento),
			NULL,
			'PR005'
		);
	END IF;

	-- ✅
	IF EXISTS (
		SELECT 1
		FROM academico.profesores
		WHERE cedula = trim(p_cedula)
			AND cedula <> trim(p_cedula_actual)
	) THEN
		PERFORM academico.fn_lanzar_excepcion(
			'Ya existe un profesor con esa cédula.',
			jsonb_build_object('cedula', p_cedula),
			NULL,
			'PR006'
		);
	END IF;

	-- ✅
	IF EXISTS (
		SELECT 1
		FROM academico.profesores
		WHERE lower(trim(email::TEXT)) = lower(trim(p_email))
			AND cedula <> trim(p_cedula_actual)
	) THEN
		PERFORM academico.fn_lanzar_excepcion(
			'Ya existe un profesor con ese correo electrónico.',
			jsonb_build_object('email', p_email),
			NULL,
			'PR007'
		);
	END IF;

	UPDATE academico.profesores
	SET nombre = NULLIF(trim(p_nombre), ''),
		primer_apellido = NULLIF(trim(p_primer_apellido), ''),
		segundo_apellido = NULLIF(trim(p_segundo_apellido), ''),
		cedula = NULLIF(trim(p_cedula), ''),
		numero_celular = NULLIF(trim(p_numero_celular), ''),
		email = NULLIF(trim(p_email), ''),
		fecha_nacimiento = p_fecha_nacimiento,
		password_hash = NULLIF(trim(p_password_hash), '')
	WHERE cedula = trim(p_cedula_actual)
	RETURNING id_profesor INTO p_id_profesor;
END;
$$;

CREATE OR REPLACE PROCEDURE academico.desactivar_profesor(
	IN p_cedula VARCHAR(20),
	OUT p_id_profesor BIGINT
)
LANGUAGE plpgsql
AS $$
BEGIN
	UPDATE academico.profesores
	SET activo = FALSE
	WHERE cedula = trim(p_cedula)
	RETURNING id_profesor INTO p_id_profesor;

	-- ✅
	IF p_id_profesor IS NULL THEN
		PERFORM academico.fn_lanzar_excepcion(
			'No existe un profesor con la cédula indicada.',
			jsonb_build_object('cedula', p_cedula),
			'Verifique la cédula del profesor.',
			'PR008'
		);
	END IF;
END;
$$;

CREATE OR REPLACE PROCEDURE academico.activar_profesor(
	IN p_cedula VARCHAR(20),
	OUT p_id_profesor BIGINT
)
LANGUAGE plpgsql
AS $$
BEGIN
	UPDATE academico.profesores
	SET activo = TRUE
	WHERE cedula = trim(p_cedula)
	RETURNING id_profesor INTO p_id_profesor;

	-- ✅
	IF p_id_profesor IS NULL THEN
		PERFORM academico.fn_lanzar_excepcion(
			'No existe un profesor con la cédula indicada.',
			jsonb_build_object('cedula', p_cedula),
			'Verifique la cédula del profesor.',
			'PR008'
		);
	END IF;
END;
$$;

CREATE OR REPLACE PROCEDURE academico.borrar_profesor(
	IN p_cedula VARCHAR(20),
	OUT p_id_profesor BIGINT
)
LANGUAGE plpgsql
AS $$
BEGIN
	DELETE FROM academico.profesores
	WHERE cedula = trim(p_cedula)
	RETURNING id_profesor INTO p_id_profesor;

	-- ✅
	IF p_id_profesor IS NULL THEN
		PERFORM academico.fn_lanzar_excepcion(
			'No existe un profesor con la cédula indicada.',
			jsonb_build_object('cedula', p_cedula),
			'Verifique la cédula del profesor.',
			'PR008'
		);
	END IF;
END;
$$;

----------------------------------------------------------------------------
-- ESTUDIANTES
----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE academico.registrar_estudiante(
	IN p_nombre VARCHAR(100),
	IN p_primer_apellido VARCHAR(100),
	IN p_segundo_apellido VARCHAR(100),
	IN p_cedula VARCHAR(20),
	IN p_numero_celular VARCHAR(20),
	IN p_email TEXT,
	IN p_fecha_nacimiento DATE,
	OUT p_id_estudiante BIGINT
)
LANGUAGE plpgsql
AS $$
BEGIN
	-- ✅
	IF NULLIF(trim(p_nombre), '') IS NULL
		OR NULLIF(trim(p_primer_apellido), '') IS NULL
		OR NULLIF(trim(p_cedula), '') IS NULL
		OR p_email IS NULL
		OR NULLIF(trim(p_email), '') IS NULL
		OR p_fecha_nacimiento IS NULL THEN
		PERFORM academico.fn_lanzar_excepcion(
			'El nombre, el primer apellido, la cédula, el correo y la fecha de nacimiento son obligatorios.',
			jsonb_build_object(
				'nombre', p_nombre,
				'primer_apellido', p_primer_apellido,
				'cedula', p_cedula,
				'email', p_email,
				'fecha_nacimiento', p_fecha_nacimiento
			),
			'Complete todos los datos requeridos del estudiante.',
			'ES001'
		);
	END IF;

	-- ✅
	IF length(trim(p_nombre)) < 2
		OR length(trim(p_primer_apellido)) < 2 THEN
		PERFORM academico.fn_lanzar_excepcion(
			'El nombre y el primer apellido deben tener al menos 2 caracteres.',
			jsonb_build_object(
				'nombre', p_nombre,
				'primer_apellido', p_primer_apellido
			),
			NULL,
			'ES002'
		);
	END IF;

	-- ✅
	IF length(trim(p_cedula)) < 5 THEN
		PERFORM academico.fn_lanzar_excepcion(
			'La cédula debe tener al menos 5 caracteres.',
			jsonb_build_object('cedula', p_cedula),
			NULL,
			'ES003'
		);
	END IF;

	-- ✅
	IF p_email !~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' THEN
		PERFORM academico.fn_lanzar_excepcion(
			'El correo electrónico no tiene un formato válido.',
			jsonb_build_object('email', p_email),
			NULL,
			'ES004'
		);
	END IF;

	-- ✅
	IF p_fecha_nacimiento < CURRENT_DATE - INTERVAL '19 years'
		OR p_fecha_nacimiento > CURRENT_DATE - INTERVAL '16 years' THEN
		PERFORM academico.fn_lanzar_excepcion(
			'El estudiante debe tener entre 16 y 19 años.',
			jsonb_build_object('fecha_nacimiento', p_fecha_nacimiento),
			NULL,
			'ES005'
		);
	END IF;

	-- ✅
	IF EXISTS (
		SELECT 1
		FROM academico.estudiantes
		WHERE cedula = trim(p_cedula)
	) THEN
		PERFORM academico.fn_lanzar_excepcion(
			'Ya existe un estudiante con esa cédula.',
			jsonb_build_object('cedula', p_cedula),
			NULL,
			'ES006'
		);
	END IF;

	-- ✅
	IF EXISTS (
		SELECT 1
		FROM academico.estudiantes
		WHERE lower(trim(email::TEXT)) = lower(trim(p_email))
	) THEN
		PERFORM academico.fn_lanzar_excepcion(
			'Ya existe un estudiante con ese correo electrónico.',
			jsonb_build_object('email', p_email),
			NULL,
			'ES007'
		);
	END IF;

	INSERT INTO academico.estudiantes (
		nombre,
		primer_apellido,
		segundo_apellido,
		cedula,
		numero_celular,
		email,
		fecha_nacimiento
	)
	VALUES (
		NULLIF(trim(p_nombre), ''),
		NULLIF(trim(p_primer_apellido), ''),
		NULLIF(trim(p_segundo_apellido), ''),
		NULLIF(trim(p_cedula), ''),
		NULLIF(trim(p_numero_celular), ''),
		NULLIF(trim(p_email), ''),
		p_fecha_nacimiento
	)
	RETURNING id_estudiante INTO p_id_estudiante;
END;
$$;

CREATE OR REPLACE FUNCTION academico.obtener_estudiante(
	p_cedula VARCHAR(20)
)
RETURNS SETOF academico.estudiante_publico
LANGUAGE plpgsql
AS $$
BEGIN
	RETURN QUERY
	SELECT e.id_estudiante,
		e.nombre,
		e.primer_apellido,
		e.segundo_apellido,
		e.cedula,
		e.numero_celular,
		e.email::TEXT,
		e.fecha_nacimiento,
		e.fecha_registro
	FROM academico.estudiantes e
	WHERE e.cedula = trim(p_cedula);

	-- ✅
	IF NOT FOUND THEN
		PERFORM academico.fn_lanzar_excepcion(
			'No existe un estudiante con la cédula indicada.',
			jsonb_build_object('cedula', p_cedula),
			'Verifique la cédula del estudiante.',
			'ES008'
		);
	END IF;
END;
$$;

CREATE OR REPLACE FUNCTION academico.obtener_estudiantes()
RETURNS SETOF academico.estudiante_publico
LANGUAGE plpgsql
AS $$
BEGIN
	RETURN QUERY
	SELECT e.id_estudiante,
		e.nombre,
		e.primer_apellido,
		e.segundo_apellido,
		e.cedula,
		e.numero_celular,
		e.email::TEXT,
		e.fecha_nacimiento,
		e.fecha_registro
	FROM academico.estudiantes e
	ORDER BY e.id_estudiante;
END;
$$;

CREATE OR REPLACE PROCEDURE academico.actualizar_estudiante(
	IN p_cedula_actual VARCHAR(20),
	IN p_nombre VARCHAR(100),
	IN p_primer_apellido VARCHAR(100),
	IN p_segundo_apellido VARCHAR(100),
	IN p_cedula VARCHAR(20),
	IN p_numero_celular VARCHAR(20),
	IN p_email TEXT,
	IN p_fecha_nacimiento DATE,
	OUT p_id_estudiante BIGINT
)
LANGUAGE plpgsql
AS $$
BEGIN
	-- ✅
	IF NOT EXISTS (
		SELECT 1
		FROM academico.estudiantes
		WHERE cedula = trim(p_cedula_actual)
	) THEN
		PERFORM academico.fn_lanzar_excepcion(
			'No existe un estudiante con la cédula indicada.',
			jsonb_build_object('cedula', p_cedula_actual),
			'Verifique la cédula actual del estudiante.',
			'ES008'
		);
	END IF;

	-- ✅
	IF NULLIF(trim(p_nombre), '') IS NULL
		OR NULLIF(trim(p_primer_apellido), '') IS NULL
		OR NULLIF(trim(p_cedula), '') IS NULL
		OR p_email IS NULL
		OR NULLIF(trim(p_email), '') IS NULL
		OR p_fecha_nacimiento IS NULL THEN
		PERFORM academico.fn_lanzar_excepcion(
			'El nombre, el primer apellido, la cédula, el correo y la fecha de nacimiento son obligatorios.',
			jsonb_build_object('nombre', p_nombre, 'primer_apellido', p_primer_apellido, 'cedula', p_cedula, 'email', p_email, 'fecha_nacimiento', p_fecha_nacimiento),
			'Complete todos los datos requeridos del estudiante.',
			'ES001'
		);
	END IF;

	-- ✅
	IF length(trim(p_nombre)) < 2 OR length(trim(p_primer_apellido)) < 2 THEN
		PERFORM academico.fn_lanzar_excepcion(
			'El nombre y el primer apellido deben tener al menos 2 caracteres.',
			jsonb_build_object('nombre', p_nombre, 'primer_apellido', p_primer_apellido), NULL, 'ES002'
		);
	END IF;

	-- ✅
	IF length(trim(p_cedula)) < 5 THEN
		PERFORM academico.fn_lanzar_excepcion(
			'La cédula debe tener al menos 5 caracteres.',
			jsonb_build_object('cedula', p_cedula), NULL, 'ES003'
		);
	END IF;

	-- ✅
	IF p_email !~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' THEN
		PERFORM academico.fn_lanzar_excepcion(
			'El correo electrónico no tiene un formato válido.',
			jsonb_build_object('email', p_email), NULL, 'ES004'
		);
	END IF;

	-- ✅
	IF p_fecha_nacimiento < CURRENT_DATE - INTERVAL '19 years'
		OR p_fecha_nacimiento > CURRENT_DATE - INTERVAL '16 years' THEN
		PERFORM academico.fn_lanzar_excepcion(
			'El estudiante debe tener entre 16 y 19 años.',
			jsonb_build_object('fecha_nacimiento', p_fecha_nacimiento), NULL, 'ES005'
		);
	END IF;

	-- ✅
	IF EXISTS (SELECT 1 FROM academico.estudiantes WHERE cedula = trim(p_cedula) AND cedula <> trim(p_cedula_actual)) THEN
		PERFORM academico.fn_lanzar_excepcion('Ya existe un estudiante con esa cédula.', jsonb_build_object('cedula', p_cedula), NULL, 'ES006');
	END IF;

	-- ✅
	IF EXISTS (SELECT 1 FROM academico.estudiantes WHERE lower(trim(email::TEXT)) = lower(trim(p_email)) AND cedula <> trim(p_cedula_actual)) THEN
		PERFORM academico.fn_lanzar_excepcion('Ya existe un estudiante con ese correo electrónico.', jsonb_build_object('email', p_email), NULL, 'ES007');
	END IF;

	UPDATE academico.estudiantes
	SET nombre = NULLIF(trim(p_nombre), ''),
		primer_apellido = NULLIF(trim(p_primer_apellido), ''),
		segundo_apellido = NULLIF(trim(p_segundo_apellido), ''),
		cedula = NULLIF(trim(p_cedula), ''),
		numero_celular = NULLIF(trim(p_numero_celular), ''),
		email = NULLIF(trim(p_email), ''),
		fecha_nacimiento = p_fecha_nacimiento
	WHERE cedula = trim(p_cedula_actual)
	RETURNING id_estudiante INTO p_id_estudiante;
END;
$$;

CREATE OR REPLACE PROCEDURE academico.borrar_estudiante(
	IN p_cedula VARCHAR(20),
	OUT p_id_estudiante BIGINT
)
LANGUAGE plpgsql
AS $$
BEGIN
	DELETE FROM academico.estudiantes
	WHERE cedula = trim(p_cedula)
	RETURNING id_estudiante INTO p_id_estudiante;

	-- ✅
	IF p_id_estudiante IS NULL THEN
		PERFORM academico.fn_lanzar_excepcion(
			'No existe un estudiante con la cédula indicada.',
			jsonb_build_object('cedula', p_cedula),
			'Verifique la cédula del estudiante.',
			'ES008'
		);
	END IF;
END;
$$;

----------------------------------------------------------------------------
-- CURSOS LECTIVOS
----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE academico.abrir_curso_lectivo(
	IN p_year_ciclo INTEGER,
	IN p_fecha_inicio_i DATE,
	IN p_fecha_fin_i DATE,
	IN p_fecha_inicio_ii DATE,
	IN p_fecha_fin_ii DATE,
	OUT p_id_curso_lectivo BIGINT
)
LANGUAGE plpgsql
AS $$
BEGIN
	-- ✅
	IF p_year_ciclo IS NULL
		OR p_fecha_inicio_i IS NULL
		OR p_fecha_fin_i IS NULL
		OR p_fecha_inicio_ii IS NULL
		OR p_fecha_fin_ii IS NULL THEN

		PERFORM academico.fn_lanzar_excepcion(
            'Todas las fechas y el año del curso lectivo son obligatorios.',
            jsonb_build_object(
                'year_ciclo', p_year_ciclo,
				'fecha_inicio_i', p_fecha_inicio_i,
				'fecha_fin_i', p_fecha_fin_i,
				'fecha_inicio_ii', p_fecha_inicio_ii,
				'fecha_fin_ii', p_fecha_fin_ii
            ),
            'Debe ingresar todas las fechas y el año del curso lectivo',
            'CL007'
        );
	END IF;

	-- ✅
	IF EXTRACT(YEAR FROM p_fecha_inicio_i) <> p_year_ciclo
		OR EXTRACT(YEAR FROM p_fecha_fin_i) <> p_year_ciclo
		OR EXTRACT(YEAR FROM p_fecha_inicio_ii) <> p_year_ciclo
		OR EXTRACT(YEAR FROM p_fecha_fin_ii) <> p_year_ciclo THEN
		PERFORM academico.fn_lanzar_excepcion(
			'Todas las fechas deben pertenecer al año del curso lectivo.',
			jsonb_build_object(
				'year_ciclo', p_year_ciclo,
				'fecha_inicio_i', p_fecha_inicio_i,
				'fecha_fin_i', p_fecha_fin_i,
				'fecha_inicio_ii', p_fecha_inicio_ii,
				'fecha_fin_ii', p_fecha_fin_ii
			),
			NULL,
			'CL008'
		);
	END IF;

	-- ✅
	IF p_fecha_fin_i <= p_fecha_inicio_i THEN
		PERFORM academico.fn_lanzar_excepcion(
			'La fecha de fin del I semestre debe ser posterior a su fecha de inicio.',
			jsonb_build_object(
				'fecha_inicio_i', p_fecha_inicio_i,
				'fecha_fin_i', p_fecha_fin_i
			),
			NULL,
			'CL009'
		);
	END IF;

	-- ✅
	IF p_fecha_fin_ii <= p_fecha_inicio_ii THEN
		PERFORM academico.fn_lanzar_excepcion(
			'La fecha de fin del II semestre debe ser posterior a su fecha de inicio.',
			jsonb_build_object(
				'fecha_inicio_ii', p_fecha_inicio_ii,
				'fecha_fin_ii', p_fecha_fin_ii
			),
			NULL,
			'CL010'
		);
	END IF;

	-- ✅
	IF p_fecha_inicio_ii <= p_fecha_fin_i THEN
		PERFORM academico.fn_lanzar_excepcion(
			'El II semestre debe iniciar después de finalizar el I semestre.',
			jsonb_build_object(
				'fecha_fin_i', p_fecha_fin_i,
				'fecha_inicio_ii', p_fecha_inicio_ii
			),
			NULL,
			'CL011'
		);
	END IF;

	INSERT INTO academico.cursos_lectivos (
		year_ciclo,
		fecha_inicio,
		fecha_fin
	)
	VALUES (
		p_year_ciclo,
		p_fecha_inicio_i,
		p_fecha_fin_ii
	)
	RETURNING id_curso_lectivo INTO p_id_curso_lectivo;

	INSERT INTO academico.semestres (
		id_curso_lectivo,
		numero_semestre,
		fecha_inicio,
		fecha_fin
	)
	VALUES
		(p_id_curso_lectivo, 'I_SEMESTRE', p_fecha_inicio_i, p_fecha_fin_i),
		(p_id_curso_lectivo, 'II_SEMESTRE', p_fecha_inicio_ii, p_fecha_fin_ii);
END;
$$;

CREATE OR REPLACE FUNCTION academico.obtener_curso_lectivo(
	p_year_ciclo INTEGER
)
RETURNS SETOF academico.curso_lectivo_publico
LANGUAGE plpgsql
AS $$
BEGIN
	RETURN QUERY
	SELECT c.id_curso_lectivo, c.year_ciclo, c.fecha_inicio, c.fecha_fin
	FROM academico.cursos_lectivos c
	WHERE c.year_ciclo = p_year_ciclo;

	-- ✅
	IF NOT FOUND THEN
		PERFORM academico.fn_lanzar_excepcion(
			'No existe un curso lectivo para el año indicado.',
			jsonb_build_object('year_ciclo', p_year_ciclo),
			'Verifique el año del curso lectivo.',
			'CL012'
		);
	END IF;
END;
$$;

CREATE OR REPLACE FUNCTION academico.obtener_cursos_lectivos()
RETURNS SETOF academico.curso_lectivo_publico
LANGUAGE plpgsql
AS $$
BEGIN
	RETURN QUERY
	SELECT c.id_curso_lectivo, c.year_ciclo, c.fecha_inicio, c.fecha_fin
	FROM academico.cursos_lectivos c
	ORDER BY c.year_ciclo DESC;
END;
$$;

CREATE OR REPLACE PROCEDURE academico.actualizar_curso_lectivo(
	IN p_year_ciclo INTEGER,
	IN p_fecha_inicio_i DATE,
	IN p_fecha_fin_i DATE,
	IN p_fecha_inicio_ii DATE,
	IN p_fecha_fin_ii DATE,
	OUT p_id_curso_lectivo BIGINT
)
LANGUAGE plpgsql
AS $$
BEGIN

	-- ✅
	IF p_year_ciclo IS NULL
		OR p_fecha_inicio_i IS NULL
		OR p_fecha_fin_i IS NULL
		OR p_fecha_inicio_ii IS NULL
		OR p_fecha_fin_ii IS NULL THEN

		PERFORM academico.fn_lanzar_excepcion(
            'Todas las fechas y el año del curso lectivo son obligatorios.',
            jsonb_build_object(
                'year_ciclo', p_year_ciclo,
				'fecha_inicio_i', p_fecha_inicio_i,
				'fecha_fin_i', p_fecha_fin_i,
				'fecha_inicio_ii', p_fecha_inicio_ii,
				'fecha_fin_ii', p_fecha_fin_ii
            ),
            'Debe ingresar todas las fechas y el año del curso lectivo',
            'CL007'
        );
	END IF;

	-- ✅
	IF NOT EXISTS (
		SELECT 1
		FROM academico.cursos_lectivos c
		WHERE c.year_ciclo = p_year_ciclo
	) THEN
		PERFORM academico.fn_lanzar_excepcion(
			'No existe un curso lectivo para el año indicado.',
			jsonb_build_object('year_ciclo', p_year_ciclo),
			'Verifique el año del curso lectivo.',
			'CL012'
		);
	END IF;

	-- ✅
	IF EXTRACT(YEAR FROM p_fecha_inicio_i) <> p_year_ciclo
		OR EXTRACT(YEAR FROM p_fecha_fin_i) <> p_year_ciclo
		OR EXTRACT(YEAR FROM p_fecha_inicio_ii) <> p_year_ciclo
		OR EXTRACT(YEAR FROM p_fecha_fin_ii) <> p_year_ciclo THEN
		PERFORM academico.fn_lanzar_excepcion(
			'Todas las fechas deben pertenecer al año del curso lectivo.',
			jsonb_build_object(
				'year_ciclo', p_year_ciclo,
				'fecha_inicio_i', p_fecha_inicio_i,
				'fecha_fin_i', p_fecha_fin_i,
				'fecha_inicio_ii', p_fecha_inicio_ii,
				'fecha_fin_ii', p_fecha_fin_ii
			),
			NULL,
			'CL008'
		);
	END IF;

	-- ✅
	IF p_fecha_fin_i <= p_fecha_inicio_i THEN
		PERFORM academico.fn_lanzar_excepcion(
			'La fecha de fin del I semestre debe ser posterior a su fecha de inicio.',
			jsonb_build_object(
				'fecha_inicio_i', p_fecha_inicio_i,
				'fecha_fin_i', p_fecha_fin_i
			),
			NULL,
			'CL009'
		);
	END IF;

	-- ✅
	IF p_fecha_fin_ii <= p_fecha_inicio_ii THEN
		PERFORM academico.fn_lanzar_excepcion(
			'La fecha de fin del II semestre debe ser posterior a su fecha de inicio.',
			jsonb_build_object(
				'fecha_inicio_ii', p_fecha_inicio_ii,
				'fecha_fin_ii', p_fecha_fin_ii
			),
			NULL,
			'CL010'
		);
	END IF;

	-- ✅
	IF p_fecha_inicio_ii <= p_fecha_fin_i THEN
		PERFORM academico.fn_lanzar_excepcion(
			'El II semestre debe iniciar después de finalizar el I semestre.',
			jsonb_build_object(
				'fecha_fin_i', p_fecha_fin_i,
				'fecha_inicio_ii', p_fecha_inicio_ii
			),
			NULL,
			'CL011'
		);
	END IF;

	UPDATE academico.cursos_lectivos c
	SET fecha_inicio = p_fecha_inicio_i,
		fecha_fin = p_fecha_fin_ii
	WHERE c.year_ciclo = p_year_ciclo
	RETURNING id_curso_lectivo INTO p_id_curso_lectivo;

	UPDATE academico.semestres s
	SET fecha_inicio = CASE s.numero_semestre
			WHEN 'I_SEMESTRE' THEN p_fecha_inicio_i
			WHEN 'II_SEMESTRE' THEN p_fecha_inicio_ii
			ELSE s.fecha_inicio
		END,
		fecha_fin = CASE s.numero_semestre
			WHEN 'I_SEMESTRE' THEN p_fecha_fin_i
			WHEN 'II_SEMESTRE' THEN p_fecha_fin_ii
			ELSE s.fecha_fin
		END
	WHERE s.id_curso_lectivo = p_id_curso_lectivo;
END;
$$;

CREATE OR REPLACE PROCEDURE academico.borrar_curso_lectivo(
	IN p_year_ciclo INTEGER,
	OUT p_id_curso_lectivo BIGINT
)
LANGUAGE plpgsql
AS $$
BEGIN
	DELETE FROM academico.semestres s
	USING academico.cursos_lectivos c
	WHERE c.id_curso_lectivo = s.id_curso_lectivo
		AND c.year_ciclo = p_year_ciclo;

	DELETE FROM academico.cursos_lectivos
	WHERE year_ciclo = p_year_ciclo
	RETURNING id_curso_lectivo INTO p_id_curso_lectivo;

	-- ✅
	IF p_id_curso_lectivo IS NULL THEN
		PERFORM academico.fn_lanzar_excepcion(
			'No existe un curso lectivo para el año indicado.',
			jsonb_build_object('year_ciclo', p_year_ciclo),
			'Verifique el año del curso lectivo.',
			'CL012'
		);
	END IF;
END;
$$;

----------------------------------------------------------------------------
-- SECCIONES
----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE academico.registrar_seccion(
	IN p_year_ciclo INTEGER,
	IN p_nivel INTEGER,
	IN p_numero_seccion INTEGER,
	OUT p_id_seccion BIGINT
)
LANGUAGE plpgsql
AS $$
DECLARE
	v_id_curso_lectivo BIGINT;
BEGIN
	-- ✅
	IF p_year_ciclo IS NULL
		OR p_nivel IS NULL
		OR p_numero_seccion IS NULL THEN
		PERFORM academico.fn_lanzar_excepcion(
			'El año del curso lectivo, el nivel y el número de sección son obligatorios.',
			jsonb_build_object(
				'year_ciclo', p_year_ciclo,
				'nivel', p_nivel,
				'numero_seccion', p_numero_seccion
			),
			'Complete todos los datos requeridos de la sección.',
			'SE001'
		);
	END IF;

	-- ✅
	IF p_nivel NOT IN (10, 11) THEN
		PERFORM academico.fn_lanzar_excepcion(
			'El nivel de la sección debe ser 10 u 11.',
			jsonb_build_object('nivel', p_nivel),
			NULL,
			'SE002'
		);
	END IF;

	-- ✅
	IF p_numero_seccion <= 0 THEN
		PERFORM academico.fn_lanzar_excepcion(
			'El número de sección debe ser mayor que cero.',
			jsonb_build_object('numero_seccion', p_numero_seccion),
			NULL,
			'SE003'
		);
	END IF;

	SELECT c.id_curso_lectivo
	INTO v_id_curso_lectivo
	FROM academico.cursos_lectivos c
	WHERE c.year_ciclo = p_year_ciclo;

	-- ✅
	IF v_id_curso_lectivo IS NULL THEN
		PERFORM academico.fn_lanzar_excepcion(
			'No existe un curso lectivo para el año indicado.',
			jsonb_build_object('year_ciclo', p_year_ciclo),
			'Primero registre el curso lectivo correspondiente.',
			'SE004'
		);
	END IF;

	-- ✅
	IF EXISTS (
		SELECT 1
		FROM academico.secciones
		WHERE id_curso_lectivo = v_id_curso_lectivo
			AND nivel = p_nivel
			AND numero_seccion = p_numero_seccion
	) THEN
		PERFORM academico.fn_lanzar_excepcion(
			'Ya existe esa sección para el curso lectivo indicado.',
			jsonb_build_object(
				'year_ciclo', p_year_ciclo,
				'nivel', p_nivel,
				'numero_seccion', p_numero_seccion
			),
			NULL,
			'SE005'
		);
	END IF;

	INSERT INTO academico.secciones (
		id_curso_lectivo,
		nivel,
		numero_seccion
	)
	VALUES (
		v_id_curso_lectivo,
		p_nivel,
		p_numero_seccion
	)
	RETURNING id_seccion INTO p_id_seccion;
END;
$$;

CREATE OR REPLACE FUNCTION academico.obtener_secciones()
RETURNS SETOF academico.seccion_publica
LANGUAGE plpgsql
AS $$
BEGIN
	RETURN QUERY
	SELECT s.id_seccion, c.year_ciclo, s.nivel || '-' || s.numero_seccion as seccion
	FROM academico.secciones s
	JOIN academico.cursos_lectivos c ON s.id_curso_lectivo = c.id_curso_lectivo
	ORDER BY s.id_curso_lectivo, s.nivel, s.numero_seccion;
END;
$$;

CREATE OR REPLACE PROCEDURE academico.borrar_seccion(
	IN p_year_ciclo INTEGER,
	IN p_nivel INTEGER,
	IN p_numero_seccion INTEGER,
	OUT p_id_seccion BIGINT
)
LANGUAGE plpgsql
AS $$
DECLARE
	v_id_curso_lectivo BIGINT;
BEGIN

	SELECT c.id_curso_lectivo
	INTO v_id_curso_lectivo
	FROM academico.cursos_lectivos c
	WHERE c.year_ciclo = p_year_ciclo;

	DELETE FROM academico.secciones
	WHERE id_curso_lectivo = v_id_curso_lectivo
		AND nivel = p_nivel
		AND numero_seccion = p_numero_seccion
	RETURNING id_seccion INTO p_id_seccion;

	-- ✅
	IF p_id_seccion IS NULL THEN
		PERFORM academico.fn_lanzar_excepcion(
			'No existe una sección con los datos indicados.',
			jsonb_build_object(
				'year_ciclo', p_year_ciclo,
				'nivel', p_nivel,
				'numero_seccion', p_numero_seccion
			),
			'Verifique los datos de la sección.',
			'SE006'
		);
	END IF;
END;
$$;

----------------------------------------------------------------------------
-- MATRICULAS
----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE academico.registrar_matricula(
	IN p_cedula_estudiante VARCHAR(20),
	IN p_year_ciclo INTEGER,
	IN p_nivel INTEGER,
	IN p_numero_seccion INTEGER,
	OUT p_id_matricula BIGINT
)
LANGUAGE plpgsql
AS $$
DECLARE
	v_id_estudiante BIGINT;
	v_id_curso_lectivo BIGINT;
	v_id_seccion BIGINT;
BEGIN
	-- ✅
	IF NULLIF(trim(p_cedula_estudiante), '') IS NULL
		OR p_year_ciclo IS NULL
		OR p_nivel IS NULL
		OR p_numero_seccion IS NULL THEN
		PERFORM academico.fn_lanzar_excepcion(
			'La cédula, el año, el nivel y el número de sección son obligatorios.',
			jsonb_build_object(
				'cedula_estudiante', p_cedula_estudiante,
				'year_ciclo', p_year_ciclo,
				'nivel', p_nivel,
				'numero_seccion', p_numero_seccion
			),
			'Complete todos los datos requeridos de la matrícula.',
			'MA001'
		);
	END IF;

	-- ✅
	IF length(trim(p_cedula_estudiante)) < 5 THEN
		PERFORM academico.fn_lanzar_excepcion(
			'La cédula del estudiante debe tener al menos 5 caracteres.',
			jsonb_build_object('cedula_estudiante', p_cedula_estudiante),
			NULL,
			'MA002'
		);
	END IF;

	-- ✅
	IF p_nivel NOT IN (10, 11) THEN
		PERFORM academico.fn_lanzar_excepcion(
			'El nivel de la matrícula debe ser 10 u 11.',
			jsonb_build_object('nivel', p_nivel),
			NULL,
			'MA003'
		);
	END IF;

	-- ✅
	IF p_numero_seccion <= 0 THEN
		PERFORM academico.fn_lanzar_excepcion(
			'El número de sección debe ser mayor que cero.',
			jsonb_build_object('numero_seccion', p_numero_seccion),
			NULL,
			'MA004'
		);
	END IF;

	SELECT e.id_estudiante
	INTO v_id_estudiante
	FROM academico.estudiantes e
	WHERE e.cedula = trim(p_cedula_estudiante);

	-- ✅
	IF v_id_estudiante IS NULL THEN
		PERFORM academico.fn_lanzar_excepcion(
			'No existe un estudiante con la cédula indicada.',
			jsonb_build_object('cedula_estudiante', p_cedula_estudiante),
			'Verifique la cédula del estudiante.',
			'MA005'
		);
	END IF;

	SELECT c.id_curso_lectivo
	INTO v_id_curso_lectivo
	FROM academico.cursos_lectivos c
	WHERE c.year_ciclo = p_year_ciclo;

	-- ✅
	IF v_id_curso_lectivo IS NULL THEN
		PERFORM academico.fn_lanzar_excepcion(
			'No existe un curso lectivo para el año indicado.',
			jsonb_build_object('year_ciclo', p_year_ciclo),
			'Primero registre el curso lectivo correspondiente.',
			'MA006'
		);
	END IF;

	SELECT s.id_seccion
	INTO v_id_seccion
	FROM academico.secciones s
	WHERE s.id_curso_lectivo = v_id_curso_lectivo
		AND s.nivel = p_nivel
		AND s.numero_seccion = p_numero_seccion;

	-- ✅
	IF v_id_seccion IS NULL THEN
		PERFORM academico.fn_lanzar_excepcion(
			'No existe la sección indicada para el curso lectivo.',
			jsonb_build_object(
				'year_ciclo', p_year_ciclo,
				'nivel', p_nivel,
				'numero_seccion', p_numero_seccion
			),
			'Verifique el curso, nivel y número de sección.',
			'MA007'
		);
	END IF;

	-- ✅
	IF EXISTS (
		SELECT 1
		FROM academico.matriculas_secciones
		WHERE id_estudiante = v_id_estudiante
			AND id_seccion = v_id_seccion
	) THEN
		PERFORM academico.fn_lanzar_excepcion(
			'El estudiante ya está matriculado en esa sección.',
			jsonb_build_object(
				'id_estudiante', v_id_estudiante,
				'id_seccion', v_id_seccion,
				'year_ciclo', p_year_ciclo
			),
			'No puede matricular al mismo estudiante en la misma sección.',
			'MA008'
		);
	END IF;

	INSERT INTO academico.matriculas_secciones (
		id_estudiante,
		id_seccion,
		estado
	)
	VALUES (
		v_id_estudiante,
		v_id_seccion,
		'EN_SISTEMA'
	)
	RETURNING id_matricula INTO p_id_matricula;
END;
$$;

CREATE OR REPLACE PROCEDURE academico.finalizar_matricula(
	IN p_id_matricula BIGINT,
	OUT p_id_matricula_finalizada BIGINT
)
LANGUAGE plpgsql
AS $$
BEGIN
	-- ✅
	IF NOT EXISTS (
		SELECT 1
		FROM academico.matriculas_secciones m
		JOIN academico.estudiantes e ON e.id_estudiante = m.id_estudiante
		WHERE m.id_matricula = p_id_matricula
	) THEN
		PERFORM academico.fn_lanzar_excepcion(
			'No existe una matrícula con el ID indicado.',
			jsonb_build_object('id_matricula', p_id_matricula),
			'Verifique el ID de matrícula.',
			'MA009'
		);
	END IF;

	-- ✅
	IF EXISTS (
		SELECT 1
		FROM academico.matriculas_secciones m
		JOIN academico.estudiantes e ON e.id_estudiante = m.id_estudiante
		WHERE m.id_matricula = p_id_matricula
			AND m.estado = 'FINALIZADA'
	) THEN
		PERFORM academico.fn_lanzar_excepcion(
			'La matrícula ya está finalizada.',
			jsonb_build_object('id_matricula', p_id_matricula),
			NULL,
			'MA010'
		);
	END IF;

	UPDATE academico.matriculas_secciones
	SET estado = 'FINALIZADA',
		fecha_finalizacion = COALESCE(fecha_finalizacion, CURRENT_TIMESTAMP)
	WHERE id_matricula = p_id_matricula
	RETURNING id_matricula INTO p_id_matricula_finalizada;

END;
$$;

CREATE OR REPLACE PROCEDURE academico.subir_a_nivel_11(
	IN p_cedula_estudiante VARCHAR(20),
	OUT p_id_matricula BIGINT
)
LANGUAGE plpgsql
AS $$
DECLARE
	v_id_estudiante BIGINT;
	v_id_matricula_nivel_10 BIGINT;
	v_id_seccion_nivel_11 BIGINT;
	v_year_ciclo_nivel_10 INTEGER;
	v_year_ciclo_nivel_11 INTEGER;
	v_numero_seccion INTEGER;
	v_detalle JSONB;
BEGIN
	-- ✅
	IF NULLIF(trim(p_cedula_estudiante), '') IS NULL THEN
		PERFORM academico.fn_lanzar_excepcion(
			'La cédula del estudiante es obligatoria.',
			jsonb_build_object('cedula_estudiante', p_cedula_estudiante),
			'Indique la cédula del estudiante.',
			'MA001'
		);
	END IF;

	SELECT e.id_estudiante
	INTO v_id_estudiante
	FROM academico.estudiantes e
	WHERE e.cedula = trim(p_cedula_estudiante);

	-- ✅	
	IF v_id_estudiante IS NULL THEN
		PERFORM academico.fn_lanzar_excepcion(
			'No existe un estudiante con la cédula indicada.',
			jsonb_build_object('cedula_estudiante', p_cedula_estudiante),
			'Verifique la cédula del estudiante.',
			'MA005'
		);
	END IF;

	PERFORM pg_advisory_xact_lock(v_id_estudiante);

	SELECT m.id_matricula, s.numero_seccion, c.year_ciclo
	INTO v_id_matricula_nivel_10, v_numero_seccion, v_year_ciclo_nivel_10
	FROM academico.matriculas_secciones m
	JOIN academico.secciones s ON s.id_seccion = m.id_seccion
	JOIN academico.cursos_lectivos c ON c.id_curso_lectivo = s.id_curso_lectivo
	WHERE m.id_estudiante = v_id_estudiante
		AND s.nivel = 10
		AND m.estado IN ('EN_SISTEMA', 'ACTIVA', 'FINALIZADA')
	ORDER BY c.year_ciclo DESC, m.id_matricula DESC
	LIMIT 1
	FOR UPDATE OF m;

	-- ✅
	IF v_id_matricula_nivel_10 IS NULL THEN
		PERFORM academico.fn_lanzar_excepcion(
			'El estudiante no tiene una matrícula de nivel 10.',
			jsonb_build_object(
				'id_estudiante', v_id_estudiante
			),
			'Primero debe registrar una matrícula de nivel 10.',
			'MA009'
		);
	END IF;

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
	WHERE m.id_estudiante = v_id_estudiante
		AND s.nivel = 11
	LIMIT 1;

	-- ✅
	IF FOUND THEN
		PERFORM academico.fn_lanzar_excepcion(
			'El estudiante ya tiene una matrícula de nivel 11.',
			jsonb_build_object('matricula_existente', v_detalle),
			'No puede subir nuevamente al nivel 11.',
			'MA010'
		);
	END IF;

	v_year_ciclo_nivel_11 := v_year_ciclo_nivel_10 + 1;

	SELECT s.id_seccion
	INTO v_id_seccion_nivel_11
	FROM academico.secciones s
	JOIN academico.cursos_lectivos c ON c.id_curso_lectivo = s.id_curso_lectivo
	WHERE c.year_ciclo = v_year_ciclo_nivel_11
		AND s.nivel = 11
		AND s.numero_seccion = v_numero_seccion;

	-- ✅ TODO: Mas descriptivo
	IF v_id_seccion_nivel_11 IS NULL THEN
		PERFORM academico.fn_lanzar_excepcion(
			'No existe una sección de nivel 11 correspondiente para el año siguiente.',
			jsonb_build_object(
				'year_ciclo', v_year_ciclo_nivel_11,
				'nivel', 11,
				'numero_seccion', v_numero_seccion
			),
			'Verifique que exista la sección de nivel 11 con el mismo número de sección.',
			'MA011'
		);
	END IF;

	--  opcional si se desea finalizar la matrícula de nivel 10 antes de subir al nivel 11 automáticamente.
	-- CALL academico.finalizar_matricula(v_id_matricula_nivel_10, null);

	INSERT INTO academico.matriculas_secciones (
		id_estudiante,
		id_seccion,
		estado
	)
	VALUES (
		v_id_estudiante,
		v_id_seccion_nivel_11,
		'EN_SISTEMA'
	)
	RETURNING id_matricula INTO p_id_matricula;
END;
$$;

CREATE OR REPLACE FUNCTION academico.obtener_matriculas_estudiante(
	p_cedula_estudiante VARCHAR(20)
)
RETURNS SETOF academico.matricula_estudiante_publica
LANGUAGE plpgsql
AS $$
BEGIN
	--✅
	IF NULLIF(trim(p_cedula_estudiante), '') IS NULL THEN
		PERFORM academico.fn_lanzar_excepcion(
			'La cédula del estudiante es obligatoria.',
			jsonb_build_object('cedula_estudiante', p_cedula_estudiante),
			'Indique la cédula del estudiante.',
			'MA001'
		);
	END IF;

	--✅
	IF NOT EXISTS (
		SELECT 1
		FROM academico.estudiantes e
		WHERE e.cedula = trim(p_cedula_estudiante)
	) THEN
		PERFORM academico.fn_lanzar_excepcion(
			'No existe un estudiante con la cédula indicada.',
			jsonb_build_object('cedula_estudiante', p_cedula_estudiante),
			'Verifique la cédula del estudiante.',
			'MA005'
		);
	END IF;

	RETURN QUERY
    SELECT m.id_matricula, c.year_ciclo, m.id_seccion, s.nivel || '-' || s.numero_seccion as seccion, m.fecha_matricula, m.estado, m.fecha_finalizacion
    FROM academico.matriculas_secciones m
    JOIN academico.secciones s ON s.id_seccion = m.id_seccion
    JOIN academico.cursos_lectivos c ON c.id_curso_lectivo = s.id_curso_lectivo
    JOIN academico.estudiantes e ON e.id_estudiante = m.id_estudiante
    WHERE e.cedula = p_cedula_estudiante;
END;
$$;

CREATE OR REPLACE PROCEDURE academico.borrar_matricula(
    p_id_matricula BIGINT,
    OUT p_id_matricula_borrada BIGINT
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- ✅
    IF p_id_matricula IS NULL THEN
        PERFORM academico.fn_lanzar_excepcion(
			'El ID de matrícula es obligatorio.',
			jsonb_build_object('id_matricula', p_id_matricula),
			'Indique el ID de la matrícula a borrar.',
			'MA012'
		);
    END IF;

    -- ✅
    IF NOT EXISTS (
        SELECT 1
        FROM academico.matriculas_secciones
        WHERE id_matricula = p_id_matricula
    ) THEN
        PERFORM academico.fn_lanzar_excepcion(
			'No existe una matrícula con el ID indicado.',
			jsonb_build_object('id_matricula', p_id_matricula),
			'Verifique el ID de matrícula.',
			'MA013'
		);
    END IF;

    DELETE FROM academico.matriculas_secciones
    WHERE id_matricula = p_id_matricula
    RETURNING id_matricula INTO p_id_matricula_borrada;
END;
$$;