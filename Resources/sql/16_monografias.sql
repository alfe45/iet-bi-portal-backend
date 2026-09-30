-- ============================================================
-- 16_monografias.sql: monografías (Administrador CU34 a CU37, Coordinador de Monografía CU01 a CU05,
-- Guía CU06 y CU07). Tablas en 06.
-- Una monografía por estudiante; empieza con su matrícula de nivel 10 y dura los dos años del programa (RN-78).
-- Se opera por la cédula del estudiante; los seguimientos, por id. Solo el coordinador de la monografía la
-- opera (AD006).
-- ============================================================
SET search_path = academico, api, auth, public;

CREATE TYPE academico.monografia_detalle AS (
    cedula_estudiante VARCHAR(20),
    nombre_estudiante TEXT,      -- "Apellido1 Apellido2, Nombre"
    anio_inicio INTEGER,         -- año de su nivel 10
    anio_actual INTEGER,         -- año de su última matrícula
    seccion_actual TEXT,         -- "11-1"
    cedula_coordinador VARCHAR(20),
    nombre_coordinador TEXT,
    codigo_asignatura VARCHAR(10),
    asignatura TEXT,
    estado academico.estado_monografia,
    seguimientos INTEGER,
    ultimo_seguimiento DATE
);

CREATE TYPE academico.seguimiento_monografia AS (
    id_seguimiento BIGINT,
    cedula_estudiante VARCHAR(20),
    fecha DATE,
    observacion VARCHAR(1000)
);

CREATE TYPE academico.reporte_monografia AS (
    cedula_estudiante VARCHAR(20),
    anio INTEGER,
    semestre academico.numero_semestre,
    observaciones VARCHAR(1000),
    enviado_en TIMESTAMPTZ
);

-- Guía CU06 y reporte de bandas: una fila por estudiante de la sección con monografía; observaciones NULL si el
-- coordinador no envió el reporte del semestre.
CREATE TYPE academico.reporte_monografia_seccion AS (
    cedula_estudiante VARCHAR(20),
    nombre_estudiante TEXT,
    codigo_asignatura VARCHAR(10),   -- área (materia de la monografía)
    asignatura TEXT,
    nombre_coordinador TEXT,
    estado academico.estado_monografia,
    observaciones VARCHAR(1000),
    enviado_en TIMESTAMPTZ
);

-- ------------------------------------------------------------
-- Helpers
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION academico.fn_monografias_detalle()
RETURNS TABLE(id_monografia BIGINT, id_estudiante BIGINT, id_coordinador BIGINT, id_usuario_coordinador UUID,
              apellidos_nombre TEXT, fila academico.monografia_detalle)
LANGUAGE sql STABLE
SET search_path = academico, auth, api, public
AS $$
    SELECT mo.id_monografia, mo.id_estudiante, mo.id_coordinador, pr.id_usuario,
           concat_ws(' ', e.primer_apellido, e.segundo_apellido, e.nombre),
           ROW(e.cedula, concat_ws(' ', e.primer_apellido, e.segundo_apellido) || ', ' || e.nombre,
               pi.anio, ult.anio, ult.seccion,
               pr.cedula, concat_ws(' ', pr.nombre, pr.primer_apellido, pr.segundo_apellido),
               asg.codigo, asg.nombre::TEXT, mo.estado,
               (SELECT COUNT(*)::INTEGER FROM academico.seguimientos_monografia sg WHERE sg.id_monografia = mo.id_monografia),
               (SELECT MAX(sg.fecha) FROM academico.seguimientos_monografia sg WHERE sg.id_monografia = mo.id_monografia)
              )::academico.monografia_detalle
    FROM academico.monografias mo
    JOIN academico.estudiantes e ON e.id_estudiante = mo.id_estudiante
    JOIN academico.matriculas mi ON mi.id_matricula = mo.id_matricula_inicio
    JOIN academico.periodos_academicos pi ON pi.id_periodo = mi.id_periodo
    JOIN academico.profesores pr ON pr.id_profesor = mo.id_coordinador
    JOIN academico.asignaturas asg ON asg.id_asignatura = mo.id_asignatura
    CROSS JOIN LATERAL (
        SELECT p.anio, s.nivel || '-' || s.numero AS seccion
        FROM academico.matriculas m
        JOIN academico.periodos_academicos p ON p.id_periodo = m.id_periodo
        JOIN academico.secciones s ON s.id_seccion = m.id_seccion
        WHERE m.id_estudiante = mo.id_estudiante
        ORDER BY p.anio DESC
        LIMIT 1
    ) ult;
$$;

-- Id de la monografía del estudiante. NF003 si el estudiante no existe; NF013 si no tiene monografía.
CREATE OR REPLACE FUNCTION academico.fn_obtener_id_monografia(p_cedula_estudiante TEXT)
RETURNS BIGINT
LANGUAGE plpgsql STABLE
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_id BIGINT;
    v_id_estudiante BIGINT := academico.fn_obtener_id_estudiante(p_cedula_estudiante);
BEGIN
    SELECT id_monografia INTO v_id FROM academico.monografias WHERE id_estudiante = v_id_estudiante;

    IF v_id IS NULL THEN
        PERFORM api.fn_lanzar_excepcion('NF013', 'El estudiante no tiene monografía.');
    END IF;

    RETURN v_id;
END;
$$;

-- Monografía que coordina el usuario, bloqueada para modificarla. NF013; AD006 si la coordina otro profesor.
CREATE OR REPLACE FUNCTION academico.fn_obtener_mi_monografia(p_id_usuario UUID, p_cedula_estudiante TEXT)
RETURNS academico.monografias
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_mono academico.monografias%ROWTYPE;
BEGIN
    SELECT mo.* INTO v_mono FROM academico.monografias mo
    WHERE mo.id_monografia = academico.fn_obtener_id_monografia(p_cedula_estudiante)
    FOR UPDATE;

    IF NOT EXISTS (SELECT 1 FROM academico.profesores pr
                   WHERE pr.id_profesor = v_mono.id_coordinador AND pr.id_usuario = p_id_usuario) THEN
        PERFORM api.fn_lanzar_excepcion('AD006', 'No coordinas esa monografía.');
    END IF;

    RETURN v_mono;
END;
$$;

-- RN-78: valida materia (MO002), coordinador (MO005) y cupo del grupo (MO003) de una monografía que empieza con
-- la matrícula p_id_matricula_inicio. p_id_monografia_excluida: la propia monografía al modificarla.
CREATE OR REPLACE FUNCTION academico.fn_validar_grupo_monografia(
    p_id_matricula_inicio BIGINT, p_id_coordinador BIGINT, p_id_asignatura BIGINT, p_id_monografia_excluida BIGINT)
RETURNS VOID
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_periodo academico.periodos_academicos%ROWTYPE;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM academico.asignaturas WHERE id_asignatura = p_id_asignatura AND tipo IN ('SUPERIOR', 'MEDIO')) THEN
        PERFORM api.fn_lanzar_excepcion('MO002', 'La materia de la monografía debe ser una asignatura SUPERIOR o MEDIO.');
    END IF;

    SELECT p.* INTO v_periodo
    FROM academico.matriculas m JOIN academico.periodos_academicos p ON p.id_periodo = m.id_periodo
    WHERE m.id_matricula = p_id_matricula_inicio;

    IF academico.fn_estado_periodo(v_periodo) <> 'FINALIZADO'
       AND NOT academico.fn_profesor_tiene_rol_activo(p_id_coordinador, 'COORD_MONOGRAFIA') THEN
        PERFORM api.fn_lanzar_excepcion('MO005', 'El coordinador debe tener un usuario activo con el rol COORD_MONOGRAFIA.');
    END IF;

    IF (SELECT COUNT(*)
        FROM academico.monografias mo
        JOIN academico.matriculas m ON m.id_matricula = mo.id_matricula_inicio
        WHERE mo.id_coordinador = p_id_coordinador AND mo.id_asignatura = p_id_asignatura
          AND m.id_periodo = v_periodo.id_periodo
          AND mo.id_monografia IS DISTINCT FROM p_id_monografia_excluida) >= 5 THEN
        PERFORM api.fn_lanzar_excepcion('MO003', 'El grupo del coordinador en esa materia ya tiene 5 estudiantes.');
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION academico.fn_snapshot_monografia(p_id_monografia BIGINT)
RETURNS JSONB
LANGUAGE sql STABLE
SET search_path = academico, auth, api, public
AS $$
    SELECT to_jsonb(d.fila) - 'seguimientos' - 'ultimo_seguimiento'
    FROM academico.fn_monografias_detalle() d WHERE d.id_monografia = p_id_monografia;
$$;

-- MO006 si la fecha del seguimiento es futura o anterior al inicio del periodo en que empezó la monografía.
CREATE OR REPLACE FUNCTION academico.fn_validar_fecha_seguimiento(p_id_monografia BIGINT, p_fecha DATE)
RETURNS VOID
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
BEGIN
    IF p_fecha IS NULL OR p_fecha > api.fn_hoy() OR p_fecha < (
        SELECT p.inicio_semestre_i
        FROM academico.monografias mo
        JOIN academico.matriculas m ON m.id_matricula = mo.id_matricula_inicio
        JOIN academico.periodos_academicos p ON p.id_periodo = m.id_periodo
        WHERE mo.id_monografia = p_id_monografia) THEN
        PERFORM api.fn_lanzar_excepcion('MO006', 'La fecha del seguimiento no es válida.');
    END IF;
END;
$$;

-- Seguimiento de una monografía que coordina el usuario, bloqueado. NF014 si no existe; AD006.
CREATE OR REPLACE FUNCTION academico.fn_obtener_mi_seguimiento(p_id_usuario UUID, p_id_seguimiento BIGINT)
RETURNS academico.seguimientos_monografia
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_seg academico.seguimientos_monografia%ROWTYPE;
BEGIN
    SELECT sg.* INTO v_seg FROM academico.seguimientos_monografia sg WHERE sg.id_seguimiento = p_id_seguimiento FOR UPDATE;

    IF NOT FOUND THEN
        PERFORM api.fn_lanzar_excepcion('NF014', 'El seguimiento no existe.');
    END IF;

    IF NOT EXISTS (SELECT 1 FROM academico.monografias mo
                   JOIN academico.profesores pr ON pr.id_profesor = mo.id_coordinador
                   WHERE mo.id_monografia = v_seg.id_monografia AND pr.id_usuario = p_id_usuario) THEN
        PERFORM api.fn_lanzar_excepcion('AD006', 'No coordinas esa monografía.');
    END IF;

    RETURN v_seg;
END;
$$;

CREATE OR REPLACE FUNCTION academico.fn_seguimientos_de(p_id_monografia BIGINT)
RETURNS SETOF academico.seguimiento_monografia
LANGUAGE sql STABLE
SET search_path = academico, auth, api, public
AS $$
    SELECT sg.id_seguimiento, e.cedula, sg.fecha, sg.observacion
    FROM academico.seguimientos_monografia sg
    JOIN academico.monografias mo ON mo.id_monografia = sg.id_monografia
    JOIN academico.estudiantes e ON e.id_estudiante = mo.id_estudiante
    WHERE sg.id_monografia = p_id_monografia
    ORDER BY sg.fecha DESC, sg.id_seguimiento DESC;
$$;

CREATE OR REPLACE FUNCTION academico.fn_reportes_de(p_id_monografia BIGINT)
RETURNS SETOF academico.reporte_monografia
LANGUAGE sql STABLE
SET search_path = academico, auth, api, public
AS $$
    SELECT e.cedula, p.anio, r.semestre, r.observaciones, r.enviado_en
    FROM academico.reportes_monografia r
    JOIN academico.periodos_academicos p ON p.id_periodo = r.id_periodo
    JOIN academico.monografias mo ON mo.id_monografia = r.id_monografia
    JOIN academico.estudiantes e ON e.id_estudiante = mo.id_estudiante
    WHERE r.id_monografia = p_id_monografia
    ORDER BY p.anio DESC, r.semestre DESC;
$$;

-- Reporte de monografía de los estudiantes a calificar de una sección en un semestre (RN-81). Lo usan el guía
-- (CU06) y el reporte de bandas.
CREATE OR REPLACE FUNCTION academico.fn_reportes_monografia_seccion(p_id_seccion BIGINT, p_semestre academico.numero_semestre)
RETURNS TABLE(id_matricula BIGINT, fila academico.reporte_monografia_seccion)
LANGUAGE plpgsql STABLE
SET search_path = academico, auth, api, public
AS $$
BEGIN
    RETURN QUERY
    SELECT ms.id_matricula,
           ROW((d.fila).cedula_estudiante, (d.fila).nombre_estudiante, (d.fila).codigo_asignatura, (d.fila).asignatura,
               (d.fila).nombre_coordinador, (d.fila).estado, r.observaciones, r.enviado_en)::academico.reporte_monografia_seccion
    FROM academico.fn_matriculas_del_semestre(p_id_seccion, p_semestre) ms
    JOIN academico.fn_monografias_detalle() d ON d.id_estudiante = ms.id_estudiante
    JOIN academico.secciones s ON s.id_seccion = p_id_seccion
    LEFT JOIN academico.reportes_monografia r
           ON r.id_monografia = d.id_monografia AND r.id_periodo = s.id_periodo AND r.semestre = p_semestre
    ORDER BY d.apellidos_nombre;
END;
$$;

-- ------------------------------------------------------------
-- Administrador CU34 - Asignar un estudiante a un coordinador de monografía (RN-78)
-- p_anio: año de la matrícula de nivel 10 del estudiante (MO004 si no es de nivel 10 o está retirada).
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION academico.fn_admin_registrar_monografia(
    p_id_usuario_actor UUID,
    p_anio INTEGER,
    p_cedula_estudiante TEXT,
    p_cedula_coordinador TEXT,
    p_codigo_asignatura TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_id_matricula BIGINT;
    v_matricula academico.matriculas%ROWTYPE;
    v_id_coordinador BIGINT;
    v_id_asignatura BIGINT;
BEGIN
    PERFORM api.fn_validar_admin_activo(p_id_usuario_actor);

    v_id_matricula := academico.fn_obtener_id_matricula(p_anio, p_cedula_estudiante);
    SELECT * INTO v_matricula FROM academico.matriculas WHERE id_matricula = v_id_matricula;

    IF v_matricula.fecha_retiro IS NOT NULL
       OR (SELECT nivel FROM academico.secciones WHERE id_seccion = v_matricula.id_seccion) <> 10 THEN
        PERFORM api.fn_lanzar_excepcion('MO004', 'La monografía empieza con una matrícula de nivel 10 sin retiro.');
    END IF;

    IF EXISTS (SELECT 1 FROM academico.monografias WHERE id_estudiante = v_matricula.id_estudiante) THEN
        PERFORM api.fn_lanzar_excepcion('MO001', 'El estudiante ya tiene monografía.');
    END IF;

    v_id_coordinador := academico.fn_obtener_id_profesor(p_cedula_coordinador);
    v_id_asignatura := academico.fn_obtener_id_asignatura(p_codigo_asignatura);
    PERFORM academico.fn_validar_grupo_monografia(v_id_matricula, v_id_coordinador, v_id_asignatura, NULL);

    INSERT INTO academico.monografias (id_estudiante, id_matricula_inicio, id_coordinador, id_asignatura)
    VALUES (v_matricula.id_estudiante, v_id_matricula, v_id_coordinador, v_id_asignatura);
END;
$$;

-- ------------------------------------------------------------
-- Administrador CU35 - Consultar monografías. Filtros opcionales: año de inicio, coordinador, materia y estado.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION academico.fn_monografias_filtradas(
    p_anio_inicio INTEGER, p_cedula_coordinador TEXT, p_codigo_asignatura TEXT, p_estado academico.estado_monografia)
RETURNS TABLE(apellidos_nombre TEXT, fila academico.monografia_detalle)
LANGUAGE sql STABLE
SET search_path = academico, auth, api, public
AS $$
    SELECT d.apellidos_nombre, d.fila
    FROM academico.fn_monografias_detalle() d
    WHERE (p_anio_inicio IS NULL OR (d.fila).anio_inicio = p_anio_inicio)
      AND (p_cedula_coordinador IS NULL OR (d.fila).cedula_coordinador = api.fn_limpiar(p_cedula_coordinador))
      AND (p_codigo_asignatura IS NULL OR (d.fila).codigo_asignatura = academico.fn_normalizar_codigo_asignatura(p_codigo_asignatura))
      AND (p_estado IS NULL OR (d.fila).estado = p_estado);
$$;

CREATE OR REPLACE FUNCTION academico.fn_admin_listar_monografias(
    p_anio_inicio INTEGER, p_cedula_coordinador TEXT, p_codigo_asignatura TEXT, p_estado academico.estado_monografia,
    p_pagina INTEGER, p_tamano_pagina INTEGER)
RETURNS SETOF academico.monografia_detalle
LANGUAGE sql STABLE
SET search_path = academico, auth, api, public
AS $$
    SELECT (f.fila).*
    FROM academico.fn_monografias_filtradas(p_anio_inicio, p_cedula_coordinador, p_codigo_asignatura, p_estado) f
    ORDER BY (f.fila).anio_inicio DESC, f.apellidos_nombre
    LIMIT api.fn_tamano_pagina(p_tamano_pagina) OFFSET api.fn_offset(p_pagina, p_tamano_pagina);
$$;

CREATE OR REPLACE FUNCTION academico.fn_admin_contar_monografias(
    p_anio_inicio INTEGER, p_cedula_coordinador TEXT, p_codigo_asignatura TEXT, p_estado academico.estado_monografia)
RETURNS BIGINT
LANGUAGE sql STABLE
SET search_path = academico, auth, api, public
AS $$
    SELECT COUNT(*) FROM academico.fn_monografias_filtradas(p_anio_inicio, p_cedula_coordinador, p_codigo_asignatura, p_estado);
$$;

CREATE OR REPLACE FUNCTION academico.fn_admin_obtener_monografia(p_cedula_estudiante TEXT)
RETURNS SETOF academico.monografia_detalle
LANGUAGE plpgsql STABLE
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_id BIGINT := academico.fn_obtener_id_monografia(p_cedula_estudiante);
BEGIN
    RETURN QUERY SELECT (d.fila).* FROM academico.fn_monografias_detalle() d WHERE d.id_monografia = v_id;
END;
$$;

-- ------------------------------------------------------------
-- Administrador CU36 - Modificar la asignación: cambiar coordinador y/o materia (RN-78). Conserva el estado, el
-- seguimiento y los reportes. Devuelve 'OK' o 'SIN_CAMBIOS' y el snapshot previo.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION academico.fn_admin_modificar_monografia(
    p_id_usuario_actor UUID,
    p_cedula_estudiante TEXT,
    p_cedula_coordinador TEXT,
    p_codigo_asignatura TEXT,
    OUT out_status TEXT,
    OUT out_datos_anteriores JSONB
)
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_mono academico.monografias%ROWTYPE;
    v_id_coordinador BIGINT;
    v_id_asignatura BIGINT;
BEGIN
    PERFORM api.fn_validar_admin_activo(p_id_usuario_actor);

    SELECT * INTO v_mono FROM academico.monografias
    WHERE id_monografia = academico.fn_obtener_id_monografia(p_cedula_estudiante) FOR UPDATE;
    v_id_coordinador := academico.fn_obtener_id_profesor(p_cedula_coordinador);
    v_id_asignatura := academico.fn_obtener_id_asignatura(p_codigo_asignatura);

    IF (v_mono.id_coordinador, v_mono.id_asignatura) = (v_id_coordinador, v_id_asignatura) THEN
        out_status := 'SIN_CAMBIOS';
        RETURN;
    END IF;

    PERFORM academico.fn_validar_grupo_monografia(v_mono.id_matricula_inicio, v_id_coordinador, v_id_asignatura, v_mono.id_monografia);

    out_datos_anteriores := academico.fn_snapshot_monografia(v_mono.id_monografia);
    UPDATE academico.monografias SET id_coordinador = v_id_coordinador, id_asignatura = v_id_asignatura
    WHERE id_monografia = v_mono.id_monografia;
    out_status := 'OK';
END;
$$;

-- ------------------------------------------------------------
-- Administrador CU37 - Eliminar la monografía. 23001 si ya tiene seguimiento o reportes. Devuelve el snapshot.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION academico.fn_admin_eliminar_monografia(p_id_usuario_actor UUID, p_cedula_estudiante TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_id BIGINT;
    v_prev JSONB;
BEGIN
    PERFORM api.fn_validar_admin_activo(p_id_usuario_actor);
    v_id := academico.fn_obtener_id_monografia(p_cedula_estudiante);
    v_prev := academico.fn_snapshot_monografia(v_id);
    DELETE FROM academico.monografias WHERE id_monografia = v_id;
    RETURN v_prev;
END;
$$;

-- ------------------------------------------------------------
-- Coordinador CU01 - Consultar el estado de mis monografías (filtros opcionales: año de inicio y estado)
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION academico.fn_coordinador_listar_monografias(
    p_id_usuario UUID, p_anio_inicio INTEGER, p_estado academico.estado_monografia)
RETURNS SETOF academico.monografia_detalle
LANGUAGE sql STABLE
SET search_path = academico, auth, api, public
AS $$
    SELECT (d.fila).*
    FROM academico.fn_monografias_detalle() d
    WHERE d.id_usuario_coordinador = p_id_usuario
      AND (p_anio_inicio IS NULL OR (d.fila).anio_inicio = p_anio_inicio)
      AND (p_estado IS NULL OR (d.fila).estado = p_estado)
    ORDER BY (d.fila).anio_inicio DESC, (d.fila).asignatura, d.apellidos_nombre;
$$;

-- Una monografía que coordino (NF013 / AD006).
CREATE OR REPLACE FUNCTION academico.fn_coordinador_obtener_monografia(p_id_usuario UUID, p_cedula_estudiante TEXT)
RETURNS SETOF academico.monografia_detalle
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_mono academico.monografias := academico.fn_obtener_mi_monografia(p_id_usuario, p_cedula_estudiante);
BEGIN
    RETURN QUERY SELECT (d.fila).* FROM academico.fn_monografias_detalle() d WHERE d.id_monografia = v_mono.id_monografia;
END;
$$;

CREATE OR REPLACE FUNCTION academico.fn_coordinador_listar_seguimientos(p_id_usuario UUID, p_cedula_estudiante TEXT)
RETURNS SETOF academico.seguimiento_monografia
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_mono academico.monografias := academico.fn_obtener_mi_monografia(p_id_usuario, p_cedula_estudiante);
BEGIN
    RETURN QUERY SELECT * FROM academico.fn_seguimientos_de(v_mono.id_monografia);
END;
$$;

CREATE OR REPLACE FUNCTION academico.fn_coordinador_listar_reportes(p_id_usuario UUID, p_cedula_estudiante TEXT)
RETURNS SETOF academico.reporte_monografia
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_mono academico.monografias := academico.fn_obtener_mi_monografia(p_id_usuario, p_cedula_estudiante);
BEGIN
    RETURN QUERY SELECT * FROM academico.fn_reportes_de(v_mono.id_monografia);
END;
$$;

-- ------------------------------------------------------------
-- Coordinador CU02 - Modificar el estado (RN-79). Devuelve 'OK' o 'SIN_CAMBIOS' y el snapshot previo.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION academico.fn_coordinador_cambiar_estado_monografia(
    p_id_usuario UUID,
    p_cedula_estudiante TEXT,
    p_estado academico.estado_monografia,
    OUT out_status TEXT,
    OUT out_datos_anteriores JSONB
)
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_mono academico.monografias := academico.fn_obtener_mi_monografia(p_id_usuario, p_cedula_estudiante);
BEGIN
    IF v_mono.estado = p_estado THEN
        out_status := 'SIN_CAMBIOS';
        RETURN;
    END IF;

    out_datos_anteriores := academico.fn_snapshot_monografia(v_mono.id_monografia);
    UPDATE academico.monografias SET estado = p_estado WHERE id_monografia = v_mono.id_monografia;
    out_status := 'OK';
END;
$$;

-- ------------------------------------------------------------
-- Coordinador CU03 - Registrar seguimiento (RN-80). Devuelve el id. MO006 fecha inválida.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION academico.fn_coordinador_registrar_seguimiento(
    p_id_usuario UUID, p_cedula_estudiante TEXT, p_fecha DATE, p_observacion TEXT)
RETURNS BIGINT
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_mono academico.monografias := academico.fn_obtener_mi_monografia(p_id_usuario, p_cedula_estudiante);
    v_fecha DATE := COALESCE(p_fecha, api.fn_hoy());
    v_id BIGINT;
BEGIN
    PERFORM academico.fn_validar_fecha_seguimiento(v_mono.id_monografia, v_fecha);

    INSERT INTO academico.seguimientos_monografia (id_monografia, fecha, observacion)
    VALUES (v_mono.id_monografia, v_fecha, api.fn_limpiar(p_observacion))
    RETURNING id_seguimiento INTO v_id;

    RETURN v_id;
END;
$$;

-- ------------------------------------------------------------
-- Coordinador CU04 - Modificar o eliminar un seguimiento. NF014 / AD006 / MO006.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION academico.fn_coordinador_modificar_seguimiento(
    p_id_usuario UUID,
    p_id_seguimiento BIGINT,
    p_fecha DATE,
    p_observacion TEXT,
    OUT out_status TEXT,
    OUT out_datos_anteriores JSONB
)
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_seg academico.seguimientos_monografia := academico.fn_obtener_mi_seguimiento(p_id_usuario, p_id_seguimiento);
    v_observacion TEXT := api.fn_limpiar(p_observacion);
BEGIN
    PERFORM academico.fn_validar_fecha_seguimiento(v_seg.id_monografia, p_fecha);

    IF (v_seg.fecha, v_seg.observacion::TEXT) IS NOT DISTINCT FROM (p_fecha, v_observacion) THEN
        out_status := 'SIN_CAMBIOS';
        RETURN;
    END IF;

    out_datos_anteriores := (SELECT to_jsonb(s) FROM academico.fn_seguimientos_de(v_seg.id_monografia) s
                             WHERE s.id_seguimiento = p_id_seguimiento);
    UPDATE academico.seguimientos_monografia SET fecha = p_fecha, observacion = v_observacion
    WHERE id_seguimiento = p_id_seguimiento;
    out_status := 'OK';
END;
$$;

CREATE OR REPLACE FUNCTION academico.fn_coordinador_eliminar_seguimiento(p_id_usuario UUID, p_id_seguimiento BIGINT)
RETURNS JSONB
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_seg academico.seguimientos_monografia := academico.fn_obtener_mi_seguimiento(p_id_usuario, p_id_seguimiento);
    v_prev JSONB;
BEGIN
    SELECT to_jsonb(s) INTO v_prev FROM academico.fn_seguimientos_de(v_seg.id_monografia) s WHERE s.id_seguimiento = p_id_seguimiento;
    DELETE FROM academico.seguimientos_monografia WHERE id_seguimiento = p_id_seguimiento;
    RETURN v_prev;
END;
$$;

-- ------------------------------------------------------------
-- Coordinador CU05 - Enviar el reporte de monografía al guía (RN-81): observaciones del semestre, que salen en el
-- reporte de bandas. Se puede corregir hasta el cierre del semestre (EV002 / EV003, con la prórroga del
-- coordinador). NF009 si el estudiante no tiene matrícula ese año. Devuelve 'OK' o 'SIN_CAMBIOS' y el previo.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION academico.fn_coordinador_enviar_reporte_monografia(
    p_id_usuario UUID,
    p_cedula_estudiante TEXT,
    p_anio INTEGER,
    p_semestre academico.numero_semestre,
    p_observaciones TEXT,
    OUT out_status TEXT,
    OUT out_datos_anteriores JSONB
)
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_mono academico.monografias := academico.fn_obtener_mi_monografia(p_id_usuario, p_cedula_estudiante);
    v_id_matricula BIGINT := academico.fn_obtener_id_matricula(p_anio, p_cedula_estudiante);
    v_periodo academico.periodos_academicos%ROWTYPE;
    v_prev academico.reportes_monografia%ROWTYPE;
    v_observaciones TEXT := api.fn_limpiar(p_observaciones);
BEGIN
    SELECT p.* INTO v_periodo FROM academico.periodos_academicos p
    JOIN academico.matriculas m ON m.id_periodo = p.id_periodo WHERE m.id_matricula = v_id_matricula;
    PERFORM academico.fn_validar_plazo_notas(v_mono.id_coordinador, v_periodo, p_semestre);

    SELECT * INTO v_prev FROM academico.reportes_monografia
    WHERE id_monografia = v_mono.id_monografia AND id_periodo = v_periodo.id_periodo AND semestre = p_semestre
    FOR UPDATE;

    IF FOUND THEN
        IF v_prev.observaciones::TEXT IS NOT DISTINCT FROM v_observaciones THEN
            out_status := 'SIN_CAMBIOS';
            RETURN;
        END IF;
        out_datos_anteriores := jsonb_build_object('anio', p_anio, 'semestre', p_semestre, 'observaciones', v_prev.observaciones);
        UPDATE academico.reportes_monografia SET observaciones = v_observaciones, enviado_en = NOW()
        WHERE id_monografia = v_mono.id_monografia AND id_periodo = v_periodo.id_periodo AND semestre = p_semestre;
    ELSE
        INSERT INTO academico.reportes_monografia (id_monografia, id_periodo, semestre, observaciones)
        VALUES (v_mono.id_monografia, v_periodo.id_periodo, p_semestre, v_observaciones);
    END IF;

    out_status := 'OK';
END;
$$;

-- Coordinador CU05 - Retirar el reporte del semestre (corrección), en el mismo plazo. NF017 si no existe.
-- Devuelve el reporte previo.
CREATE OR REPLACE FUNCTION academico.fn_coordinador_eliminar_reporte_monografia(
    p_id_usuario UUID, p_cedula_estudiante TEXT, p_anio INTEGER, p_semestre academico.numero_semestre)
RETURNS JSONB
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_mono academico.monografias := academico.fn_obtener_mi_monografia(p_id_usuario, p_cedula_estudiante);
    v_periodo academico.periodos_academicos%ROWTYPE;
    v_prev academico.reportes_monografia%ROWTYPE;
BEGIN
    SELECT * INTO v_periodo FROM academico.periodos_academicos WHERE anio = p_anio;
    IF NOT FOUND THEN
        PERFORM api.fn_lanzar_excepcion('NF004', 'El periodo académico no existe.');
    END IF;
    PERFORM academico.fn_validar_plazo_notas(v_mono.id_coordinador, v_periodo, p_semestre);

    DELETE FROM academico.reportes_monografia
    WHERE id_monografia = v_mono.id_monografia AND id_periodo = v_periodo.id_periodo AND semestre = p_semestre
    RETURNING * INTO v_prev;

    IF v_prev.id_monografia IS NULL THEN
        PERFORM api.fn_lanzar_excepcion('NF017', 'El reporte de monografía no existe.');
    END IF;

    RETURN jsonb_build_object('anio', p_anio, 'semestre', p_semestre, 'observaciones', v_prev.observaciones);
END;
$$;

-- ------------------------------------------------------------
-- Guía CU06 - Reportes de monografía de mi sección guía en un semestre (AD005). p_cedula_estudiante NULL = todos
-- (el reporte de bandas de un estudiante lo filtra).
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION academico.fn_guia_reportes_monografia(
    p_id_usuario UUID, p_anio INTEGER, p_nivel INTEGER, p_numero INTEGER, p_semestre academico.numero_semestre,
    p_cedula_estudiante TEXT)
RETURNS SETOF academico.reporte_monografia_seccion
LANGUAGE plpgsql STABLE
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_id_seccion BIGINT := academico.fn_validar_guia_seccion(p_id_usuario, p_anio, p_nivel, p_numero);
BEGIN
    RETURN QUERY
    SELECT (r.fila).* FROM academico.fn_reportes_monografia_seccion(v_id_seccion, p_semestre) r
    WHERE p_cedula_estudiante IS NULL OR (r.fila).cedula_estudiante = api.fn_limpiar(p_cedula_estudiante);
END;
$$;

-- ------------------------------------------------------------
-- Guía CU07 - Verificar las monografías de mi sección guía: estado y seguimiento (RN-79, RN-80). AD005.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION academico.fn_guia_listar_monografias(p_id_usuario UUID, p_anio INTEGER, p_nivel INTEGER, p_numero INTEGER)
RETURNS SETOF academico.monografia_detalle
LANGUAGE plpgsql STABLE
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_id_seccion BIGINT := academico.fn_validar_guia_seccion(p_id_usuario, p_anio, p_nivel, p_numero);
BEGIN
    RETURN QUERY
    SELECT (d.fila).*
    FROM academico.fn_monografias_detalle() d
    WHERE EXISTS (SELECT 1 FROM academico.matriculas m WHERE m.id_seccion = v_id_seccion AND m.id_estudiante = d.id_estudiante)
    ORDER BY d.apellidos_nombre;
END;
$$;

CREATE OR REPLACE FUNCTION academico.fn_guia_listar_seguimientos(p_id_usuario UUID, p_anio INTEGER, p_nivel INTEGER, p_numero INTEGER)
RETURNS SETOF academico.seguimiento_monografia
LANGUAGE plpgsql STABLE
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_id_seccion BIGINT := academico.fn_validar_guia_seccion(p_id_usuario, p_anio, p_nivel, p_numero);
BEGIN
    RETURN QUERY
    SELECT s.*
    FROM academico.monografias mo
    CROSS JOIN LATERAL academico.fn_seguimientos_de(mo.id_monografia) s
    WHERE EXISTS (SELECT 1 FROM academico.matriculas m WHERE m.id_seccion = v_id_seccion AND m.id_estudiante = mo.id_estudiante);
END;
$$;
