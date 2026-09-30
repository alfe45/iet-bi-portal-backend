-- ============================================================
-- 09_admin_periodos.sql: CU 14 a 17 + periodo/semestre actual y cierres.
-- Se opera SIEMPRE por año (nunca por id_periodo). El año es inmutable.
-- "Hoy" es api.fn_hoy() (hora de Costa Rica). Un semestre queda cerrado cuando pasa su fecha de fin.
-- El cierre aplica a la operación de los profesores (fn_validar_*_abierto). El ADMIN puede registrar
-- y corregir periodos pasados para digitalizar información histórica.
-- ============================================================
SET search_path = academico, api, auth, public;

CREATE TYPE academico.periodo_admin AS (
    anio INTEGER,
    inicio_semestre_i DATE,
    fin_semestre_i DATE,
    inicio_semestre_ii DATE,
    fin_semestre_ii DATE,
    estado academico.estado_periodo,
    semestre_actual academico.numero_semestre   -- NULL fuera de los semestres (receso o periodo no en curso)
);

-- ------------------------------------------------------------
-- Estado y semestre según la fecha actual
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION academico.fn_estado_periodo(p academico.periodos_academicos)
RETURNS academico.estado_periodo
LANGUAGE sql STABLE
SET search_path = academico, auth, api, public
AS $$
    SELECT CASE
        WHEN api.fn_hoy() < p.inicio_semestre_i THEN 'PROGRAMADO'
        WHEN api.fn_hoy() > p.fin_semestre_ii THEN 'FINALIZADO'
        ELSE 'EN_CURSO'
    END::academico.estado_periodo;
$$;

CREATE OR REPLACE FUNCTION academico.fn_semestre_en_fecha(p academico.periodos_academicos, p_fecha DATE)
RETURNS academico.numero_semestre
LANGUAGE sql IMMUTABLE
AS $$
    SELECT CASE
        WHEN p_fecha BETWEEN p.inicio_semestre_i AND p.fin_semestre_i THEN 'I_SEMESTRE'
        WHEN p_fecha BETWEEN p.inicio_semestre_ii AND p.fin_semestre_ii THEN 'II_SEMESTRE'
    END::academico.numero_semestre;
$$;

CREATE OR REPLACE FUNCTION academico.fn_fin_semestre(p academico.periodos_academicos, p_semestre academico.numero_semestre)
RETURNS DATE
LANGUAGE sql IMMUTABLE
AS $$
    SELECT CASE p_semestre WHEN 'I_SEMESTRE' THEN p.fin_semestre_i ELSE p.fin_semestre_ii END;
$$;

CREATE OR REPLACE FUNCTION academico.fn_a_periodo_admin(p academico.periodos_academicos)
RETURNS academico.periodo_admin
LANGUAGE sql STABLE
SET search_path = academico, auth, api, public
AS $$
    SELECT ROW(p.anio, p.inicio_semestre_i, p.fin_semestre_i, p.inicio_semestre_ii, p.fin_semestre_ii,
               academico.fn_estado_periodo(p), academico.fn_semestre_en_fecha(p, api.fn_hoy()))::academico.periodo_admin;
$$;

-- ------------------------------------------------------------
-- Periodo actual: el que contiene la fecha de hoy (0 o 1 fila). semestre_actual indica el semestre
-- en curso, o NULL durante el receso entre semestres.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION academico.fn_periodo_actual()
RETURNS SETOF academico.periodo_admin
LANGUAGE sql STABLE
SET search_path = academico, auth, api, public
AS $$
    SELECT (academico.fn_a_periodo_admin(p)).*
    FROM academico.periodos_academicos p
    WHERE api.fn_hoy() BETWEEN p.inicio_semestre_i AND p.fin_semestre_ii;
$$;

-- ------------------------------------------------------------
-- Cierres: validaciones para los módulos que dependen del periodo (secciones, matrículas,
-- evaluaciones, ausentismo...). Devuelven el id_periodo para usarlo como FK interna.
-- ------------------------------------------------------------
-- NF004 si no existe; PA003 si el periodo ya finalizó.
CREATE OR REPLACE FUNCTION academico.fn_validar_periodo_abierto(p_anio INTEGER)
RETURNS BIGINT
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_periodo academico.periodos_academicos%ROWTYPE;
BEGIN
    SELECT * INTO v_periodo FROM academico.periodos_academicos WHERE anio = p_anio;

    IF NOT FOUND THEN
        PERFORM api.fn_lanzar_excepcion('NF004', 'El periodo académico no existe.');
    END IF;

    IF academico.fn_estado_periodo(v_periodo) = 'FINALIZADO' THEN
        PERFORM api.fn_lanzar_excepcion('PA003', 'El periodo académico ya finalizó.');
    END IF;

    RETURN v_periodo.id_periodo;
END;
$$;

-- NF004 si no existe; PA004 si el semestre ya finalizó (sus procesos están cerrados).
CREATE OR REPLACE FUNCTION academico.fn_validar_semestre_abierto(p_anio INTEGER, p_semestre academico.numero_semestre)
RETURNS BIGINT
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_periodo academico.periodos_academicos%ROWTYPE;
BEGIN
    SELECT * INTO v_periodo FROM academico.periodos_academicos WHERE anio = p_anio;

    IF NOT FOUND THEN
        PERFORM api.fn_lanzar_excepcion('NF004', 'El periodo académico no existe.');
    END IF;

    IF api.fn_hoy() > academico.fn_fin_semestre(v_periodo, p_semestre) THEN
        PERFORM api.fn_lanzar_excepcion('PA004', 'El semestre ya finalizó.');
    END IF;

    RETURN v_periodo.id_periodo;
END;
$$;

-- ------------------------------------------------------------
-- PA002 si las fechas no están en orden o fuera del año (mismo criterio que los CHECK de la tabla,
-- pero con un código propio). Usada por registrar y actualizar.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION academico.fn_validar_fechas_periodo(
    p_anio INTEGER,
    p_inicio_semestre_i DATE,
    p_fin_semestre_i DATE,
    p_inicio_semestre_ii DATE,
    p_fin_semestre_ii DATE
)
RETURNS VOID
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
BEGIN
    IF p_inicio_semestre_i IS NULL OR p_fin_semestre_i IS NULL
        OR p_inicio_semestre_ii IS NULL OR p_fin_semestre_ii IS NULL
        OR NOT (p_inicio_semestre_i < p_fin_semestre_i
                AND p_fin_semestre_i < p_inicio_semestre_ii
                AND p_inicio_semestre_ii < p_fin_semestre_ii)
        OR EXTRACT(YEAR FROM p_inicio_semestre_i) <> p_anio
        OR EXTRACT(YEAR FROM p_fin_semestre_ii) <> p_anio
    THEN
        PERFORM api.fn_lanzar_excepcion('PA002', 'Las fechas del periodo no son válidas.');
    END IF;
END;
$$;

-- CU 14 - Registrar periodo académico. Devuelve el año.
CREATE OR REPLACE FUNCTION academico.fn_admin_registrar_periodo(
    p_id_usuario_actor UUID,
    p_anio INTEGER,
    p_inicio_semestre_i DATE,
    p_fin_semestre_i DATE,
    p_inicio_semestre_ii DATE,
    p_fin_semestre_ii DATE
)
RETURNS INTEGER
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
BEGIN
    PERFORM api.fn_validar_admin_activo(p_id_usuario_actor);

    IF EXISTS (SELECT 1 FROM academico.periodos_academicos WHERE anio = p_anio) THEN
        PERFORM api.fn_lanzar_excepcion('PA001', 'Ya existe un periodo académico para ese año.');
    END IF;

    PERFORM academico.fn_validar_fechas_periodo(
        p_anio, p_inicio_semestre_i, p_fin_semestre_i, p_inicio_semestre_ii, p_fin_semestre_ii);

    -- Se permiten periodos pasados (digitalización de información histórica).
    INSERT INTO academico.periodos_academicos (
        anio, inicio_semestre_i, fin_semestre_i, inicio_semestre_ii, fin_semestre_ii)
    VALUES (
        p_anio, p_inicio_semestre_i, p_fin_semestre_i, p_inicio_semestre_ii, p_fin_semestre_ii);

    RETURN p_anio;
END;
$$;

-- CU 15 - Consultar periodos académicos (más reciente primero)
CREATE OR REPLACE FUNCTION academico.fn_admin_listar_periodos(p_pagina INTEGER, p_tamano_pagina INTEGER)
RETURNS SETOF academico.periodo_admin
LANGUAGE sql STABLE
SET search_path = academico, auth, api, public
AS $$
    SELECT (academico.fn_a_periodo_admin(p)).*
    FROM academico.periodos_academicos p
    ORDER BY p.anio DESC
    LIMIT api.fn_tamano_pagina(p_tamano_pagina)
    OFFSET api.fn_offset(p_pagina, p_tamano_pagina);
$$;

CREATE OR REPLACE FUNCTION academico.fn_admin_contar_periodos()
RETURNS BIGINT
LANGUAGE sql STABLE
SET search_path = academico, auth, api, public
AS $$
    SELECT COUNT(*) FROM academico.periodos_academicos;
$$;

CREATE OR REPLACE FUNCTION academico.fn_admin_obtener_periodo(p_anio INTEGER)
RETURNS SETOF academico.periodo_admin
LANGUAGE sql STABLE
SET search_path = academico, auth, api, public
AS $$
    SELECT (academico.fn_a_periodo_admin(p)).*
    FROM academico.periodos_academicos p
    WHERE p.anio = p_anio;
$$;

-- TRUE si con las fechas de p (nuevas) algún registro del periodo queda fuera de sus reglas de fecha. plpgsql: las
-- tablas se crean en 06 (RP-50).
CREATE OR REPLACE FUNCTION academico.fn_periodo_tiene_registros_fuera(p academico.periodos_academicos)
RETURNS BOOLEAN
LANGUAGE plpgsql STABLE
SET search_path = academico, auth, api, public
AS $$
BEGIN
    RETURN EXISTS (SELECT 1 FROM academico.lecciones l
                   JOIN academico.asignaciones_docentes a ON a.id_asignacion = l.id_asignacion
                   JOIN academico.secciones s ON s.id_seccion = a.id_seccion
                   WHERE s.id_periodo = p.id_periodo AND academico.fn_semestre_en_fecha(p, l.fecha) IS NULL)
        OR EXISTS (SELECT 1 FROM academico.matriculas m
                   WHERE m.id_periodo = p.id_periodo
                     AND (m.fecha_matricula > p.fin_semestre_ii
                          OR m.fecha_matricula < (p.inicio_semestre_i - INTERVAL '1 year')::DATE
                          OR m.fecha_retiro > p.fin_semestre_ii))
        OR EXISTS (SELECT 1 FROM academico.experiencias_cas x
                   JOIN academico.informes_cas i ON i.id_informe = x.id_informe
                   JOIN academico.matriculas m ON m.id_matricula = i.id_matricula
                   WHERE m.id_periodo = p.id_periodo AND x.fecha NOT BETWEEN p.inicio_semestre_i AND p.fin_semestre_ii)
        OR EXISTS (SELECT 1 FROM academico.seguimientos_monografia sg
                   JOIN academico.monografias mo ON mo.id_monografia = sg.id_monografia
                   JOIN academico.matriculas m ON m.id_matricula = mo.id_matricula_inicio
                   WHERE m.id_periodo = p.id_periodo AND sg.fecha < p.inicio_semestre_i);
END;
$$;

-- CU 16 - Modificar las fechas de un periodo. Devuelve 'OK' o 'SIN_CAMBIOS' y el snapshot previo.
-- PA008 si las nuevas fechas dejan fuera registros del periodo (lecciones, matrículas, retiros...).
-- Periodo finalizado (histórico): se puede corregir mientras siga finalizado (PA007: no se reabre).
-- Periodo no finalizado: las fechas de un semestre finalizado no cambian (PA004) y un semestre no
-- finalizado no puede quedar con fin en el pasado (PA005).
CREATE OR REPLACE FUNCTION academico.fn_admin_actualizar_periodo(
    p_id_usuario_actor UUID,
    p_anio INTEGER,
    p_inicio_semestre_i DATE,
    p_fin_semestre_i DATE,
    p_inicio_semestre_ii DATE,
    p_fin_semestre_ii DATE
)
RETURNS TABLE(out_status TEXT, out_datos_anteriores JSONB)
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_prev academico.periodos_academicos%ROWTYPE;
    v_nuevo academico.periodos_academicos%ROWTYPE;
    v_hoy DATE := api.fn_hoy();
BEGIN
    PERFORM api.fn_validar_admin_activo(p_id_usuario_actor);

    SELECT * INTO v_prev
    FROM academico.periodos_academicos p
    WHERE p.anio = p_anio
    FOR UPDATE;

    IF NOT FOUND THEN
        PERFORM api.fn_lanzar_excepcion('NF004', 'El periodo académico no existe.');
    END IF;

    PERFORM academico.fn_validar_fechas_periodo(
        p_anio, p_inicio_semestre_i, p_fin_semestre_i, p_inicio_semestre_ii, p_fin_semestre_ii);

    v_nuevo := v_prev;
    v_nuevo.inicio_semestre_i := p_inicio_semestre_i;
    v_nuevo.fin_semestre_i := p_fin_semestre_i;
    v_nuevo.inicio_semestre_ii := p_inicio_semestre_ii;
    v_nuevo.fin_semestre_ii := p_fin_semestre_ii;

    IF v_nuevo IS NOT DISTINCT FROM v_prev THEN
        RETURN QUERY SELECT 'SIN_CAMBIOS'::TEXT, NULL::JSONB;
        RETURN;
    END IF;

    IF academico.fn_estado_periodo(v_prev) = 'FINALIZADO' THEN
        -- Corrección de un periodo histórico: debe seguir finalizado.
        IF v_nuevo.fin_semestre_ii >= v_hoy THEN
            PERFORM api.fn_lanzar_excepcion('PA007', 'Un periodo finalizado no se puede reabrir.');
        END IF;
    -- I semestre: si ya finalizó, sus fechas son inmutables; si no, su fin no puede quedar en el pasado.
    ELSIF v_hoy > v_prev.fin_semestre_i THEN
        IF (v_nuevo.inicio_semestre_i, v_nuevo.fin_semestre_i) IS DISTINCT FROM (v_prev.inicio_semestre_i, v_prev.fin_semestre_i) THEN
            PERFORM api.fn_lanzar_excepcion('PA004', 'El semestre ya finalizó.');
        END IF;
    ELSIF v_nuevo.fin_semestre_i < v_hoy THEN
        PERFORM api.fn_lanzar_excepcion('PA005', 'La fecha de fin de un semestre no finalizado no puede quedar en el pasado.');
    END IF;

    -- II semestre (periodo no finalizado): su fin no puede quedar en el pasado.
    IF academico.fn_estado_periodo(v_prev) <> 'FINALIZADO' AND v_nuevo.fin_semestre_ii < v_hoy THEN
        PERFORM api.fn_lanzar_excepcion('PA005', 'La fecha de fin de un semestre no finalizado no puede quedar en el pasado.');
    END IF;

    -- PA008: las nuevas fechas no dejan fuera registros del periodo: lecciones fuera de un semestre (LE001), matrículas
    -- o retiros posteriores al fin del periodo (MA002 / MA003), experiencias CAS fuera del periodo (CA001) ni
    -- seguimientos de monografía anteriores a su inicio (MO006).
    IF academico.fn_periodo_tiene_registros_fuera(v_nuevo) THEN
        PERFORM api.fn_lanzar_excepcion('PA008', 'Las nuevas fechas dejan fuera lecciones, matrículas u otros registros del periodo.');
    END IF;

    UPDATE academico.periodos_academicos
    SET inicio_semestre_i = v_nuevo.inicio_semestre_i,
        fin_semestre_i = v_nuevo.fin_semestre_i,
        inicio_semestre_ii = v_nuevo.inicio_semestre_ii,
        fin_semestre_ii = v_nuevo.fin_semestre_ii
    WHERE id_periodo = v_prev.id_periodo;

    RETURN QUERY SELECT 'OK'::TEXT, to_jsonb(v_prev) - 'id_periodo';
END;
$$;

-- CU 17 - Eliminar periodo académico. Solo si no tiene secciones (PA006). Devuelve el snapshot previo.
-- Si otras entidades lo referencian con FK RESTRICT, Postgres lanza 23503.
CREATE OR REPLACE FUNCTION academico.fn_admin_eliminar_periodo(
    p_id_usuario_actor UUID,
    p_anio INTEGER
)
RETURNS JSONB
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_prev academico.periodos_academicos%ROWTYPE;
BEGIN
    PERFORM api.fn_validar_admin_activo(p_id_usuario_actor);

    SELECT * INTO v_prev
    FROM academico.periodos_academicos p
    WHERE p.anio = p_anio
    FOR UPDATE;

    IF NOT FOUND THEN
        PERFORM api.fn_lanzar_excepcion('NF004', 'El periodo académico no existe.');
    END IF;

    IF EXISTS (SELECT 1 FROM academico.secciones s WHERE s.id_periodo = v_prev.id_periodo) THEN
        PERFORM api.fn_lanzar_excepcion('PA006', 'El periodo académico tiene secciones asociadas.');
    END IF;

    DELETE FROM academico.periodos_academicos WHERE id_periodo = v_prev.id_periodo;

    RETURN to_jsonb(v_prev) - 'id_periodo';
END;
$$;
