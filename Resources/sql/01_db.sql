----------------------------------------------------------------------------
-- 1 - ROLES AND CONFIG
----------------------------------------------------------------------------
ROLLBACK;
BEGIN;
-- 1) Crear roles de aplicación (NOLOGIN) y cuentas de servicio (LOGIN)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'bi_admin') THEN
        CREATE ROLE bi_admin NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'bi_profesor') THEN
        CREATE ROLE bi_profesor NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'bi_api') THEN
        CREATE ROLE bi_api NOLOGIN;
    END IF;
END;
$$;

-- Crear cuentas LOGIN por portal (cuentas de conexión de la aplicación).
-- NOTA: las contraseñas de ejemplo deben rotarse en despliegue. 
-- las cuentas de conexión de la aplicación no deben ser usadas por personas.
-- no debe quedar en el repositorio ninguna contraseña de producción, ni siquiera cifrada.
DO $$
BEGIN
    DROP ROLE IF EXISTS svc_admin_portal;
    DROP ROLE IF EXISTS svc_profesor_portal;
    DROP ROLE IF EXISTS svc_api;

    CREATE ROLE svc_admin_portal LOGIN PASSWORD '1234';
    CREATE ROLE svc_profesor_portal LOGIN PASSWORD '1234';
    CREATE ROLE svc_api LOGIN PASSWORD '1234';

    GRANT bi_admin TO svc_admin_portal;
    GRANT bi_api TO svc_api;
    GRANT bi_profesor TO svc_profesor_portal;

    COMMENT ON ROLE svc_admin_portal IS 'Cuenta de conexión del backoffice/registro académico. Miembro de bi_admin.';
    COMMENT ON ROLE svc_profesor_portal IS 'Cuenta de conexión del portal docente. Miembro de bi_profesor.';
    COMMENT ON ROLE svc_api IS 'Cuenta de conexión del API. Miembro de bi_api.';
END;
$$;

-- 2) Crear esquemas sin borrar datos u objetos existentes.
DROP SCHEMA IF EXISTS academico CASCADE;
DROP SCHEMA IF EXISTS api CASCADE;
CREATE SCHEMA academico;
CREATE SCHEMA api;

-- 3) Crear extensiones dentro del esquema "academico"
-- Razonamiento: todos los procedimientos SECURITY DEFINER usan
-- SET search_path = pg_catalog, academico, api (sin public).
-- Si las extensiones quedan en public las funciones fallarán en runtime.
CREATE EXTENSION IF NOT EXISTS citext SCHEMA academico;
CREATE EXTENSION IF NOT EXISTS pgcrypto SCHEMA academico;
CREATE EXTENSION IF NOT EXISTS btree_gist SCHEMA academico;

-- 4) Ajuste temporal del search_path para la instalación
-- (esto facilita la definición de columnas que usan CITEXT sin calificar)
SET search_path = academico, public, pg_catalog;

-- 5) Revocar accesos públicos por seguridad
REVOKE ALL ON SCHEMA academico FROM PUBLIC;
REVOKE ALL ON SCHEMA api FROM PUBLIC;

GRANT USAGE ON SCHEMA api TO bi_api, bi_admin, bi_profesor;
GRANT USAGE ON SCHEMA academico TO bi_api, bi_admin, bi_profesor;
GRANT CREATE ON SCHEMA api, academico TO bi_api;

-- Permisos del API sobre el esquema académico.
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA academico TO bi_api;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA academico TO bi_api;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA academico TO bi_api;
GRANT EXECUTE ON ALL PROCEDURES IN SCHEMA academico TO bi_api;

-- Aplicar los mismos permisos a objetos creados por los scripts siguientes.
ALTER DEFAULT PRIVILEGES IN SCHEMA api REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
ALTER DEFAULT PRIVILEGES IN SCHEMA academico GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO bi_api;
ALTER DEFAULT PRIVILEGES IN SCHEMA academico GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO bi_api;
ALTER DEFAULT PRIVILEGES IN SCHEMA academico GRANT EXECUTE ON FUNCTIONS TO bi_api;
COMMIT;

----------------------------------------------------------------------------
-- 2 - SCHEMA TABLES
----------------------------------------------------------------------------
BEGIN;
SET search_path = academico, pg_catalog;
DO $$
BEGIN
    CREATE TYPE academico.roles_profesor AS ENUM ('GUIA','REGULAR','COORD_MONOGRAFIA','COORD_CAS');
    CREATE TYPE academico.tipo_banda AS ENUM ('NUMERICA_1_7','LETRA_A_E','NUMERICA_0_100');
    CREATE TYPE academico.tipo_asignatura AS ENUM ('TRONCAL','SUPERIOR','MEDIO','MEP');
    CREATE TYPE academico.estado_monografia AS ENUM ('CAPACITACION','INVESTIGACION','TERMINADA');
    CREATE TYPE academico.estado_asistencia AS ENUM ('PRESENTE','AUSENTE','TARDIA','JUSTIFICADA');
    CREATE TYPE academico.tipo_reporte AS ENUM ('REPORTE_SECCION','REPORTE_ESTUDIANTE');
    CREATE TYPE academico.numero_semestre AS ENUM ('I_SEMESTRE','II_SEMESTRE');
    CREATE TYPE academico.estado_matricula AS ENUM ('EN_SISTEMA','ACTIVA','FINALIZADA');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
COMMIT;

----------------------------------------------------------------------------
-- 3 - PUBLIC TYPES
----------------------------------------------------------------------------
BEGIN;
DO $$
BEGIN
    CREATE TYPE academico.profesor_publico AS (
        id_profesor BIGINT,
        nombre VARCHAR(100),
        primer_apellido VARCHAR(100),
        segundo_apellido VARCHAR(100),
        cedula VARCHAR(20),
        numero_celular VARCHAR(20),
        email TEXT,
        fecha_nacimiento DATE,
        fecha_registro TIMESTAMPTZ,
        activo BOOLEAN
    );
    CREATE TYPE academico.profesor_login AS (
        email TEXT,
        password_hash VARCHAR(255)
    );
    CREATE TYPE academico.estudiante_publico AS (
        id_estudiante BIGINT,
        nombre VARCHAR(100),
        primer_apellido VARCHAR(100),
        segundo_apellido VARCHAR(100),
        cedula VARCHAR(20),
        numero_celular VARCHAR(20),
        email TEXT,
        fecha_nacimiento DATE,
        fecha_registro TIMESTAMPTZ
    );
    CREATE TYPE academico.curso_lectivo_publico AS (
        id_curso_lectivo BIGINT,
        year_ciclo INTEGER,
        fecha_inicio DATE,
        fecha_fin DATE
    );
    CREATE TYPE academico.seccion_publica AS (
        id_seccion BIGINT,
        year_ciclo INTEGER,
        seccion TEXT
    );
    CREATE TYPE academico.matricula_estudiante_publica AS (
        id_matricula BIGINT,
        year_ciclo INTEGER,
        id_seccion BIGINT,
        seccion TEXT,
        fecha_matricula TIMESTAMPTZ,
        estado academico.estado_matricula,
        fecha_finalizacion TIMESTAMPTZ
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END;
$$;
COMMIT;

-----------------------------------------------------------------------
-- SCHEMA TABLES
-----------------------------------------------------------------------
BEGIN;
-- PROFESORES
CREATE TABLE IF NOT EXISTS academico.profesores (
    id_profesor BIGINT GENERATED ALWAYS AS IDENTITY,
    nombre VARCHAR(100) NOT NULL,
    primer_apellido VARCHAR(100) NOT NULL,
    segundo_apellido VARCHAR(100),
    cedula VARCHAR(20) NOT NULL,
    numero_celular VARCHAR(20),
    email CITEXT NOT NULL,
    fecha_nacimiento DATE NOT NULL,
    fecha_registro TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    password_hash VARCHAR(255) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT pk_profesores PRIMARY KEY (id_profesor),
    CONSTRAINT uq_profesores_cedula UNIQUE (cedula),
    CONSTRAINT uq_profesores_email UNIQUE (email),
    CONSTRAINT ck_profesores_nombre CHECK (length(trim(nombre)) >= 2),
    CONSTRAINT ck_profesores_primer_apellido CHECK (length(trim(primer_apellido)) >= 2),
    CONSTRAINT ck_profesores_cedula CHECK (length(trim(cedula)) >= 5),
    CONSTRAINT ck_profesores_email CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'),
    CONSTRAINT ck_profesores_fecha_nacimiento CHECK (fecha_nacimiento BETWEEN DATE '1900-01-01' AND CURRENT_DATE)
);

-- ESTUDIANTES
CREATE TABLE IF NOT EXISTS academico.estudiantes (
    id_estudiante BIGINT GENERATED ALWAYS AS IDENTITY,
    nombre VARCHAR(100) NOT NULL,
    primer_apellido VARCHAR(100) NOT NULL,
    segundo_apellido VARCHAR(100),
    cedula VARCHAR(20) NOT NULL,
    numero_celular VARCHAR(20),
    email CITEXT NOT NULL,
    fecha_nacimiento DATE NOT NULL,
    fecha_registro TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_estudiantes PRIMARY KEY (id_estudiante),
    CONSTRAINT uq_estudiantes_cedula UNIQUE (cedula),
    CONSTRAINT uq_estudiantes_email UNIQUE (email),
    CONSTRAINT ck_estudiantes_nombre CHECK (length(trim(nombre)) >= 2),
    CONSTRAINT ck_estudiantes_primer_apellido CHECK (length(trim(primer_apellido)) >= 2),
    CONSTRAINT ck_estudiantes_cedula CHECK (length(trim(cedula)) >= 5),
    CONSTRAINT ck_estudiantes_email CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'),
    -- RN: los estudiantes deben tener entre 16 y 19 años al momento de la inscripción.
    CONSTRAINT ck_estudiantes_edad_16_19 CHECK (fecha_nacimiento BETWEEN (CURRENT_DATE - INTERVAL '19 years') AND (CURRENT_DATE - INTERVAL '16 years'))
);

-- CURSOS_LECTIVOS
CREATE TABLE IF NOT EXISTS academico.cursos_lectivos (
    id_curso_lectivo BIGINT GENERATED ALWAYS AS IDENTITY,
    year_ciclo INTEGER NOT NULL,
    fecha_inicio DATE NOT NULL,
    fecha_fin DATE NOT NULL,
    CONSTRAINT pk_cursos_lectivos PRIMARY KEY (id_curso_lectivo),
    -- RN: el año del ciclo lectivo debe ser único.
    CONSTRAINT uq_cursos_lectivos_year_ciclo UNIQUE (year_ciclo),
    CONSTRAINT ck_cursos_lectivos_fechas CHECK (fecha_fin > fecha_inicio),
    -- RN: el año del ciclo lectivo debe coincidir con el año de las fechas de inicio y fin.
    CONSTRAINT ck_cursos_lectivos_rango_fechas_en_year CHECK (
        year_ciclo = EXTRACT(YEAR FROM fecha_inicio)
        AND year_ciclo = EXTRACT(YEAR FROM fecha_fin)
    )
);
-- IDX: year_ciclo - útil para reportes por año.
CREATE INDEX IF NOT EXISTS ix_cursos_lectivos_year ON academico.cursos_lectivos(year_ciclo);

-- SEMESTRES
CREATE TABLE IF NOT EXISTS academico.semestres (
    id_semestre BIGINT GENERATED ALWAYS AS IDENTITY,
    id_curso_lectivo BIGINT NOT NULL,
    numero_semestre academico.numero_semestre NOT NULL DEFAULT 'I_SEMESTRE',
    fecha_inicio DATE NOT NULL,
    fecha_fin DATE NOT NULL,
    CONSTRAINT pk_semestres PRIMARY KEY (id_semestre),
    CONSTRAINT fk_semestres_curso FOREIGN KEY (id_curso_lectivo)
        REFERENCES academico.cursos_lectivos(id_curso_lectivo) ON DELETE RESTRICT,
    CONSTRAINT uq_semestres_curso_numero UNIQUE (id_curso_lectivo, numero_semestre),
    CONSTRAINT ck_semestres_fechas CHECK (fecha_fin >= fecha_inicio)
);
-- IDX: id_curso_lectivo - útil para reportes por curso lectivo.
CREATE INDEX IF NOT EXISTS ix_semestres_curso ON academico.semestres(id_curso_lectivo);

-- SECCIONES
CREATE TABLE IF NOT EXISTS academico.secciones (
    id_seccion BIGINT GENERATED ALWAYS AS IDENTITY,
    id_curso_lectivo BIGINT NOT NULL,
    nivel INTEGER NOT NULL,
    numero_seccion INTEGER NOT NULL,
    CONSTRAINT pk_secciones PRIMARY KEY (id_seccion),
    CONSTRAINT fk_secciones_curso FOREIGN KEY (id_curso_lectivo)
        REFERENCES academico.cursos_lectivos(id_curso_lectivo) ON DELETE RESTRICT,
    CONSTRAINT uq_seccion_curso_nivel_numero_seccion UNIQUE (id_curso_lectivo, nivel, numero_seccion),
    -- RN: el nivel de la sección debe ser 10 o 11.
    CONSTRAINT ck_secciones_nivel CHECK (nivel IN (10, 11)),
    CONSTRAINT ck_secciones_numero_seccion CHECK (numero_seccion > 0)
);
-- IDX: id_curso_lectivo - útil para reportes por curso lectivo.
CREATE INDEX IF NOT EXISTS ix_secciones_curso ON academico.secciones(id_curso_lectivo);

-- MATRICULAS_SECCIONES
CREATE TABLE IF NOT EXISTS academico.matriculas_secciones (
    id_matricula BIGINT GENERATED ALWAYS AS IDENTITY,
    id_estudiante BIGINT NOT NULL,
    id_seccion BIGINT NOT NULL,
    fecha_matricula TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_finalizacion TIMESTAMPTZ,
    estado academico.estado_matricula NOT NULL DEFAULT 'EN_SISTEMA',
    CONSTRAINT pk_matriculas PRIMARY KEY (id_matricula),
    CONSTRAINT fk_matriculas_estudiante FOREIGN KEY (id_estudiante)
        REFERENCES academico.estudiantes(id_estudiante) ON DELETE RESTRICT,
    CONSTRAINT fk_matriculas_seccion FOREIGN KEY (id_seccion)
        REFERENCES academico.secciones(id_seccion) ON DELETE RESTRICT,
    -- RN: si la fecha de finalización está presente, entonces el estado debe ser 'FINALIZADA'.
    CONSTRAINT ck_matriculas_fecha_finalizacion CHECK (fecha_finalizacion IS NULL OR estado = 'FINALIZADA'),
    -- RN: una matrícula no puede tener una fecha de finalización en el futuro.
    CONSTRAINT ck_matriculas_fecha_finalizacion_futura CHECK (fecha_finalizacion IS NULL OR fecha_finalizacion <= CURRENT_TIMESTAMP),
    CONSTRAINT uq_matriculas_estudiante_seccionn UNIQUE (id_estudiante, id_seccion)
);
-- IDX: id_estudiante - útil para reportes por estudiante.
CREATE INDEX IF NOT EXISTS ix_matriculas_estudiante ON academico.matriculas_secciones(id_estudiante);
--- IDX: id_seccion - útil para reportes por sección.
CREATE INDEX IF NOT EXISTS ix_matriculas_seccion ON academico.matriculas_secciones(id_seccion);
-- IDX: (id_estudiante, fecha_matricula DESC) - útil para reportes de historial de matrícula por estudiante.
CREATE INDEX IF NOT EXISTS ix_matriculas_estudiante_fecha ON academico.matriculas_secciones(id_estudiante, fecha_matricula DESC);

-- ASIGNATURAS
CREATE TABLE IF NOT EXISTS academico.asignaturas (
    id_asignatura BIGINT GENERATED ALWAYS AS IDENTITY,
    codigo VARCHAR(3) NOT NULL,
    tipo_asignatura academico.tipo_asignatura NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    descripcion VARCHAR(255),
    -- RN: la banda de calificación depende del tipo de asignatura.
    tipo_banda academico.tipo_banda GENERATED ALWAYS AS (
        CASE tipo_asignatura
            WHEN 'TRONCAL' THEN 'LETRA_A_E'::academico.tipo_banda
            WHEN 'MEP' THEN 'NUMERICA_0_100'::academico.tipo_banda
            ELSE 'NUMERICA_1_7'::academico.tipo_banda
        END
    ) STORED,
    -- RN: solo las asignaturas superiores y medias pueden elegirse para monografía.
    permite_monografia BOOLEAN GENERATED ALWAYS AS (
        tipo_asignatura IN ('SUPERIOR', 'MEDIO')
    ) STORED,
    CONSTRAINT pk_asignaturas PRIMARY KEY (id_asignatura),
    CONSTRAINT uq_asignaturas_codigo UNIQUE (codigo),
    CONSTRAINT uq_asignaturas_nombre UNIQUE (nombre),
    CONSTRAINT ck_asignaturas_nombre CHECK (length(trim(nombre)) >= 2)
);

COMMIT;