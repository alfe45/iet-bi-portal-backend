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
-- Estado derivado (no se guarda): RETIRADA si tiene retiro; si no, según el estado del periodo.
CREATE TYPE academico.estado_matricula AS ENUM ('PROGRAMADA','ACTIVA','FINALIZADA','RETIRADA');

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
    CONSTRAINT ck_profesores_fecha_nacimiento CHECK (fecha_nacimiento >= DATE '1900-01-01')   -- "no futura": api.fn_validar_fecha_nacimiento (PR005)
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

-- PERIODOS ACADÉMICOS: un periodo por año con sus dos semestres. Se opera por año (clave natural).
-- Reglas fijas como CHECK; las que dependen de la fecha actual (estado, cierres) en 09_admin_periodos.sql.
CREATE TYPE academico.estado_periodo AS ENUM ('PROGRAMADO','EN_CURSO','FINALIZADO');

CREATE TABLE academico.periodos_academicos (
    id_periodo BIGINT GENERATED ALWAYS AS IDENTITY,
    anio INTEGER NOT NULL,
    inicio_semestre_i DATE NOT NULL,
    fin_semestre_i DATE NOT NULL,
    inicio_semestre_ii DATE NOT NULL,
    fin_semestre_ii DATE NOT NULL,
    CONSTRAINT pk_periodos_academicos PRIMARY KEY (id_periodo),
    CONSTRAINT uq_periodos_academicos_anio UNIQUE (anio),
    CONSTRAINT ck_periodos_academicos_anio CHECK (anio BETWEEN 2000 AND 2100),
    CONSTRAINT ck_periodos_academicos_orden CHECK (
        inicio_semestre_i < fin_semestre_i
        AND fin_semestre_i < inicio_semestre_ii
        AND inicio_semestre_ii < fin_semestre_ii),
    CONSTRAINT ck_periodos_academicos_en_anio CHECK (
        EXTRACT(YEAR FROM inicio_semestre_i) = anio
        AND EXTRACT(YEAR FROM fin_semestre_ii) = anio)
);

-- SECCIONES: grupo de un nivel (10 u 11) dentro de un periodo. Se opera por (año, nivel, número), ej. 2026 "10-1".
-- Un guía como máximo por sección y un profesor es guía de una sola sección por periodo.
CREATE TABLE academico.secciones (
    id_seccion BIGINT GENERATED ALWAYS AS IDENTITY,
    id_periodo BIGINT NOT NULL,
    nivel SMALLINT NOT NULL,
    numero SMALLINT NOT NULL,
    id_profesor_guia BIGINT NULL,
    CONSTRAINT pk_secciones PRIMARY KEY (id_seccion),
    CONSTRAINT fk_secciones_periodo FOREIGN KEY (id_periodo) REFERENCES academico.periodos_academicos(id_periodo) ON DELETE RESTRICT,
    CONSTRAINT fk_secciones_profesor_guia FOREIGN KEY (id_profesor_guia) REFERENCES academico.profesores(id_profesor) ON DELETE RESTRICT,
    CONSTRAINT uq_secciones_periodo_nivel_numero UNIQUE (id_periodo, nivel, numero),
    CONSTRAINT uq_secciones_id_periodo UNIQUE (id_seccion, id_periodo),   -- destino de FKs compuestas (matrículas)
    CONSTRAINT uq_secciones_periodo_guia UNIQUE (id_periodo, id_profesor_guia),
    CONSTRAINT ck_secciones_nivel CHECK (nivel IN (10, 11)),
    CONSTRAINT ck_secciones_numero CHECK (numero BETWEEN 1 AND 99)
);
CREATE INDEX ix_secciones_profesor_guia ON academico.secciones(id_profesor_guia);

-- ASIGNATURAS: catálogo global. Se opera por código (clave natural, inmutable).
-- Los niveles en que se imparte son datos (RN-39: Cívica y Estudios Sociales solo en 10).
CREATE TABLE academico.asignaturas (
    id_asignatura BIGINT GENERATED ALWAYS AS IDENTITY,
    codigo VARCHAR(10) NOT NULL,
    nombre CITEXT NOT NULL,
    tipo academico.tipo_asignatura NOT NULL,
    descripcion VARCHAR(255),
    imparte_nivel_10 BOOLEAN NOT NULL,
    imparte_nivel_11 BOOLEAN NOT NULL,
    CONSTRAINT pk_asignaturas PRIMARY KEY (id_asignatura),
    CONSTRAINT uq_asignaturas_codigo UNIQUE (codigo),
    CONSTRAINT uq_asignaturas_nombre UNIQUE (nombre),
    CONSTRAINT ck_asignaturas_codigo CHECK (codigo ~ '^[A-Z0-9]{2,10}$'),
    CONSTRAINT ck_asignaturas_nombre CHECK (length(trim(nombre)) BETWEEN 2 AND 100),
    CONSTRAINT ck_asignaturas_niveles CHECK (imparte_nivel_10 OR imparte_nivel_11)
);

-- ASIGNACIONES DOCENTES: profesor que imparte una asignatura en una sección. Puede haber varios
-- profesores para la misma asignatura y sección (co-docencia). Se opera por claves naturales:
-- (año, nivel, número de sección, código de asignatura, cédula del profesor).
CREATE TABLE academico.asignaciones_docentes (
    id_asignacion BIGINT GENERATED ALWAYS AS IDENTITY,
    id_seccion BIGINT NOT NULL,
    id_asignatura BIGINT NOT NULL,
    id_profesor BIGINT NOT NULL,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_asignaciones_docentes PRIMARY KEY (id_asignacion),
    CONSTRAINT fk_asignaciones_seccion FOREIGN KEY (id_seccion) REFERENCES academico.secciones(id_seccion) ON DELETE RESTRICT,
    CONSTRAINT fk_asignaciones_asignatura FOREIGN KEY (id_asignatura) REFERENCES academico.asignaturas(id_asignatura) ON DELETE RESTRICT,
    CONSTRAINT fk_asignaciones_profesor FOREIGN KEY (id_profesor) REFERENCES academico.profesores(id_profesor) ON DELETE RESTRICT,
    CONSTRAINT uq_asignaciones_seccion_asignatura_profesor UNIQUE (id_seccion, id_asignatura, id_profesor)
);
CREATE INDEX ix_asignaciones_profesor ON academico.asignaciones_docentes(id_profesor);
CREATE INDEX ix_asignaciones_asignatura ON academico.asignaciones_docentes(id_asignatura);

-- MATRÍCULAS: un estudiante en una sección de un periodo; una sola matrícula por estudiante y periodo.
-- id_periodo se guarda para garantizar esa unicidad; la FK compuesta asegura que coincide con la sección.
-- El estado no se guarda: se deriva del retiro y de las fechas del periodo (academico.fn_estado_matricula).
CREATE TABLE academico.matriculas (
    id_matricula BIGINT GENERATED ALWAYS AS IDENTITY,
    id_estudiante BIGINT NOT NULL,
    id_periodo BIGINT NOT NULL,
    id_seccion BIGINT NOT NULL,
    fecha_matricula DATE NOT NULL,
    fecha_retiro DATE NULL,
    motivo_retiro VARCHAR(255) NULL,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_matriculas PRIMARY KEY (id_matricula),
    CONSTRAINT fk_matriculas_estudiante FOREIGN KEY (id_estudiante) REFERENCES academico.estudiantes(id_estudiante) ON DELETE RESTRICT,
    CONSTRAINT fk_matriculas_seccion_periodo FOREIGN KEY (id_seccion, id_periodo)
        REFERENCES academico.secciones(id_seccion, id_periodo) ON DELETE RESTRICT,
    CONSTRAINT uq_matriculas_estudiante_periodo UNIQUE (id_estudiante, id_periodo),
    CONSTRAINT ck_matriculas_retiro CHECK (fecha_retiro IS NULL OR fecha_retiro >= fecha_matricula),
    CONSTRAINT ck_matriculas_motivo_sin_retiro CHECK (fecha_retiro IS NOT NULL OR motivo_retiro IS NULL)
);
CREATE INDEX ix_matriculas_seccion ON academico.matriculas(id_seccion);
