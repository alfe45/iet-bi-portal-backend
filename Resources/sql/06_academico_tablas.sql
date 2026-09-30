-- ============================================================
-- 06_academico_tablas.sql: ENUMS Y TABLAS DEL ESQUEMA academico
-- La cédula es la clave natural con la que se opera (API); id_* es PK interna y nunca se expone.
-- ============================================================
SET search_path = academico, auth, api, public, pg_catalog;

-- El tipo de asignatura define la escala de la nota (RN-73): SUPERIOR y MEDIO bandas 1 a 7, TRONCAL letras A a E, MEP 0 a 100.
CREATE TYPE academico.tipo_asignatura AS ENUM ('TRONCAL','SUPERIOR','MEDIO','MEP');
CREATE TYPE academico.estado_monografia AS ENUM ('CAPACITACION','INVESTIGACION','TERMINADA');
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

-- LECCIONES: clase que el profesor de una asignación registra cuando la imparte (no depende de un horario).
-- Se identifica por id_leccion (RP-53): la fecha y la hora se pueden corregir. Reglas que dependen de la
-- fecha actual (fecha no futura, semestre abierto) en 14_ausentismo.sql.
CREATE TABLE academico.lecciones (
    id_leccion BIGINT GENERATED ALWAYS AS IDENTITY,
    id_asignacion BIGINT NOT NULL,
    fecha DATE NOT NULL,
    hora TIME NOT NULL,
    tema VARCHAR(255) NULL,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_lecciones PRIMARY KEY (id_leccion),
    CONSTRAINT fk_lecciones_asignacion FOREIGN KEY (id_asignacion) REFERENCES academico.asignaciones_docentes(id_asignacion) ON DELETE RESTRICT,
    CONSTRAINT uq_lecciones_asignacion_fecha_hora UNIQUE (id_asignacion, fecha, hora)
);

-- AUSENCIAS: solo se guardan los ausentes y las llegadas tardías de cada lección (el resto de los matriculados
-- estuvo presente). tardia = llegó tarde (no se justifica); si no, es ausencia y justificacion NULL = injustificada.
-- Borrar la lección borra sus ausencias; una matrícula con ausencias no se borra.
CREATE TABLE academico.ausencias (
    id_leccion BIGINT NOT NULL,
    id_matricula BIGINT NOT NULL,
    tardia BOOLEAN NOT NULL DEFAULT FALSE,
    justificacion VARCHAR(255) NULL,
    justificada_en TIMESTAMPTZ NULL,
    CONSTRAINT pk_ausencias PRIMARY KEY (id_leccion, id_matricula),
    CONSTRAINT fk_ausencias_leccion FOREIGN KEY (id_leccion) REFERENCES academico.lecciones(id_leccion) ON DELETE CASCADE,
    CONSTRAINT fk_ausencias_matricula FOREIGN KEY (id_matricula) REFERENCES academico.matriculas(id_matricula) ON DELETE RESTRICT,
    CONSTRAINT ck_ausencias_justificacion CHECK (justificacion IS NULL OR length(trim(justificacion)) >= 3),
    CONSTRAINT ck_ausencias_justificada_en CHECK ((justificacion IS NULL) = (justificada_en IS NULL)),
    CONSTRAINT ck_ausencias_tardia_sin_justificacion CHECK (NOT tardia OR justificacion IS NULL)
);
CREATE INDEX ix_ausencias_matricula ON academico.ausencias(id_matricula);

-- EVALUACIONES: nota semestral de un estudiante (matrícula) en una asignación (RN-73). La nota se guarda como
-- texto normalizado ('1'..'7', 'A'..'E' o '0'..'100'); la escala según el tipo de asignatura la valida
-- 15_evaluaciones.sql (EV001). observaciones = observaciones del profesor (Profesor Regular CU09).
CREATE TABLE academico.evaluaciones (
    id_evaluacion BIGINT GENERATED ALWAYS AS IDENTITY,
    id_asignacion BIGINT NOT NULL,
    id_matricula BIGINT NOT NULL,
    semestre academico.numero_semestre NOT NULL,
    nota VARCHAR(3) NOT NULL,
    observaciones VARCHAR(500) NULL,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    modificado_en TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_evaluaciones PRIMARY KEY (id_evaluacion),
    CONSTRAINT fk_evaluaciones_asignacion FOREIGN KEY (id_asignacion) REFERENCES academico.asignaciones_docentes(id_asignacion) ON DELETE RESTRICT,
    CONSTRAINT fk_evaluaciones_matricula FOREIGN KEY (id_matricula) REFERENCES academico.matriculas(id_matricula) ON DELETE RESTRICT,
    CONSTRAINT uq_evaluaciones_asignacion_matricula_semestre UNIQUE (id_asignacion, id_matricula, semestre),
    CONSTRAINT ck_evaluaciones_nota CHECK (nota ~ '^([A-E]|[0-9]|[1-9][0-9]|100)$'),
    CONSTRAINT ck_evaluaciones_observaciones CHECK (observaciones IS NULL OR length(trim(observaciones)) >= 3)
);
CREATE INDEX ix_evaluaciones_matricula ON academico.evaluaciones(id_matricula);

-- ENVÍOS DE NOTAS: el profesor envió al guía las notas de su asignación en el semestre (RN-75). El guía y el
-- reporte de bandas solo ven notas enviadas. Es una marca de la asignación: se borra con ella.
CREATE TABLE academico.envios_notas (
    id_asignacion BIGINT NOT NULL,
    semestre academico.numero_semestre NOT NULL,
    enviado_en TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_envios_notas PRIMARY KEY (id_asignacion, semestre),
    CONSTRAINT fk_envios_notas_asignacion FOREIGN KEY (id_asignacion) REFERENCES academico.asignaciones_docentes(id_asignacion) ON DELETE CASCADE
);

-- PRÓRROGAS: más tiempo que el ADMIN da a un profesor para enviar y corregir notas de un semestre (RN-74).
-- Sin prórroga, el cierre es la fecha de fin del semestre.
CREATE TABLE academico.prorrogas (
    id_profesor BIGINT NOT NULL,
    id_periodo BIGINT NOT NULL,
    semestre academico.numero_semestre NOT NULL,
    fecha_limite DATE NOT NULL,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_prorrogas PRIMARY KEY (id_profesor, id_periodo, semestre),
    CONSTRAINT fk_prorrogas_profesor FOREIGN KEY (id_profesor) REFERENCES academico.profesores(id_profesor) ON DELETE CASCADE,
    CONSTRAINT fk_prorrogas_periodo FOREIGN KEY (id_periodo) REFERENCES academico.periodos_academicos(id_periodo) ON DELETE CASCADE
);

-- MONOGRAFÍAS: una por estudiante; empieza con su matrícula de nivel 10 y sigue en su nivel 11 (RN-78). Un
-- coordinador la tutela en una materia SUPERIOR o MEDIO. Se opera por la cédula del estudiante.
CREATE TABLE academico.monografias (
    id_monografia BIGINT GENERATED ALWAYS AS IDENTITY,
    id_estudiante BIGINT NOT NULL,
    id_matricula_inicio BIGINT NOT NULL,
    id_coordinador BIGINT NOT NULL,
    id_asignatura BIGINT NOT NULL,
    estado academico.estado_monografia NOT NULL DEFAULT 'CAPACITACION',
    creado_en TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_monografias PRIMARY KEY (id_monografia),
    CONSTRAINT fk_monografias_estudiante FOREIGN KEY (id_estudiante) REFERENCES academico.estudiantes(id_estudiante) ON DELETE RESTRICT,
    CONSTRAINT fk_monografias_matricula FOREIGN KEY (id_matricula_inicio) REFERENCES academico.matriculas(id_matricula) ON DELETE RESTRICT,
    CONSTRAINT fk_monografias_coordinador FOREIGN KEY (id_coordinador) REFERENCES academico.profesores(id_profesor) ON DELETE RESTRICT,
    CONSTRAINT fk_monografias_asignatura FOREIGN KEY (id_asignatura) REFERENCES academico.asignaturas(id_asignatura) ON DELETE RESTRICT,
    CONSTRAINT uq_monografias_estudiante UNIQUE (id_estudiante)
);
CREATE INDEX ix_monografias_coordinador ON academico.monografias(id_coordinador);

-- SEGUIMIENTO DE MONOGRAFÍAS: observaciones fechadas del coordinador (RN-80). Se identifican por id.
CREATE TABLE academico.seguimientos_monografia (
    id_seguimiento BIGINT GENERATED ALWAYS AS IDENTITY,
    id_monografia BIGINT NOT NULL,
    fecha DATE NOT NULL,
    observacion VARCHAR(1000) NOT NULL,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_seguimientos_monografia PRIMARY KEY (id_seguimiento),
    CONSTRAINT fk_seguimientos_monografia FOREIGN KEY (id_monografia) REFERENCES academico.monografias(id_monografia) ON DELETE RESTRICT,
    CONSTRAINT ck_seguimientos_observacion CHECK (length(trim(observacion)) >= 3)
);
CREATE INDEX ix_seguimientos_monografia ON academico.seguimientos_monografia(id_monografia);

-- REPORTES DE MONOGRAFÍA: observaciones semestrales que el coordinador envía al guía (RN-81); salen en el
-- reporte de bandas del estudiante.
CREATE TABLE academico.reportes_monografia (
    id_monografia BIGINT NOT NULL,
    id_periodo BIGINT NOT NULL,
    semestre academico.numero_semestre NOT NULL,
    observaciones VARCHAR(1000) NOT NULL,
    enviado_en TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_reportes_monografia PRIMARY KEY (id_monografia, id_periodo, semestre),
    CONSTRAINT fk_reportes_monografia FOREIGN KEY (id_monografia) REFERENCES academico.monografias(id_monografia) ON DELETE RESTRICT,
    CONSTRAINT fk_reportes_monografia_periodo FOREIGN KEY (id_periodo) REFERENCES academico.periodos_academicos(id_periodo) ON DELETE RESTRICT,
    CONSTRAINT ck_reportes_monografia_observaciones CHECK (length(trim(observaciones)) >= 3)
);

-- INFORMES CAS: informe semestral del profesor CAS por estudiante (RN-83). Comparte la clave de la nota
-- (asignación CAS, matrícula, semestre): así el informe "apunta" a la nota CAS del estudiante.
-- perfil y entrevistas: lo que el estudiante lleva cumplido hasta ese semestre.
CREATE TABLE academico.informes_cas (
    id_informe BIGINT GENERATED ALWAYS AS IDENTITY,
    id_asignacion BIGINT NOT NULL,
    id_matricula BIGINT NOT NULL,
    semestre academico.numero_semestre NOT NULL,
    perfil BOOLEAN NOT NULL DEFAULT FALSE,
    entrevista_1 BOOLEAN NOT NULL DEFAULT FALSE,
    entrevista_2 BOOLEAN NOT NULL DEFAULT FALSE,
    entrevista_final BOOLEAN NOT NULL DEFAULT FALSE,
    observaciones VARCHAR(2000) NULL,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    modificado_en TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_informes_cas PRIMARY KEY (id_informe),
    CONSTRAINT fk_informes_cas_asignacion FOREIGN KEY (id_asignacion) REFERENCES academico.asignaciones_docentes(id_asignacion) ON DELETE RESTRICT,
    CONSTRAINT fk_informes_cas_matricula FOREIGN KEY (id_matricula) REFERENCES academico.matriculas(id_matricula) ON DELETE RESTRICT,
    CONSTRAINT uq_informes_cas_asignacion_matricula_semestre UNIQUE (id_asignacion, id_matricula, semestre)
);
CREATE INDEX ix_informes_cas_matricula ON academico.informes_cas(id_matricula);

-- EXPERIENCIAS CAS: filas del informe (proyecto, serie de experiencias o experiencia), en el orden del formato.
-- resultados_aprendizaje: cuáles de los 7 resultados de aprendizaje CAS cumple.
CREATE TABLE academico.experiencias_cas (
    id_informe BIGINT NOT NULL,
    orden SMALLINT NOT NULL,
    descripcion VARCHAR(255) NOT NULL,
    fecha DATE NULL,
    creatividad BOOLEAN NOT NULL DEFAULT FALSE,
    actividad BOOLEAN NOT NULL DEFAULT FALSE,
    servicio BOOLEAN NOT NULL DEFAULT FALSE,
    resultados_aprendizaje SMALLINT[] NOT NULL DEFAULT '{}',
    carpeta BOOLEAN NOT NULL DEFAULT FALSE,
    reflexion BOOLEAN NOT NULL DEFAULT FALSE,
    pruebas BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT pk_experiencias_cas PRIMARY KEY (id_informe, orden),
    CONSTRAINT fk_experiencias_cas_informe FOREIGN KEY (id_informe) REFERENCES academico.informes_cas(id_informe) ON DELETE CASCADE,
    CONSTRAINT ck_experiencias_cas_orden CHECK (orden BETWEEN 1 AND 30),
    CONSTRAINT ck_experiencias_cas_descripcion CHECK (length(trim(descripcion)) >= 3),
    CONSTRAINT ck_experiencias_cas_resultados CHECK (resultados_aprendizaje <@ ARRAY[1,2,3,4,5,6,7]::SMALLINT[])
);
