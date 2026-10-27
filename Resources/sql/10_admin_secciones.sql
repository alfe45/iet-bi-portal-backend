-- ============================================================
-- 10_admin_secciones.sql: CU 13 a 16 (admin) + Guía CU01 (mis secciones guía). Se opera SIEMPRE por (año, nivel, número), nunca por id_seccion.
-- El ADMIN puede trabajar sobre periodos pasados (digitalización); las reglas operativas del guía
-- (usuario activo con rol GUIA) solo se exigen en periodos no finalizados.
-- ============================================================
SET search_path = academico, api, auth, public;

CREATE TYPE academico.seccion_admin AS (
    anio INTEGER,
    nivel SMALLINT,
    numero SMALLINT,
    nombre TEXT,                 -- "11-1"
    cedula_guia VARCHAR(20),
    nombre_guia TEXT,            -- NULL si no tiene guía
    cantidad_estudiantes BIGINT  -- matrículas no retiradas
);

-- ------------------------------------------------------------
-- Helpers
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION academico.fn_a_seccion_admin(s academico.secciones)
RETURNS academico.seccion_admin
LANGUAGE sql STABLE
SET search_path = academico, auth, api, public
AS $$
    SELECT ROW(
        p.anio, s.nivel, s.numero, s.nivel || '-' || s.numero,
        g.cedula,
        CASE WHEN g.id_profesor IS NULL THEN NULL
             ELSE concat_ws(' ', g.nombre, g.primer_apellido, g.segundo_apellido) END,
        (SELECT COUNT(*) FROM academico.matriculas m WHERE m.id_seccion = s.id_seccion AND m.fecha_retiro IS NULL)
    )::academico.seccion_admin
    FROM academico.periodos_academicos p
    LEFT JOIN academico.profesores g ON g.id_profesor = s.id_profesor_guia
    WHERE p.id_periodo = s.id_periodo;
$$;

-- Id interno de la sección para usarlo como FK en otros módulos. NF006 si no existe.
CREATE OR REPLACE FUNCTION academico.fn_obtener_id_seccion(p_anio INTEGER, p_nivel INTEGER, p_numero INTEGER)
RETURNS BIGINT
LANGUAGE plpgsql STABLE
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_id BIGINT;
BEGIN
    SELECT s.id_seccion INTO v_id
    FROM academico.secciones s
    JOIN academico.periodos_academicos p ON p.id_periodo = s.id_periodo
    WHERE p.anio = p_anio AND s.nivel = p_nivel AND s.numero = p_numero;

    IF v_id IS NULL THEN
        PERFORM api.fn_lanzar_excepcion('NF006', 'La sección no existe.');
    END IF;

    RETURN v_id;
END;
$$;

-- TRUE si existe la sección (año, nivel, número).
CREATE OR REPLACE FUNCTION academico.fn_existe_seccion(p_anio INTEGER, p_nivel INTEGER, p_numero INTEGER)
RETURNS BOOLEAN
LANGUAGE sql STABLE
SET search_path = academico, auth, api, public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM academico.secciones s
        JOIN academico.periodos_academicos p ON p.id_periodo = s.id_periodo
        WHERE p.anio = p_anio AND s.nivel = p_nivel AND s.numero = p_numero);
$$;

-- RP-57: bloquea (FOR SHARE) la sección 11-N del año anterior a p_anio; FALSE si no existe. La usan crear la 12-N y
-- subir la sección; eliminar la 11-N la bloquea FOR UPDATE.
CREATE OR REPLACE FUNCTION academico.fn_bloquear_seccion_11_anterior(p_anio INTEGER, p_numero INTEGER)
RETURNS BOOLEAN
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
BEGIN
    PERFORM 1 FROM academico.secciones s
    JOIN academico.periodos_academicos p ON p.id_periodo = s.id_periodo
    WHERE p.anio = p_anio - 1 AND s.nivel = 11 AND s.numero = p_numero
    FOR SHARE OF s;
    RETURN FOUND;
END;
$$;

-- CU 13 - Registrar sección. Devuelve el nombre ("11-1"). Una sección de nivel 12 solo se crea si
-- existió la 11-N del año anterior (SE005, RN-62). Registrada a mano nace sin guía ni asignaciones; subir la
-- sección (fn_admin_subir_seccion) sí copia los profesores de la 11-N (RN-63).
CREATE OR REPLACE FUNCTION academico.fn_admin_registrar_seccion(
    p_id_usuario_actor UUID,
    p_anio INTEGER,
    p_nivel INTEGER,
    p_numero INTEGER
)
RETURNS TEXT
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_id_periodo BIGINT;
BEGIN
    PERFORM api.fn_validar_admin_activo(p_id_usuario_actor);

    SELECT id_periodo INTO v_id_periodo FROM academico.periodos_academicos WHERE anio = p_anio;
    IF v_id_periodo IS NULL THEN
        PERFORM api.fn_lanzar_excepcion('NF004', 'El periodo académico no existe.');
    END IF;

    IF p_nivel IS NULL OR p_nivel NOT IN (11, 12) OR p_numero IS NULL OR p_numero NOT BETWEEN 1 AND 99 THEN
        PERFORM api.fn_lanzar_excepcion('SE002', 'La sección no es válida.');
    END IF;

    IF EXISTS (SELECT 1 FROM academico.secciones
               WHERE id_periodo = v_id_periodo AND nivel = p_nivel AND numero = p_numero) THEN
        PERFORM api.fn_lanzar_excepcion('SE001', 'Ya existe esa sección en el periodo.');
    END IF;

    -- RN-62: la sección de nivel 12 es la continuación de la 11-N del año anterior (la sección sube completa).
    -- FOR SHARE (RP-57): si a la vez se elimina la 11-N, una de las dos espera y ve el resultado de la otra.
    IF p_nivel = 12 AND NOT academico.fn_bloquear_seccion_11_anterior(p_anio, p_numero) THEN
        PERFORM api.fn_lanzar_excepcion('SE005', 'Para crear la sección de nivel 12 debe existir la sección de nivel 11 con el mismo número el año anterior.');
    END IF;

    INSERT INTO academico.secciones (id_periodo, nivel, numero)
    VALUES (v_id_periodo, p_nivel, p_numero);

    RETURN p_nivel || '-' || p_numero;
END;
$$;

-- CU 14 - Consultar secciones. Filtros opcionales por año y nivel (NULL = todos).
CREATE OR REPLACE FUNCTION academico.fn_admin_listar_secciones(p_id_usuario_actor UUID, 
    p_anio INTEGER, p_nivel INTEGER, p_pagina INTEGER, p_tamano_pagina INTEGER)
RETURNS SETOF academico.seccion_admin
LANGUAGE sql STABLE
SET search_path = academico, auth, api, public
AS $$
    SELECT api.fn_validar_admin_activo(p_id_usuario_actor);   -- RP-12 (las lecturas también)
    SELECT f.*   -- LATERAL: (f(s)).* llamaría a la función una vez por columna
    FROM academico.secciones s
    JOIN academico.periodos_academicos p ON p.id_periodo = s.id_periodo
    CROSS JOIN LATERAL academico.fn_a_seccion_admin(s) f
    WHERE (p_anio IS NULL OR p.anio = p_anio)
      AND (p_nivel IS NULL OR s.nivel = p_nivel)
    ORDER BY p.anio DESC, s.nivel, s.numero
    LIMIT api.fn_tamano_pagina(p_tamano_pagina)
    OFFSET api.fn_offset(p_pagina, p_tamano_pagina);
$$;

CREATE OR REPLACE FUNCTION academico.fn_admin_contar_secciones(p_id_usuario_actor UUID, p_anio INTEGER, p_nivel INTEGER)
RETURNS BIGINT
LANGUAGE sql STABLE
SET search_path = academico, auth, api, public
AS $$
    SELECT api.fn_validar_admin_activo(p_id_usuario_actor);   -- RP-12 (las lecturas también)
    SELECT COUNT(*)
    FROM academico.secciones s
    JOIN academico.periodos_academicos p ON p.id_periodo = s.id_periodo
    WHERE (p_anio IS NULL OR p.anio = p_anio)
      AND (p_nivel IS NULL OR s.nivel = p_nivel);
$$;

CREATE OR REPLACE FUNCTION academico.fn_admin_obtener_seccion(p_id_usuario_actor UUID, p_anio INTEGER, p_nivel INTEGER, p_numero INTEGER)
RETURNS SETOF academico.seccion_admin
LANGUAGE sql STABLE
SET search_path = academico, auth, api, public
AS $$
    SELECT api.fn_validar_admin_activo(p_id_usuario_actor);   -- RP-12 (las lecturas también)
    SELECT f.*
    FROM academico.secciones s
    JOIN academico.periodos_academicos p ON p.id_periodo = s.id_periodo
    CROSS JOIN LATERAL academico.fn_a_seccion_admin(s) f
    WHERE p.anio = p_anio AND s.nivel = p_nivel AND s.numero = p_numero;
$$;

-- CU 15 - Eliminar sección. Devuelve el snapshot previo. Una 11-N que ya continúa como 12-N el año
-- siguiente no se elimina (SE006, RN-62). Si otras entidades la referencian (matrículas,
-- asignaciones...) con FK RESTRICT, Postgres lanza 23503.
CREATE OR REPLACE FUNCTION academico.fn_admin_eliminar_seccion(
    p_id_usuario_actor UUID,
    p_anio INTEGER,
    p_nivel INTEGER,
    p_numero INTEGER
)
RETURNS JSONB
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_id_seccion BIGINT;
    v_seccion academico.secciones%ROWTYPE;
    v_prev JSONB;
BEGIN
    PERFORM api.fn_validar_admin_activo(p_id_usuario_actor);

    v_id_seccion := academico.fn_obtener_id_seccion(p_anio, p_nivel, p_numero);
    SELECT * INTO v_seccion
    FROM academico.secciones
    WHERE id_seccion = v_id_seccion
    FOR UPDATE;

    IF p_nivel = 11 AND academico.fn_existe_seccion(p_anio + 1, 12, p_numero) THEN
        PERFORM api.fn_lanzar_excepcion('SE006', 'La sección de nivel 11 ya continúa en nivel 12 el año siguiente.');
    END IF;

    v_prev := to_jsonb(academico.fn_a_seccion_admin(v_seccion));

    DELETE FROM academico.secciones WHERE id_seccion = v_seccion.id_seccion;

    RETURN v_prev;
END;
$$;

-- CU 16 - Asociar (o reemplazar) el profesor guía de una sección. Devuelve 'OK' o 'SIN_CAMBIOS'
-- y el snapshot previo. En periodos no finalizados el profesor debe tener usuario activo con rol
-- GUIA (SE003). Un profesor es guía de una sola sección por periodo (SE004).
CREATE OR REPLACE FUNCTION academico.fn_admin_asignar_guia_seccion(
    p_id_usuario_actor UUID,
    p_anio INTEGER,
    p_nivel INTEGER,
    p_numero INTEGER,
    p_cedula_profesor TEXT
)
RETURNS TABLE(out_status TEXT, out_datos_anteriores JSONB)
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_id_seccion BIGINT;
    v_seccion academico.secciones%ROWTYPE;
    v_profesor academico.profesores%ROWTYPE;
    v_periodo academico.periodos_academicos%ROWTYPE;
    v_prev JSONB;
BEGIN
    PERFORM api.fn_validar_admin_activo(p_id_usuario_actor);

    v_id_seccion := academico.fn_obtener_id_seccion(p_anio, p_nivel, p_numero);
    SELECT * INTO v_seccion
    FROM academico.secciones
    WHERE id_seccion = v_id_seccion
    FOR UPDATE;

    SELECT * INTO v_profesor FROM academico.profesores WHERE cedula = api.fn_limpiar_cedula(p_cedula_profesor);
    IF NOT FOUND THEN
        PERFORM api.fn_lanzar_excepcion('NF002', 'El profesor no existe.');
    END IF;

    IF v_seccion.id_profesor_guia IS NOT DISTINCT FROM v_profesor.id_profesor THEN
        RETURN QUERY SELECT 'SIN_CAMBIOS'::TEXT, NULL::JSONB;
        RETURN;
    END IF;

    SELECT * INTO v_periodo FROM academico.periodos_academicos WHERE id_periodo = v_seccion.id_periodo;

    IF academico.fn_estado_periodo(v_periodo) <> 'FINALIZADO'
       AND NOT academico.fn_profesor_tiene_rol_activo(v_profesor.id_profesor, 'GUIA') THEN
        PERFORM api.fn_lanzar_excepcion('SE003', 'El profesor debe tener un usuario activo con el rol GUIA.');
    END IF;

    IF EXISTS (SELECT 1 FROM academico.secciones
               WHERE id_periodo = v_seccion.id_periodo AND id_profesor_guia = v_profesor.id_profesor) THEN
        PERFORM api.fn_lanzar_excepcion('SE004', 'El profesor ya es guía de otra sección en ese periodo.');
    END IF;

    v_prev := to_jsonb(academico.fn_a_seccion_admin(v_seccion));

    UPDATE academico.secciones SET id_profesor_guia = v_profesor.id_profesor
    WHERE id_seccion = v_seccion.id_seccion;

    RETURN QUERY SELECT 'OK'::TEXT, v_prev;
END;
$$;

-- CU 16 - Quitar el profesor guía de una sección. Devuelve 'OK' o 'SIN_CAMBIOS' (no tenía guía)
-- y el snapshot previo.
CREATE OR REPLACE FUNCTION academico.fn_admin_quitar_guia_seccion(
    p_id_usuario_actor UUID,
    p_anio INTEGER,
    p_nivel INTEGER,
    p_numero INTEGER
)
RETURNS TABLE(out_status TEXT, out_datos_anteriores JSONB)
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_id_seccion BIGINT;
    v_seccion academico.secciones%ROWTYPE;
    v_prev JSONB;
BEGIN
    PERFORM api.fn_validar_admin_activo(p_id_usuario_actor);

    v_id_seccion := academico.fn_obtener_id_seccion(p_anio, p_nivel, p_numero);
    SELECT * INTO v_seccion
    FROM academico.secciones
    WHERE id_seccion = v_id_seccion
    FOR UPDATE;

    IF v_seccion.id_profesor_guia IS NULL THEN
        RETURN QUERY SELECT 'SIN_CAMBIOS'::TEXT, NULL::JSONB;
        RETURN;
    END IF;

    v_prev := to_jsonb(academico.fn_a_seccion_admin(v_seccion));

    UPDATE academico.secciones SET id_profesor_guia = NULL WHERE id_seccion = v_seccion.id_seccion;

    RETURN QUERY SELECT 'OK'::TEXT, v_prev;
END;
$$;

-- Guía CU01 - Secciones de las que el usuario es profesor guía en un año (p_anio NULL = periodo en
-- curso; NF005 si no hay). Normalmente una (un guía por sección y una sección por periodo, RN-36).
CREATE OR REPLACE FUNCTION academico.fn_profesor_listar_mis_secciones_guia(p_id_usuario UUID, p_anio INTEGER)
RETURNS SETOF academico.seccion_admin
LANGUAGE plpgsql STABLE
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_anio INTEGER := p_anio;
BEGIN
    IF v_anio IS NULL THEN
        SELECT anio INTO v_anio FROM academico.fn_periodo_actual();
        IF v_anio IS NULL THEN
            PERFORM api.fn_lanzar_excepcion('NF005', 'No hay un periodo académico en curso.');
        END IF;
    END IF;

    RETURN QUERY
    SELECT f.*
    FROM academico.secciones s
    JOIN academico.periodos_academicos p ON p.id_periodo = s.id_periodo
    JOIN academico.profesores pr ON pr.id_profesor = s.id_profesor_guia
    CROSS JOIN LATERAL academico.fn_a_seccion_admin(s) f
    WHERE pr.id_usuario = p_id_usuario AND p.anio = v_anio
    ORDER BY s.nivel, s.numero;
END;
$$;
