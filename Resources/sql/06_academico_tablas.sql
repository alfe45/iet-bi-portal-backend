-- ============================================================
-- 06_academico_tablas.sql: ENUMS Y TABLAS DEL ESQUEMA academico
-- La cédula es la clave natural con la que se opera (API); id_* es PK interna y nunca se expone.
-- ============================================================
SET search_path = academico, auth, api, public, pg_catalog;

CREATE TYPE academico.tipo_banda AS ENUM ('NUMERICA_1_7','LETRA_A_E','NUMERICA_0_100');
CREATE TYPE academico.tipo_asignatura AS ENUM ('TRONCAL','SUPERIOR','MEDIO','MEP');
CREATE TYPE academico.estado_monografia AS ENUM ('CAPACITACION','INVESTIGACION','TERMINADA');
CREATE TYPE academico.estado_asistencia AS ENUM ('PRESENTE','AUSENTE','TARDIA','JUSTIFICADA');
CREATE TYPE academico.tipo_reporte AS ENUM ('REPORTE_SECCION','REPORTE_ESTUDIANTE');
CREATE TYPE academico.numero_semestre AS ENUM ('I_SEMESTRE','II_SEMESTRE');
CREATE TYPE academico.estado_matricula AS ENUM ('EN_SISTEMA','ACTIVA','FINALIZADA');

-- PROFESORES: perfil académico de un usuario (1 usuario -> 0..1 profesor)
CREATE TABLE academico.profesores (
    id_profesor BIGINT GENERATED ALWAYS AS IDENTITY,
    nombre VARCHAR(100) NOT NULL,
    primer_apellido VARCHAR(100) NOT NULL,
    segundo_apellido VARCHAR(100),
    cedula VARCHAR(20) NOT NULL,
    numero_celular VARCHAR(20),
    fecha_nacimiento DATE NOT NULL,
    id_usuario UUID NOT NULL,
    CONSTRAINT pk_profesores PRIMARY KEY (id_profesor),
    CONSTRAINT fk_profesores_usuario FOREIGN KEY (id_usuario) REFERENCES api.usuarios(id_usuario) ON DELETE RESTRICT,
    CONSTRAINT uq_profesores_usuario UNIQUE (id_usuario),
    CONSTRAINT uq_profesores_cedula UNIQUE (cedula),
    CONSTRAINT ck_profesores_nombre CHECK (length(trim(nombre)) >= 2),
    CONSTRAINT ck_profesores_primer_apellido CHECK (length(trim(primer_apellido)) >= 2),
    CONSTRAINT ck_profesores_cedula CHECK (cedula ~ '^[A-Za-z0-9-]{5,20}$'),
    CONSTRAINT ck_profesores_fecha_nacimiento CHECK (fecha_nacimiento BETWEEN DATE '1900-01-01' AND CURRENT_DATE)
);

-- ESTUDIANTES (la regla de edad depende de la fecha actual: la valida academico.fn_validar_edad_estudiante)
CREATE TABLE academico.estudiantes (
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
    CONSTRAINT ck_estudiantes_cedula CHECK (cedula ~ '^[A-Za-z0-9-]{5,20}$'),
    CONSTRAINT ck_estudiantes_email CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
);
