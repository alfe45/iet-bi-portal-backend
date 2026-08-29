-- name=schema_tables.sql
-- Modelo relacional: tipos controlados, tablas y constraints.
-- Incluye comentarios que explican las reglas de negocio implementadas.
-- El llamador controla la transaccion; este archivo no hace ROLLBACK implicito.
BEGIN;

SET search_path = academico, pg_catalog;

DO $$
BEGIN
    CREATE TYPE academico.tipo_profesor AS ENUM ('GUIA','REGULAR','COORD_MONOGRAFIA');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$
BEGIN
    CREATE TYPE academico.tipo_banda AS ENUM ('NUMERICA','LETRA');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$
BEGIN
    CREATE TYPE academico.estado_monografia AS ENUM ('CAPACITACION','INVESTIGACION','CERRADA','CANCELADA');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$
BEGIN
    CREATE TYPE academico.estado_asistencia AS ENUM ('PRESENTE','AUSENTE','TARDANZA','JUSTIFICADA');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$
BEGIN
    CREATE TYPE academico.tipo_reporte AS ENUM ('REPORTE_SECCION');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- 05. USUARIOS Y HERENCIA XOR
CREATE TABLE IF NOT EXISTS academico.usuarios (
    id_usuario BIGINT GENERATED ALWAYS AS IDENTITY,
    nombre VARCHAR(100) NOT NULL,
    primer_apellido VARCHAR(100) NOT NULL,
    segundo_apellido VARCHAR(100),
    cedula VARCHAR(20) NOT NULL,
    numero_celular VARCHAR(20),
    email CITEXT NOT NULL,
    fecha_nacimiento DATE NOT NULL,
    fecha_registro TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    password_hash VARCHAR(255) NOT NULL,
    correo_verificado BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT pk_usuarios PRIMARY KEY (id_usuario),
    CONSTRAINT uq_usuarios_cedula UNIQUE (cedula),
    CONSTRAINT uq_usuarios_email UNIQUE (email),
    CONSTRAINT ck_usuarios_nombre CHECK (length(trim(nombre)) >= 2),
    CONSTRAINT ck_usuarios_primer_apellido CHECK (length(trim(primer_apellido)) >= 2),
    CONSTRAINT ck_usuarios_cedula CHECK (length(trim(cedula)) >= 5),
    CONSTRAINT ck_usuarios_email CHECK (
        email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'
    ),
    CONSTRAINT ck_usuarios_fecha_nacimiento CHECK (
        fecha_nacimiento BETWEEN DATE '1900-01-01' AND CURRENT_DATE
    )
);

CREATE TABLE IF NOT EXISTS academico.profesores (
    id_usuario BIGINT NOT NULL,
    CONSTRAINT pk_profesores PRIMARY KEY (id_usuario),
    CONSTRAINT fk_profesores_usuario FOREIGN KEY (id_usuario)
        REFERENCES academico.usuarios(id_usuario) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS academico.estudiantes (
    id_usuario BIGINT NOT NULL,
    fotografia_url VARCHAR(500),
    CONSTRAINT pk_estudiantes PRIMARY KEY (id_usuario),
    CONSTRAINT fk_estudiantes_usuario FOREIGN KEY (id_usuario)
        REFERENCES academico.usuarios(id_usuario) ON DELETE RESTRICT
);

-- profeso_roles puente (permite acumular tipos)
CREATE TABLE IF NOT EXISTS academico.profesor_roles (
    id_profesor BIGINT NOT NULL,
    tipo academico.tipo_profesor NOT NULL,
    fecha_asignacion DATE NOT NULL DEFAULT CURRENT_DATE,
    fecha_fin DATE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT pk_profesor_roles PRIMARY KEY (id_profesor, tipo),
    CONSTRAINT fk_profesor_roles_profesor FOREIGN KEY (id_profesor)
        REFERENCES academico.profesores(id_usuario) ON DELETE RESTRICT,
    CONSTRAINT ck_profesor_roles_fechas CHECK (
        fecha_fin IS NULL OR fecha_fin >= fecha_asignacion
    )
);
CREATE INDEX IF NOT EXISTS ix_profesor_roles_tipo_activo
    ON academico.profesor_roles(tipo, activo);

-- 06. PERÍODOS ACADÉMICOS
CREATE TABLE IF NOT EXISTS academico.cursos_lectivos (
    id_curso_lectivo BIGINT GENERATED ALWAYS AS IDENTITY,
    nombre VARCHAR(100) NOT NULL,
    fecha_inicio DATE NOT NULL,
    fecha_fin DATE NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT pk_cursos_lectivos PRIMARY KEY (id_curso_lectivo),
    CONSTRAINT uq_cursos_lectivos_nombre UNIQUE (nombre),
    CONSTRAINT ck_cursos_lectivos_fechas CHECK (fecha_fin > fecha_inicio)
);

CREATE TABLE IF NOT EXISTS academico.semestres (
    id_semestre BIGINT GENERATED ALWAYS AS IDENTITY,
    id_curso_lectivo BIGINT NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    fecha_inicio DATE NOT NULL,
    fecha_fin DATE NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT pk_semestres PRIMARY KEY (id_semestre),
    CONSTRAINT fk_semestres_curso FOREIGN KEY (id_curso_lectivo)
        REFERENCES academico.cursos_lectivos(id_curso_lectivo) ON DELETE RESTRICT,
    CONSTRAINT uq_semestres_curso_nombre UNIQUE (id_curso_lectivo, nombre),
    CONSTRAINT ck_semestres_fechas CHECK (fecha_fin >= fecha_inicio)
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_semestre_activo_por_curso
    ON academico.semestres(id_curso_lectivo)
    WHERE activo = TRUE;
CREATE INDEX IF NOT EXISTS ix_semestres_curso ON academico.semestres(id_curso_lectivo);

-- 07. SECCIONES, GUIAS Y MATRICULAS
CREATE TABLE IF NOT EXISTS academico.secciones (
    id_seccion BIGINT GENERATED ALWAYS AS IDENTITY,
    id_curso_lectivo BIGINT NOT NULL,
    nivel SMALLINT NOT NULL,
    numero INTEGER NOT NULL,
    activa BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT pk_secciones PRIMARY KEY (id_seccion),
    CONSTRAINT fk_secciones_curso FOREIGN KEY (id_curso_lectivo)
        REFERENCES academico.cursos_lectivos(id_curso_lectivo) ON DELETE RESTRICT,
    CONSTRAINT uq_secciones_id_curso UNIQUE (id_seccion, id_curso_lectivo),
    CONSTRAINT uq_seccion_curso_nivel_numero UNIQUE (id_curso_lectivo, nivel, numero),
    CONSTRAINT ck_secciones_nivel CHECK (nivel IN (10, 11)),
    CONSTRAINT ck_secciones_numero CHECK (numero > 0)
);
CREATE INDEX IF NOT EXISTS ix_secciones_curso ON academico.secciones(id_curso_lectivo);

CREATE TABLE IF NOT EXISTS academico.guias_seccion (
    id_guia_seccion BIGINT GENERATED ALWAYS AS IDENTITY,
    id_seccion BIGINT NOT NULL,
    id_profesor BIGINT NOT NULL,
    fecha_inicio DATE NOT NULL,
    fecha_fin DATE,
    CONSTRAINT pk_guias_seccion PRIMARY KEY (id_guia_seccion),
    CONSTRAINT fk_guias_seccion_seccion FOREIGN KEY (id_seccion)
        REFERENCES academico.secciones(id_seccion) ON DELETE RESTRICT,
    CONSTRAINT fk_guias_seccion_profesor FOREIGN KEY (id_profesor)
        REFERENCES academico.profesores(id_usuario) ON DELETE RESTRICT,
    CONSTRAINT ck_guias_seccion_fechas CHECK (
        fecha_fin IS NULL OR fecha_fin >= fecha_inicio
    ),
    CONSTRAINT ex_guias_una_guia_por_seccion
        EXCLUDE USING gist (
            id_seccion WITH =,
            daterange(fecha_inicio, COALESCE(fecha_fin + 1, 'infinity'::date), '[)') WITH &&
        ),
    CONSTRAINT ex_guias_unica_seccion_por_guia
        EXCLUDE USING gist (
            id_profesor WITH =,
            daterange(fecha_inicio, COALESCE(fecha_fin + 1, 'infinity'::date), '[)') WITH &&
        )
);
CREATE INDEX IF NOT EXISTS ix_guias_seccion_profesor ON academico.guias_seccion(id_profesor);
CREATE INDEX IF NOT EXISTS ix_guias_seccion_seccion ON academico.guias_seccion(id_seccion);

CREATE TABLE IF NOT EXISTS academico.matriculas (
    id_matricula BIGINT GENERATED ALWAYS AS IDENTITY,
    id_estudiante BIGINT NOT NULL,
    id_seccion BIGINT NOT NULL,
    id_curso_lectivo BIGINT NOT NULL,
    fecha_matricula DATE NOT NULL DEFAULT CURRENT_DATE,
    fecha_retiro DATE,
    activa BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT pk_matriculas PRIMARY KEY (id_matricula),
    CONSTRAINT fk_matriculas_estudiante FOREIGN KEY (id_estudiante)
        REFERENCES academico.estudiantes(id_usuario) ON DELETE RESTRICT,
    CONSTRAINT fk_matriculas_seccion_curso FOREIGN KEY (id_seccion, id_curso_lectivo)
        REFERENCES academico.secciones(id_seccion, id_curso_lectivo) ON DELETE RESTRICT,
    CONSTRAINT ck_matriculas_fechas CHECK (
        fecha_retiro IS NULL OR fecha_retiro >= fecha_matricula
    ),
    CONSTRAINT ck_matriculas_estado_retiro CHECK (
        activa OR fecha_retiro IS NOT NULL
    )
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_matricula_estudiante_curso_activa
    ON academico.matriculas(id_estudiante, id_curso_lectivo)
    WHERE activa = TRUE;
CREATE INDEX IF NOT EXISTS ix_matriculas_estudiante ON academico.matriculas(id_estudiante);
CREATE INDEX IF NOT EXISTS ix_matriculas_seccion ON academico.matriculas(id_seccion);

-- 08. ASIGNATURAS Y DOCENCIA
CREATE TABLE IF NOT EXISTS academico.asignaturas (
    id_asignatura BIGINT GENERATED ALWAYS AS IDENTITY,
    codigo VARCHAR(30),
    nombre VARCHAR(100) NOT NULL,
    descripcion VARCHAR(255),
    activa BOOLEAN NOT NULL DEFAULT TRUE,
    tipo_banda academico.tipo_banda NOT NULL DEFAULT 'NUMERICA',
    es_teoria_conocimiento BOOLEAN NOT NULL DEFAULT FALSE,
    permite_monografia BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT pk_asignaturas PRIMARY KEY (id_asignatura),
    CONSTRAINT uq_asignaturas_codigo UNIQUE (codigo),
    CONSTRAINT uq_asignaturas_nombre UNIQUE (nombre),
    CONSTRAINT ck_asignaturas_nombre CHECK (length(trim(nombre)) >= 2),
    CONSTRAINT ck_asignaturas_tok_banda CHECK (
        NOT es_teoria_conocimiento OR tipo_banda = 'LETRA'
    ),
    CONSTRAINT ck_asignaturas_flags CHECK (
        NOT (es_teoria_conocimiento AND permite_monografia)
    )
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_asignatura_tok
    ON academico.asignaturas((es_teoria_conocimiento))
    WHERE es_teoria_conocimiento = TRUE;

CREATE TABLE IF NOT EXISTS academico.asignaciones_docentes (
    id_asignacion BIGINT GENERATED ALWAYS AS IDENTITY,
    id_profesor BIGINT NOT NULL,
    id_asignatura BIGINT NOT NULL,
    id_seccion BIGINT NOT NULL,
    activa BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT pk_asignaciones_docentes PRIMARY KEY (id_asignacion),
    CONSTRAINT fk_ad_profesor FOREIGN KEY (id_profesor)
        REFERENCES academico.profesores(id_usuario) ON DELETE RESTRICT,
    CONSTRAINT fk_ad_asignatura FOREIGN KEY (id_asignatura)
        REFERENCES academico.asignaturas(id_asignatura) ON DELETE RESTRICT,
    CONSTRAINT fk_ad_seccion FOREIGN KEY (id_seccion)
        REFERENCES academico.secciones(id_seccion) ON DELETE RESTRICT
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_ad_profesor_asignatura_seccion_activa
    ON academico.asignaciones_docentes(id_profesor, id_asignatura, id_seccion)
    WHERE activa = TRUE;
CREATE INDEX IF NOT EXISTS ix_ad_profesor ON academico.asignaciones_docentes(id_profesor);
CREATE INDEX IF NOT EXISTS ix_ad_seccion ON academico.asignaciones_docentes(id_seccion);
CREATE INDEX IF NOT EXISTS ix_ad_asignatura ON academico.asignaciones_docentes(id_asignatura);

-- 09. COORDINACIÓN Y MONOGRAFÍAS
CREATE TABLE IF NOT EXISTS academico.coordinaciones_monografia (
    id_coordinacion BIGINT GENERATED ALWAYS AS IDENTITY,
    id_profesor BIGINT NOT NULL,
    id_asignatura BIGINT NOT NULL,
    fecha_inicio DATE NOT NULL DEFAULT CURRENT_DATE,
    fecha_fin DATE,
    activa BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT pk_coordinaciones_monografia PRIMARY KEY (id_coordinacion),
    CONSTRAINT uq_cm_coordinacion_asignatura UNIQUE (id_coordinacion, id_asignatura),
    CONSTRAINT fk_cm_profesor FOREIGN KEY (id_profesor)
        REFERENCES academico.profesores(id_usuario) ON DELETE RESTRICT,
    CONSTRAINT fk_cm_asignatura FOREIGN KEY (id_asignatura)
        REFERENCES academico.asignaturas(id_asignatura) ON DELETE RESTRICT,
    CONSTRAINT ck_cm_fechas CHECK (fecha_fin IS NULL OR fecha_fin >= fecha_inicio),
    CONSTRAINT ex_cm_profesor_periodo
        EXCLUDE USING gist (
            id_profesor WITH =,
            daterange(fecha_inicio, COALESCE(fecha_fin + 1, 'infinity'::date), '[)') WITH &&
        )
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_coordinador_activo
    ON academico.coordinaciones_monografia(id_profesor)
    WHERE activa = TRUE;
CREATE INDEX IF NOT EXISTS ix_cm_asignatura ON academico.coordinaciones_monografia(id_asignatura);

CREATE TABLE IF NOT EXISTS academico.monografias (
    id_monografia BIGINT GENERATED ALWAYS AS IDENTITY,
    id_estudiante BIGINT NOT NULL,
    id_curso_lectivo_inicio BIGINT NOT NULL,
    fecha_inicio DATE NOT NULL,
    fecha_fin DATE NOT NULL,
    id_asignatura BIGINT,
    id_coordinacion BIGINT,
    fecha_seleccion_asignatura DATE,
    estado academico.estado_monografia NOT NULL DEFAULT 'CAPACITACION',
    CONSTRAINT pk_monografias PRIMARY KEY (id_monografia),
    CONSTRAINT uq_monografia_estudiante UNIQUE (id_estudiante),
    CONSTRAINT fk_monografia_estudiante FOREIGN KEY (id_estudiante)
        REFERENCES academico.estudiantes(id_usuario) ON DELETE RESTRICT,
    CONSTRAINT fk_monografia_curso_inicio FOREIGN KEY (id_curso_lectivo_inicio)
        REFERENCES academico.cursos_lectivos(id_curso_lectivo) ON DELETE RESTRICT,
    CONSTRAINT fk_monografia_coordinacion_asignatura
        FOREIGN KEY (id_coordinacion, id_asignatura)
        REFERENCES academico.coordinaciones_monografia(id_coordinacion, id_asignatura)
        ON DELETE RESTRICT,
    CONSTRAINT ck_monografia_dos_anios CHECK (
        fecha_fin = (fecha_inicio + INTERVAL '2 years')::date
    ),
    CONSTRAINT ck_monografia_seleccion_consistente CHECK (
        (id_asignatura IS NULL AND id_coordinacion IS NULL AND fecha_seleccion_asignatura IS NULL)
        OR
        (id_asignatura IS NOT NULL AND id_coordinacion IS NOT NULL AND fecha_seleccion_asignatura IS NOT NULL)
    ),
    CONSTRAINT ck_monografia_estado_consistente CHECK (
        (estado = 'CAPACITACION' AND id_asignatura IS NULL)
        OR
        (estado IN ('INVESTIGACION', 'CERRADA') AND id_asignatura IS NOT NULL)
        OR
        (estado = 'CANCELADA')
    ),
    CONSTRAINT ck_monografia_seleccion_despues_capacitacion CHECK (
        fecha_seleccion_asignatura IS NULL
        OR (
            fecha_seleccion_asignatura >= (fecha_inicio + INTERVAL '6 months')::date
            AND fecha_seleccion_asignatura <= fecha_fin
        )
    ),
    CONSTRAINT ck_monografia_fechas CHECK (fecha_fin > fecha_inicio)
);
CREATE INDEX IF NOT EXISTS ix_monografias_asignatura ON academico.monografias(id_asignatura);
CREATE INDEX IF NOT EXISTS ix_monografias_coordinacion ON academico.monografias(id_coordinacion);
CREATE INDEX IF NOT EXISTS ix_monografias_estado ON academico.monografias(estado);

CREATE TABLE IF NOT EXISTS academico.observaciones_monografia (
    id_observacion BIGINT GENERATED ALWAYS AS IDENTITY,
    id_monografia BIGINT NOT NULL,
    id_profesor BIGINT NOT NULL,
    fecha_observacion TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    observacion TEXT NOT NULL,
    CONSTRAINT pk_observaciones_monografia PRIMARY KEY (id_observacion),
    CONSTRAINT fk_om_monografia FOREIGN KEY (id_monografia)
        REFERENCES academico.monografias(id_monografia) ON DELETE CASCADE,
    CONSTRAINT fk_om_profesor FOREIGN KEY (id_profesor)
        REFERENCES academico.profesores(id_usuario) ON DELETE RESTRICT,
    CONSTRAINT ck_om_observacion CHECK (length(trim(observacion)) >= 3)
);
CREATE INDEX IF NOT EXISTS ix_om_monografia_fecha
    ON academico.observaciones_monografia(id_monografia, fecha_observacion DESC);

-- 10. CALIFICACIONES / BANDAS
CREATE TABLE IF NOT EXISTS academico.calificaciones (
    id_calificacion BIGINT GENERATED ALWAYS AS IDENTITY,
    id_semestre BIGINT NOT NULL,
    id_matricula BIGINT,
    id_asignacion BIGINT,
    id_monografia BIGINT,
    banda_numerica SMALLINT,
    banda_letra CHAR(1),
    fecha_registro TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    observacion TEXT,
    aprobada BOOLEAN GENERATED ALWAYS AS (
        CASE
            WHEN banda_numerica IS NULL THEN NULL
            ELSE banda_numerica >= 4
        END
    ) STORED,
    CONSTRAINT pk_calificaciones PRIMARY KEY (id_calificacion),
    CONSTRAINT fk_cal_semestre FOREIGN KEY (id_semestre)
        REFERENCES academico.semestres(id_semestre) ON DELETE RESTRICT,
    CONSTRAINT fk_cal_matricula FOREIGN KEY (id_matricula)
        REFERENCES academico.matriculas(id_matricula) ON DELETE RESTRICT,
    CONSTRAINT fk_cal_asignacion FOREIGN KEY (id_asignacion)
        REFERENCES academico.asignaciones_docentes(id_asignacion) ON DELETE RESTRICT,
    CONSTRAINT fk_cal_monografia FOREIGN KEY (id_monografia)
        REFERENCES academico.monografias(id_monografia) ON DELETE RESTRICT,
    CONSTRAINT ck_cal_fuente_xor CHECK (
        (id_asignacion IS NOT NULL AND id_matricula IS NOT NULL AND id_monografia IS NULL)
        OR
        (id_asignacion IS NULL AND id_matricula IS NULL AND id_monografia IS NOT NULL)
    ),
    CONSTRAINT ck_cal_banda_xor CHECK (
        (banda_numerica IS NOT NULL AND banda_letra IS NULL)
        OR
        (banda_numerica IS NULL AND banda_letra IS NOT NULL)
    ),
    CONSTRAINT ck_cal_banda_numerica CHECK (
        banda_numerica IS NULL OR banda_numerica BETWEEN 1 AND 7
    ),
    CONSTRAINT ck_cal_banda_letra CHECK (
        banda_letra IS NULL OR banda_letra IN ('A','B','C','D','E')
    )
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_calificacion_asignatura
    ON academico.calificaciones(id_semestre, id_matricula, id_asignacion)
    WHERE id_asignacion IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS uq_calificacion_monografia
    ON academico.calificaciones(id_semestre, id_monografia)
    WHERE id_monografia IS NOT NULL;
CREATE INDEX IF NOT EXISTS ix_calificaciones_matricula ON academico.calificaciones(id_matricula);
CREATE INDEX IF NOT EXISTS ix_calificaciones_semestre ON academico.calificaciones(id_semestre);
CREATE INDEX IF NOT EXISTS ix_calificaciones_monografia ON academico.calificaciones(id_monografia);

-- 11. LECCIONES / ASISTENCIA / JUSTIFICACIONES
CREATE TABLE IF NOT EXISTS academico.lecciones (
    id_leccion BIGINT GENERATED ALWAYS AS IDENTITY,
    id_asignacion BIGINT NOT NULL,
    id_semestre BIGINT NOT NULL,
    fecha DATE NOT NULL,
    hora_inicio TIME NOT NULL,
    tema VARCHAR(255),
    CONSTRAINT pk_lecciones PRIMARY KEY (id_leccion),
    CONSTRAINT fk_lecciones_asignacion FOREIGN KEY (id_asignacion)
        REFERENCES academico.asignaciones_docentes(id_asignacion) ON DELETE RESTRICT,
    CONSTRAINT fk_lecciones_semestre FOREIGN KEY (id_semestre)
        REFERENCES academico.semestres(id_semestre) ON DELETE RESTRICT,
    CONSTRAINT uq_leccion_asignacion_fecha_hora UNIQUE (id_asignacion, fecha, hora_inicio)
);
CREATE INDEX IF NOT EXISTS ix_lecciones_asignacion_fecha
    ON academico.lecciones(id_asignacion, fecha);

CREATE TABLE IF NOT EXISTS academico.asistencia (
    id_asistencia BIGINT GENERATED ALWAYS AS IDENTITY,
    id_leccion BIGINT NOT NULL,
    id_matricula BIGINT NOT NULL,
    estado academico.estado_asistencia NOT NULL DEFAULT 'AUSENTE',
    fecha_registro TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    observacion TEXT,
    CONSTRAINT pk_asistencia PRIMARY KEY (id_asistencia),
    CONSTRAINT fk_asistencia_leccion FOREIGN KEY (id_leccion)
        REFERENCES academico.lecciones(id_leccion) ON DELETE CASCADE,
    CONSTRAINT fk_asistencia_matricula FOREIGN KEY (id_matricula)
        REFERENCES academico.matriculas(id_matricula) ON DELETE RESTRICT,
    CONSTRAINT uq_asistencia_leccion_matricula UNIQUE (id_leccion, id_matricula)
);
CREATE INDEX IF NOT EXISTS ix_asistencia_matricula ON academico.asistencia(id_matricula);
CREATE INDEX IF NOT EXISTS ix_asistencia_estado ON academico.asistencia(estado);

CREATE TABLE IF NOT EXISTS academico.justificaciones_asistencia (
    id_justificacion BIGINT GENERATED ALWAYS AS IDENTITY,
    id_asistencia BIGINT NOT NULL,
    id_usuario_autor BIGINT NOT NULL,
    fecha_justificacion TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    comentario TEXT NOT NULL,
    adjunto_url VARCHAR(500),
    CONSTRAINT pk_justificaciones_asistencia PRIMARY KEY (id_justificacion),
    CONSTRAINT fk_ja_asistencia FOREIGN KEY (id_asistencia)
        REFERENCES academico.asistencia(id_asistencia) ON DELETE CASCADE,
    CONSTRAINT fk_ja_autor FOREIGN KEY (id_usuario_autor)
        REFERENCES academico.usuarios(id_usuario) ON DELETE RESTRICT,
    CONSTRAINT uq_justificacion_por_asistencia UNIQUE (id_asistencia),
    CONSTRAINT ck_ja_comentario CHECK (length(trim(comentario)) >= 3)
);
CREATE INDEX IF NOT EXISTS ix_ja_asistencia ON academico.justificaciones_asistencia(id_asistencia);

-- 12. VERIFICACIÓN DE CORREO
CREATE TABLE IF NOT EXISTS academico.verificaciones_email (
    id_verificacion BIGINT GENERATED ALWAYS AS IDENTITY,
    id_usuario BIGINT NOT NULL,
    token_hash CHAR(64) NOT NULL,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expira_en TIMESTAMPTZ NOT NULL,
    verificado_en TIMESTAMPTZ,
    CONSTRAINT pk_verificaciones_email PRIMARY KEY (id_verificacion),
    CONSTRAINT fk_ve_usuario FOREIGN KEY (id_usuario)
        REFERENCES academico.usuarios(id_usuario) ON DELETE CASCADE,
    CONSTRAINT uq_verificaciones_token UNIQUE (token_hash),
    CONSTRAINT ck_ve_expiracion CHECK (expira_en > creado_en)
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_verificacion_pendiente_usuario
    ON academico.verificaciones_email(id_usuario)
    WHERE verificado_en IS NULL;
CREATE INDEX IF NOT EXISTS ix_verificaciones_email_usuario ON academico.verificaciones_email(id_usuario);

-- 13. REPORTES
CREATE TABLE IF NOT EXISTS academico.reportes (
    id_reporte BIGINT GENERATED ALWAYS AS IDENTITY,
    tipo academico.tipo_reporte NOT NULL,
    id_seccion BIGINT NOT NULL,
    id_semestre BIGINT NOT NULL,
    generado_por BIGINT NOT NULL,
    generado_en TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    contenido JSONB NOT NULL,
    CONSTRAINT pk_reportes PRIMARY KEY (id_reporte),
    CONSTRAINT fk_reportes_seccion FOREIGN KEY (id_seccion)
        REFERENCES academico.secciones(id_seccion) ON DELETE RESTRICT,
    CONSTRAINT fk_reportes_semestre FOREIGN KEY (id_semestre)
        REFERENCES academico.semestres(id_semestre) ON DELETE RESTRICT,
    CONSTRAINT fk_reportes_generado_por FOREIGN KEY (generado_por)
        REFERENCES academico.usuarios(id_usuario) ON DELETE RESTRICT,
    CONSTRAINT ck_reportes_contenido CHECK (jsonb_typeof(contenido) = 'object')
);
CREATE INDEX IF NOT EXISTS ix_reportes_seccion_semestre
    ON academico.reportes(id_seccion, id_semestre, generado_en DESC);

-- 14. AUDITORÍA
CREATE TABLE IF NOT EXISTS academico.auditoria_operaciones (
    id_auditoria BIGINT GENERATED ALWAYS AS IDENTITY,
    fecha_evento TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    id_usuario_actor BIGINT,
    rol_bd TEXT NOT NULL DEFAULT SESSION_USER,
    esquema TEXT NOT NULL,
    tabla TEXT NOT NULL,
    operacion TEXT NOT NULL,
    clave_registro TEXT,
    datos_antes JSONB,
    datos_despues JSONB,
    CONSTRAINT pk_auditoria PRIMARY KEY (id_auditoria),
    CONSTRAINT ck_auditoria_operacion CHECK (operacion IN ('INSERT','UPDATE','DELETE'))
);
CREATE INDEX IF NOT EXISTS ix_auditoria_fecha ON academico.auditoria_operaciones(fecha_evento DESC);
CREATE INDEX IF NOT EXISTS ix_auditoria_actor ON academico.auditoria_operaciones(id_usuario_actor);
CREATE INDEX IF NOT EXISTS ix_auditoria_tabla ON academico.auditoria_operaciones(esquema, tabla);

-- 28. DATOS INICIALES MÍNIMOS DE REFERENCIA
INSERT INTO academico.asignaturas(codigo, nombre, descripcion, tipo_banda, es_teoria_conocimiento, permite_monografia)
VALUES ('TOK', 'Teoría del conocimiento', 'Asignatura del BI evaluada mediante letras A-E.', 'LETRA', TRUE, FALSE)
ON CONFLICT (codigo) DO NOTHING;

COMMIT;