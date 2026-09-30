-- ============================================================
-- 14_ausentismo.sql: ausentismo por lección (Profesor Regular CU10 a CU12, Guía CU05). Tablas en 06.
-- Una lección es una clase que el profesor de una asignación registra cuando la imparte (fecha, hora y
-- tema); no depende de un horario (RN-66). Solo se guardan los ausentes y las llegadas tardías (RN-68, RN-86).
-- Solo el profesor de la asignación opera sus lecciones (AD004). La fecha cae en un semestre del periodo
-- y no es futura (LE001); cuando el semestre de la lección terminó, queda cerrada (PA004, RP-48).
-- Las lecciones se identifican por id (RP-53).
-- ============================================================
SET search_path = academico, api, auth, public;

CREATE TYPE academico.leccion_detalle AS (
    id_leccion BIGINT,
    anio INTEGER,
    nivel SMALLINT,
    numero SMALLINT,
    seccion TEXT,                -- "10-1"
    codigo_asignatura VARCHAR(10),
    asignatura TEXT,
    fecha DATE,
    hora TIME,
    tema VARCHAR(255),
    semestre academico.numero_semestre,
    ausentes INTEGER,
    justificadas INTEGER,
    tardias INTEGER
);

CREATE TYPE academico.ausencia_detalle AS (
    cedula_estudiante VARCHAR(20),
    nombre_estudiante TEXT,      -- "Apellido1 Apellido2, Nombre"
    tardia BOOLEAN,              -- TRUE = llegó tarde; FALSE = ausente
    justificada BOOLEAN,
    justificacion VARCHAR(255)
);

-- Una fila por estudiante (y asignación, en el resumen del guía). porcentaje_ausentismo es NULL si no hubo lecciones.
CREATE TYPE academico.resumen_ausentismo AS (
    cedula_estudiante VARCHAR(20),
    nombre_estudiante TEXT,
    estado_matricula academico.estado_matricula,
    codigo_asignatura VARCHAR(10),
    asignatura TEXT,
    nombre_profesor TEXT,
    lecciones INTEGER,
    ausencias INTEGER,
    justificadas INTEGER,
    injustificadas INTEGER,
    tardias INTEGER,
    porcentaje_ausentismo NUMERIC(5,2)
);

-- ------------------------------------------------------------
-- Helpers
-- ------------------------------------------------------------
-- Todas las lecciones con sus datos resueltos (una fila por lección).
CREATE OR REPLACE FUNCTION academico.fn_lecciones_detalle()
RETURNS TABLE(id_leccion BIGINT, id_asignacion BIGINT, id_seccion BIGINT, id_usuario_profesor UUID, fila academico.leccion_detalle)
LANGUAGE sql STABLE
SET search_path = academico, auth, api, public
AS $$
    SELECT l.id_leccion, a.id_asignacion, s.id_seccion, pr.id_usuario,
           ROW(l.id_leccion, p.anio, s.nivel, s.numero, s.nivel || '-' || s.numero,
               asg.codigo, asg.nombre::TEXT, l.fecha, l.hora, l.tema,
               academico.fn_semestre_en_fecha(p, l.fecha),
               (SELECT COUNT(*)::INTEGER FROM academico.ausencias au WHERE au.id_leccion = l.id_leccion AND NOT au.tardia),
               (SELECT COUNT(*)::INTEGER FROM academico.ausencias au WHERE au.id_leccion = l.id_leccion AND au.justificacion IS NOT NULL),
               (SELECT COUNT(*)::INTEGER FROM academico.ausencias au WHERE au.id_leccion = l.id_leccion AND au.tardia)
              )::academico.leccion_detalle
    FROM academico.lecciones l
    JOIN academico.asignaciones_docentes a ON a.id_asignacion = l.id_asignacion
    JOIN academico.secciones s ON s.id_seccion = a.id_seccion
    JOIN academico.periodos_academicos p ON p.id_periodo = s.id_periodo
    JOIN academico.asignaturas asg ON asg.id_asignatura = a.id_asignatura
    JOIN academico.profesores pr ON pr.id_profesor = a.id_profesor;
$$;

-- Id de la asignación del profesor autenticado en (año, nivel, número, código). NF006/NF007 si no existe la
-- sección o la asignatura; AD004 si el usuario no imparte esa asignatura en esa sección.
CREATE OR REPLACE FUNCTION academico.fn_obtener_mi_asignacion(
    p_id_usuario UUID, p_anio INTEGER, p_nivel INTEGER, p_numero INTEGER, p_codigo_asignatura TEXT)
RETURNS BIGINT
LANGUAGE plpgsql STABLE
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_id BIGINT;
    v_id_seccion BIGINT := academico.fn_obtener_id_seccion(p_anio, p_nivel, p_numero);
    v_id_asignatura BIGINT := academico.fn_obtener_id_asignatura(p_codigo_asignatura);
BEGIN
    SELECT a.id_asignacion INTO v_id
    FROM academico.asignaciones_docentes a
    JOIN academico.profesores pr ON pr.id_profesor = a.id_profesor
    WHERE a.id_seccion = v_id_seccion AND a.id_asignatura = v_id_asignatura AND pr.id_usuario = p_id_usuario;

    IF v_id IS NULL THEN
        PERFORM api.fn_lanzar_excepcion('AD004', 'No impartes esa asignatura en esa sección.');
    END IF;

    RETURN v_id;
END;
$$;

-- Lección del profesor autenticado, bloqueada para modificarla. NF010 si no existe; AD004 si es de otro profesor.
CREATE OR REPLACE FUNCTION academico.fn_obtener_mi_leccion(p_id_usuario UUID, p_id_leccion BIGINT)
RETURNS academico.lecciones
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_leccion academico.lecciones%ROWTYPE;
BEGIN
    SELECT l.* INTO v_leccion FROM academico.lecciones l WHERE l.id_leccion = p_id_leccion FOR UPDATE;

    IF NOT FOUND THEN
        PERFORM api.fn_lanzar_excepcion('NF010', 'La lección no existe.');
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM academico.asignaciones_docentes a
        JOIN academico.profesores pr ON pr.id_profesor = a.id_profesor
        WHERE a.id_asignacion = v_leccion.id_asignacion AND pr.id_usuario = p_id_usuario
    ) THEN
        PERFORM api.fn_lanzar_excepcion('AD004', 'No impartes esa asignatura en esa sección.');
    END IF;

    RETURN v_leccion;
END;
$$;

-- Periodo de una asignación.
CREATE OR REPLACE FUNCTION academico.fn_periodo_de_asignacion(p_id_asignacion BIGINT)
RETURNS academico.periodos_academicos
LANGUAGE sql STABLE
SET search_path = academico, auth, api, public
AS $$
    SELECT p.*
    FROM academico.asignaciones_docentes a
    JOIN academico.secciones s ON s.id_seccion = a.id_seccion
    JOIN academico.periodos_academicos p ON p.id_periodo = s.id_periodo
    WHERE a.id_asignacion = p_id_asignacion;
$$;

-- RN-67: LE001 si la fecha es futura o no cae en un semestre del periodo; PA004 si ese semestre ya terminó.
CREATE OR REPLACE FUNCTION academico.fn_validar_fecha_leccion(p_periodo academico.periodos_academicos, p_fecha DATE)
RETURNS VOID
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_semestre academico.numero_semestre := academico.fn_semestre_en_fecha(p_periodo, p_fecha);
BEGIN
    IF p_fecha IS NULL OR p_fecha > api.fn_hoy() OR v_semestre IS NULL THEN
        PERFORM api.fn_lanzar_excepcion('LE001', 'La fecha de la lección no es válida.');
    END IF;

    IF api.fn_hoy() > academico.fn_fin_semestre(p_periodo, v_semestre) THEN
        PERFORM api.fn_lanzar_excepcion('PA004', 'El semestre ya finalizó.');
    END IF;
END;
$$;

-- PA004 si el semestre de una lección ya registrada terminó (la lección y sus ausencias quedan cerradas).
CREATE OR REPLACE FUNCTION academico.fn_validar_leccion_abierta(p_leccion academico.lecciones)
RETURNS VOID
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_periodo academico.periodos_academicos := academico.fn_periodo_de_asignacion(p_leccion.id_asignacion);
BEGIN
    IF api.fn_hoy() > academico.fn_fin_semestre(v_periodo, academico.fn_semestre_en_fecha(v_periodo, p_leccion.fecha)) THEN
        PERFORM api.fn_lanzar_excepcion('PA004', 'El semestre ya finalizó.');
    END IF;
END;
$$;

-- LE002 si la asignación ya tiene otra lección en esa fecha y hora.
CREATE OR REPLACE FUNCTION academico.fn_validar_leccion_unica(
    p_id_asignacion BIGINT, p_fecha DATE, p_hora TIME, p_id_leccion_excluida BIGINT)
RETURNS VOID
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM academico.lecciones
               WHERE id_asignacion = p_id_asignacion AND fecha = p_fecha AND hora = p_hora
                 AND id_leccion IS DISTINCT FROM p_id_leccion_excluida) THEN
        PERFORM api.fn_lanzar_excepcion('LE002', 'Ya registraste una lección en esa fecha y hora.');
    END IF;
END;
$$;

-- Cédulas sin espacios, vacíos ni repetidos.
CREATE OR REPLACE FUNCTION academico.fn_limpiar_cedulas(p_cedulas TEXT[])
RETURNS TEXT[]
LANGUAGE sql IMMUTABLE
SET search_path = academico, auth, api, public
AS $$
    SELECT COALESCE(array_agg(DISTINCT c), ARRAY[]::TEXT[])
    FROM (SELECT api.fn_limpiar(x) AS c FROM unnest(COALESCE(p_cedulas, ARRAY[]::TEXT[])) x) t
    WHERE c IS NOT NULL;
$$;

-- RN-68 / RN-86: deja como ausentes de la lección exactamente a p_ausentes y como tardíos a p_tardias (sin
-- repetidos; LE004 si un estudiante está en las dos listas). Cada uno debe estar matriculado en la sección a la
-- fecha de la lección (LE003). Conserva la justificación de quien sigue ausente; quien pasa a tardío la pierde.
-- Devuelve TRUE si cambió algo.
CREATE OR REPLACE FUNCTION academico.fn_guardar_ausentes(p_id_leccion BIGINT, p_ausentes TEXT[], p_tardias TEXT[])
RETURNS BOOLEAN
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_leccion academico.lecciones%ROWTYPE;
    v_id_seccion BIGINT;
    v_ausentes TEXT[] := academico.fn_limpiar_cedulas(p_ausentes);
    v_tardias TEXT[] := academico.fn_limpiar_cedulas(p_tardias);
    v_cedulas TEXT[];
    v_registros JSONB;
    v_cambios INTEGER;
    v_total INTEGER := 0;
BEGIN
    IF v_ausentes && v_tardias THEN
        PERFORM api.fn_lanzar_excepcion('LE004', 'Un estudiante no puede estar ausente y tardío en la misma lección.');
    END IF;
    v_cedulas := v_ausentes || v_tardias;

    SELECT * INTO v_leccion FROM academico.lecciones WHERE id_leccion = p_id_leccion;
    SELECT id_seccion INTO v_id_seccion FROM academico.asignaciones_docentes WHERE id_asignacion = v_leccion.id_asignacion;

    -- Matrículas vigentes a la fecha de la lección de los estudiantes indicados: [{id_matricula, tardia}].
    SELECT COALESCE(jsonb_agg(jsonb_build_object('id_matricula', m.id_matricula, 'tardia', e.cedula = ANY (v_tardias))), '[]'::jsonb)
    INTO v_registros
    FROM academico.matriculas m
    JOIN academico.estudiantes e ON e.id_estudiante = m.id_estudiante
    WHERE m.id_seccion = v_id_seccion
      AND e.cedula = ANY (v_cedulas)
      AND m.fecha_matricula <= v_leccion.fecha
      AND (m.fecha_retiro IS NULL OR m.fecha_retiro > v_leccion.fecha);

    IF jsonb_array_length(v_registros) <> cardinality(v_cedulas) THEN
        PERFORM api.fn_lanzar_excepcion('LE003', 'Un estudiante marcado como ausente o tardío no estaba matriculado en la sección en la fecha de la lección.');
    END IF;

    WITH r AS (SELECT * FROM jsonb_to_recordset(v_registros) AS x(id_matricula BIGINT, tardia BOOLEAN))
    DELETE FROM academico.ausencias au
    WHERE au.id_leccion = p_id_leccion
      AND NOT EXISTS (SELECT 1 FROM r WHERE r.id_matricula = au.id_matricula);
    GET DIAGNOSTICS v_cambios = ROW_COUNT;
    v_total := v_total + v_cambios;

    WITH r AS (SELECT * FROM jsonb_to_recordset(v_registros) AS x(id_matricula BIGINT, tardia BOOLEAN))
    UPDATE academico.ausencias au
    SET tardia = r.tardia,
        justificacion = CASE WHEN r.tardia THEN NULL ELSE au.justificacion END,
        justificada_en = CASE WHEN r.tardia THEN NULL ELSE au.justificada_en END
    FROM r
    WHERE au.id_leccion = p_id_leccion AND au.id_matricula = r.id_matricula AND au.tardia <> r.tardia;
    GET DIAGNOSTICS v_cambios = ROW_COUNT;
    v_total := v_total + v_cambios;

    INSERT INTO academico.ausencias (id_leccion, id_matricula, tardia)
    SELECT p_id_leccion, x.id_matricula, x.tardia
    FROM jsonb_to_recordset(v_registros) AS x(id_matricula BIGINT, tardia BOOLEAN)
    ON CONFLICT (id_leccion, id_matricula) DO NOTHING;
    GET DIAGNOSTICS v_cambios = ROW_COUNT;
    v_total := v_total + v_cambios;

    RETURN v_total > 0;
END;
$$;

CREATE OR REPLACE FUNCTION academico.fn_listar_ausencias_de(p_id_leccion BIGINT)
RETURNS SETOF academico.ausencia_detalle
LANGUAGE sql STABLE
SET search_path = academico, auth, api, public
AS $$
    SELECT e.cedula, concat_ws(' ', e.primer_apellido, e.segundo_apellido) || ', ' || e.nombre,
           au.tardia, au.justificacion IS NOT NULL, au.justificacion
    FROM academico.ausencias au
    JOIN academico.matriculas m ON m.id_matricula = au.id_matricula
    JOIN academico.estudiantes e ON e.id_estudiante = m.id_estudiante
    WHERE au.id_leccion = p_id_leccion
    ORDER BY au.tardia, e.primer_apellido, e.segundo_apellido, e.nombre;
$$;

-- Snapshot para auditoría: la lección con la lista de ausentes.
CREATE OR REPLACE FUNCTION academico.fn_snapshot_leccion(p_id_leccion BIGINT)
RETURNS JSONB
LANGUAGE sql STABLE
SET search_path = academico, auth, api, public
AS $$
    SELECT to_jsonb(d.fila) || jsonb_build_object('ausentes',
               COALESCE((SELECT jsonb_agg(to_jsonb(a)) FROM academico.fn_listar_ausencias_de(p_id_leccion) a), '[]'::jsonb))
    FROM academico.fn_lecciones_detalle() d
    WHERE d.id_leccion = p_id_leccion;
$$;

-- RN-70: conteo por estudiante (matrícula) y asignación de la sección. Las lecciones que cuentan para un
-- estudiante son las registradas mientras estuvo matriculado (desde su matrícula y antes de su retiro). Las
-- llegadas tardías se cuentan aparte (RN-86). p_id_asignacion NULL = todas; p_semestre NULL = todo el año.
-- Lo usan el resumen de ausentismo y el reporte de bandas.
CREATE OR REPLACE FUNCTION academico.fn_conteo_ausentismo(p_id_seccion BIGINT, p_id_asignacion BIGINT, p_semestre academico.numero_semestre)
RETURNS TABLE(id_matricula BIGINT, id_asignacion BIGINT, lecciones INTEGER, ausencias INTEGER, justificadas INTEGER, tardias INTEGER)
LANGUAGE sql STABLE
SET search_path = academico, auth, api, public
AS $$
    SELECT m.id_matricula, a.id_asignacion,
           COUNT(l.id_leccion)::INTEGER,
           (COUNT(au.id_leccion) FILTER (WHERE NOT au.tardia))::INTEGER,
           COUNT(au.justificacion)::INTEGER,
           (COUNT(au.id_leccion) FILTER (WHERE au.tardia))::INTEGER
    FROM academico.matriculas m
    JOIN academico.periodos_academicos p ON p.id_periodo = m.id_periodo
    JOIN academico.asignaciones_docentes a ON a.id_seccion = m.id_seccion
    LEFT JOIN academico.lecciones l ON l.id_asignacion = a.id_asignacion
         AND l.fecha >= m.fecha_matricula
         AND (m.fecha_retiro IS NULL OR l.fecha < m.fecha_retiro)
         AND (p_semestre IS NULL OR academico.fn_semestre_en_fecha(p, l.fecha) = p_semestre)
    LEFT JOIN academico.ausencias au ON au.id_leccion = l.id_leccion AND au.id_matricula = m.id_matricula
    WHERE m.id_seccion = p_id_seccion AND (p_id_asignacion IS NULL OR a.id_asignacion = p_id_asignacion)
    GROUP BY m.id_matricula, a.id_asignacion;
$$;

-- RN-70: resumen por estudiante y asignación (porcentaje = ausencias / lecciones; NULL si no hubo lecciones).
CREATE OR REPLACE FUNCTION academico.fn_resumen_ausentismo(p_id_seccion BIGINT, p_id_asignacion BIGINT, p_semestre academico.numero_semestre)
RETURNS SETOF academico.resumen_ausentismo
LANGUAGE sql STABLE
SET search_path = academico, auth, api, public
AS $$
    SELECT (d.fila).cedula_estudiante, (d.fila).nombre_estudiante, (d.fila).estado,
           (ad.fila).codigo_asignatura, (ad.fila).asignatura, (ad.fila).nombre_profesor,
           c.lecciones, c.ausencias, c.justificadas, c.ausencias - c.justificadas, c.tardias,
           CASE WHEN c.lecciones > 0 THEN round(100.0 * c.ausencias / c.lecciones, 2) END
    FROM academico.fn_conteo_ausentismo(p_id_seccion, p_id_asignacion, p_semestre) c
    JOIN academico.fn_matriculas_detalle() d ON d.id_matricula = c.id_matricula
    JOIN academico.fn_asignaciones_detalle() ad ON ad.id_asignacion = c.id_asignacion
    ORDER BY d.apellidos_nombre, (ad.fila).asignatura, (ad.fila).nombre_profesor;
$$;

-- ------------------------------------------------------------
-- Profesor Regular CU10 - Registrar ausentismo: registra la lección con sus ausentes y tardíos. Devuelve el id.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION academico.fn_profesor_registrar_leccion(
    p_id_usuario UUID,
    p_anio INTEGER,
    p_nivel INTEGER,
    p_numero INTEGER,
    p_codigo_asignatura TEXT,
    p_fecha DATE,
    p_hora TIME,
    p_tema TEXT,
    p_ausentes TEXT[],
    p_tardias TEXT[]
)
RETURNS BIGINT
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_id_asignacion BIGINT := academico.fn_obtener_mi_asignacion(p_id_usuario, p_anio, p_nivel, p_numero, p_codigo_asignatura);
    v_id_leccion BIGINT;
BEGIN
    PERFORM academico.fn_validar_fecha_leccion(academico.fn_periodo_de_asignacion(v_id_asignacion), p_fecha);
    PERFORM academico.fn_validar_leccion_unica(v_id_asignacion, p_fecha, p_hora, NULL);

    INSERT INTO academico.lecciones (id_asignacion, fecha, hora, tema)
    VALUES (v_id_asignacion, p_fecha, p_hora, api.fn_limpiar(p_tema))
    RETURNING id_leccion INTO v_id_leccion;

    PERFORM academico.fn_guardar_ausentes(v_id_leccion, p_ausentes, p_tardias);
    RETURN v_id_leccion;
END;
$$;

-- ------------------------------------------------------------
-- Profesor Regular CU11 - Modificar ausentismo: corrige fecha, hora y tema y reemplaza las listas de ausentes y tardíos.
-- Devuelve 'OK' o 'SIN_CAMBIOS' y el snapshot previo.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION academico.fn_profesor_modificar_leccion(
    p_id_usuario UUID,
    p_id_leccion BIGINT,
    p_fecha DATE,
    p_hora TIME,
    p_tema TEXT,
    p_ausentes TEXT[],
    p_tardias TEXT[],
    OUT out_status TEXT,
    OUT out_datos_anteriores JSONB
)
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_leccion academico.lecciones := academico.fn_obtener_mi_leccion(p_id_usuario, p_id_leccion);
    v_tema TEXT := api.fn_limpiar(p_tema);
    v_cambio_datos BOOLEAN;
    v_cambio_ausentes BOOLEAN;
BEGIN
    PERFORM academico.fn_validar_leccion_abierta(v_leccion);
    PERFORM academico.fn_validar_fecha_leccion(academico.fn_periodo_de_asignacion(v_leccion.id_asignacion), p_fecha);
    PERFORM academico.fn_validar_leccion_unica(v_leccion.id_asignacion, p_fecha, p_hora, p_id_leccion);

    out_datos_anteriores := academico.fn_snapshot_leccion(p_id_leccion);
    v_cambio_datos := (v_leccion.fecha, v_leccion.hora, v_leccion.tema) IS DISTINCT FROM (p_fecha, p_hora, v_tema);

    IF v_cambio_datos THEN
        UPDATE academico.lecciones SET fecha = p_fecha, hora = p_hora, tema = v_tema WHERE id_leccion = p_id_leccion;
    END IF;

    v_cambio_ausentes := academico.fn_guardar_ausentes(p_id_leccion, p_ausentes, p_tardias);
    out_status := CASE WHEN v_cambio_datos OR v_cambio_ausentes THEN 'OK' ELSE 'SIN_CAMBIOS' END;
END;
$$;

-- Profesor Regular CU11 - Eliminar una lección (y sus ausencias). Devuelve el snapshot previo.
CREATE OR REPLACE FUNCTION academico.fn_profesor_eliminar_leccion(p_id_usuario UUID, p_id_leccion BIGINT)
RETURNS JSONB
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_leccion academico.lecciones := academico.fn_obtener_mi_leccion(p_id_usuario, p_id_leccion);
    v_prev JSONB;
BEGIN
    PERFORM academico.fn_validar_leccion_abierta(v_leccion);
    v_prev := academico.fn_snapshot_leccion(p_id_leccion);
    DELETE FROM academico.lecciones WHERE id_leccion = p_id_leccion;
    RETURN v_prev;
END;
$$;

-- ------------------------------------------------------------
-- Profesor Regular CU11 - Justificar una ausencia (RN-69). Devuelve 'OK' o 'SIN_CAMBIOS' y la ausencia previa.
-- NF003 si el estudiante no existe; NF011 si no tiene ausencia en la lección (una llegada tardía no se justifica).
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION academico.fn_profesor_justificar_ausencia(
    p_id_usuario UUID,
    p_id_leccion BIGINT,
    p_cedula_estudiante TEXT,
    p_justificacion TEXT,
    OUT out_status TEXT,
    OUT out_datos_anteriores JSONB
)
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_leccion academico.lecciones := academico.fn_obtener_mi_leccion(p_id_usuario, p_id_leccion);
    v_id_estudiante BIGINT := academico.fn_obtener_id_estudiante(p_cedula_estudiante);
    v_ausencia academico.ausencias%ROWTYPE;
    v_justificacion TEXT := api.fn_limpiar(p_justificacion);
BEGIN
    PERFORM academico.fn_validar_leccion_abierta(v_leccion);

    SELECT au.* INTO v_ausencia
    FROM academico.ausencias au
    JOIN academico.matriculas m ON m.id_matricula = au.id_matricula
    WHERE au.id_leccion = p_id_leccion AND m.id_estudiante = v_id_estudiante AND NOT au.tardia
    FOR UPDATE OF au;

    IF NOT FOUND THEN
        PERFORM api.fn_lanzar_excepcion('NF011', 'El estudiante no tiene una ausencia en esa lección.');
    END IF;

    out_datos_anteriores := jsonb_build_object('idLeccion', p_id_leccion, 'cedulaEstudiante', api.fn_limpiar(p_cedula_estudiante),
                                               'justificacion', v_ausencia.justificacion);

    IF v_ausencia.justificacion IS NOT DISTINCT FROM v_justificacion THEN
        out_status := 'SIN_CAMBIOS';
        RETURN;
    END IF;

    UPDATE academico.ausencias
    SET justificacion = v_justificacion,
        justificada_en = CASE WHEN v_justificacion IS NULL THEN NULL ELSE NOW() END
    WHERE id_leccion = p_id_leccion AND id_matricula = v_ausencia.id_matricula;

    out_status := 'OK';
END;
$$;

-- ------------------------------------------------------------
-- Profesor Regular CU12 - Consultar ausentismo
-- ------------------------------------------------------------
-- Lecciones de mi asignación, de la más reciente a la más antigua. p_semestre NULL = todo el año.
CREATE OR REPLACE FUNCTION academico.fn_profesor_lecciones_filtradas(
    p_id_usuario UUID, p_anio INTEGER, p_nivel INTEGER, p_numero INTEGER, p_codigo_asignatura TEXT,
    p_semestre academico.numero_semestre)
RETURNS SETOF academico.leccion_detalle
LANGUAGE plpgsql STABLE
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_id_asignacion BIGINT := academico.fn_obtener_mi_asignacion(p_id_usuario, p_anio, p_nivel, p_numero, p_codigo_asignatura);
BEGIN
    RETURN QUERY
    SELECT (d.fila).*
    FROM academico.fn_lecciones_detalle() d
    WHERE d.id_asignacion = v_id_asignacion AND (p_semestre IS NULL OR (d.fila).semestre = p_semestre)
    ORDER BY (d.fila).fecha DESC, (d.fila).hora DESC;
END;
$$;

CREATE OR REPLACE FUNCTION academico.fn_profesor_listar_lecciones(
    p_id_usuario UUID, p_anio INTEGER, p_nivel INTEGER, p_numero INTEGER, p_codigo_asignatura TEXT,
    p_semestre academico.numero_semestre, p_pagina INTEGER, p_tamano_pagina INTEGER)
RETURNS SETOF academico.leccion_detalle
LANGUAGE sql STABLE
SET search_path = academico, auth, api, public
AS $$
    SELECT *
    FROM academico.fn_profesor_lecciones_filtradas(p_id_usuario, p_anio, p_nivel, p_numero, p_codigo_asignatura, p_semestre)
    LIMIT api.fn_tamano_pagina(p_tamano_pagina) OFFSET api.fn_offset(p_pagina, p_tamano_pagina);
$$;

CREATE OR REPLACE FUNCTION academico.fn_profesor_contar_lecciones(
    p_id_usuario UUID, p_anio INTEGER, p_nivel INTEGER, p_numero INTEGER, p_codigo_asignatura TEXT,
    p_semestre academico.numero_semestre)
RETURNS BIGINT
LANGUAGE sql STABLE
SET search_path = academico, auth, api, public
AS $$
    SELECT COUNT(*)
    FROM academico.fn_profesor_lecciones_filtradas(p_id_usuario, p_anio, p_nivel, p_numero, p_codigo_asignatura, p_semestre);
$$;

-- Detalle de una lección mía (NF010 / AD004).
CREATE OR REPLACE FUNCTION academico.fn_profesor_obtener_leccion(p_id_usuario UUID, p_id_leccion BIGINT)
RETURNS SETOF academico.leccion_detalle
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
BEGIN
    PERFORM academico.fn_obtener_mi_leccion(p_id_usuario, p_id_leccion);
    RETURN QUERY SELECT (d.fila).* FROM academico.fn_lecciones_detalle() d WHERE d.id_leccion = p_id_leccion;
END;
$$;

-- Ausentes de una lección mía (NF010 / AD004).
CREATE OR REPLACE FUNCTION academico.fn_profesor_listar_ausencias_leccion(p_id_usuario UUID, p_id_leccion BIGINT)
RETURNS SETOF academico.ausencia_detalle
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
BEGIN
    PERFORM academico.fn_obtener_mi_leccion(p_id_usuario, p_id_leccion);
    RETURN QUERY SELECT * FROM academico.fn_listar_ausencias_de(p_id_leccion);
END;
$$;

-- Resumen de ausentismo de mi asignación por estudiante (RN-70).
CREATE OR REPLACE FUNCTION academico.fn_profesor_resumen_ausentismo(
    p_id_usuario UUID, p_anio INTEGER, p_nivel INTEGER, p_numero INTEGER, p_codigo_asignatura TEXT,
    p_semestre academico.numero_semestre)
RETURNS SETOF academico.resumen_ausentismo
LANGUAGE plpgsql STABLE
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_id_asignacion BIGINT := academico.fn_obtener_mi_asignacion(p_id_usuario, p_anio, p_nivel, p_numero, p_codigo_asignatura);
BEGIN
    RETURN QUERY
    SELECT * FROM academico.fn_resumen_ausentismo(academico.fn_obtener_id_seccion(p_anio, p_nivel, p_numero), v_id_asignacion, p_semestre);
END;
$$;

-- ------------------------------------------------------------
-- Guía CU05 - Ausentismo de mi sección guía por estudiante y asignatura (RN-71). AD005 si no es el guía.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION academico.fn_guia_resumen_ausentismo(
    p_id_usuario UUID, p_anio INTEGER, p_nivel INTEGER, p_numero INTEGER, p_semestre academico.numero_semestre)
RETURNS SETOF academico.resumen_ausentismo
LANGUAGE plpgsql STABLE
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_id_seccion BIGINT := academico.fn_validar_guia_seccion(p_id_usuario, p_anio, p_nivel, p_numero);
BEGIN
    RETURN QUERY SELECT * FROM academico.fn_resumen_ausentismo(v_id_seccion, NULL, p_semestre);
END;
$$;
