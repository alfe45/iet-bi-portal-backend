-- ============================================================
-- 11_admin_asignaturas.sql: CU 26 a 29. Se opera SIEMPRE por código (nunca por id_asignatura).
-- El código es inmutable y se guarda en mayúsculas. El nombre es único sin distinguir mayúsculas.
-- ============================================================
SET search_path = academico, api, auth, public;

CREATE TYPE academico.asignatura_admin AS (
    codigo VARCHAR(10),
    nombre CITEXT,
    tipo academico.tipo_asignatura,
    descripcion VARCHAR(255),
    imparte_nivel_10 BOOLEAN,
    imparte_nivel_11 BOOLEAN
);

-- ------------------------------------------------------------
-- Helpers (también para asignaciones docentes)
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION academico.fn_normalizar_codigo_asignatura(p_codigo TEXT)
RETURNS TEXT
LANGUAGE sql IMMUTABLE
AS $$
    SELECT upper(api.fn_limpiar(p_codigo));
$$;

-- Id interno de la asignatura para usarlo como FK. NF007 si no existe.
CREATE OR REPLACE FUNCTION academico.fn_obtener_id_asignatura(p_codigo TEXT)
RETURNS BIGINT
LANGUAGE plpgsql STABLE
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_id BIGINT;
BEGIN
    SELECT id_asignatura INTO v_id
    FROM academico.asignaturas
    WHERE codigo = academico.fn_normalizar_codigo_asignatura(p_codigo);

    IF v_id IS NULL THEN
        PERFORM api.fn_lanzar_excepcion('NF007', 'La asignatura no existe.');
    END IF;

    RETURN v_id;
END;
$$;

-- RP-57: bloquea la asignatura (FOR SHARE) para quien depende de su tipo o sus niveles (asignar, calificar, monografía);
-- fn_admin_actualizar_asignatura la bloquea FOR UPDATE. El FK de una asignación solo toma KEY SHARE, que no choca con
-- un UPDATE de tipo o niveles: sin esto, AS005/AS006/AS007 se podían violar con peticiones simultáneas.
CREATE OR REPLACE FUNCTION academico.fn_bloquear_asignatura(p_id_asignatura BIGINT)
RETURNS VOID
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
BEGIN
    PERFORM 1 FROM academico.asignaturas WHERE id_asignatura = p_id_asignatura FOR SHARE;
END;
$$;

-- RN-39: AS005 si la asignatura no se imparte en ese nivel (ej. Cívica en 11).
-- La usan las asignaciones docentes al asignar una asignatura a una sección.
CREATE OR REPLACE FUNCTION academico.fn_validar_asignatura_en_nivel(p_id_asignatura BIGINT, p_nivel INTEGER)
RETURNS VOID
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
BEGIN
    PERFORM academico.fn_bloquear_asignatura(p_id_asignatura);

    IF NOT EXISTS (
        SELECT 1 FROM academico.asignaturas a
        WHERE a.id_asignatura = p_id_asignatura
          AND ((p_nivel = 10 AND a.imparte_nivel_10) OR (p_nivel = 11 AND a.imparte_nivel_11))
    ) THEN
        PERFORM api.fn_lanzar_excepcion('AS005', 'La asignatura no se imparte en ese nivel.');
    END IF;
END;
$$;

-- AS003 si no se imparte en ningún nivel. Usada por registrar y actualizar.
CREATE OR REPLACE FUNCTION academico.fn_validar_niveles_asignatura(p_nivel_10 BOOLEAN, p_nivel_11 BOOLEAN)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT (COALESCE(p_nivel_10, FALSE) OR COALESCE(p_nivel_11, FALSE)) THEN
        PERFORM api.fn_lanzar_excepcion('AS003', 'La asignatura debe impartirse en al menos un nivel.');
    END IF;
END;
$$;

-- RN-82: AS008 si la asignatura CAS no es TRONCAL (su nota usa la escala A a E y tiene su propio informe).
CREATE OR REPLACE FUNCTION academico.fn_validar_tipo_asignatura(p_codigo TEXT, p_tipo academico.tipo_asignatura)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_codigo = 'CAS' AND p_tipo IS DISTINCT FROM 'TRONCAL' THEN
        PERFORM api.fn_lanzar_excepcion('AS008', 'La asignatura CAS debe ser de tipo TRONCAL.');
    END IF;
END;
$$;

-- CU 26 - Registrar asignatura. Devuelve el código normalizado.
CREATE OR REPLACE FUNCTION academico.fn_admin_registrar_asignatura(
    p_id_usuario_actor UUID,
    p_codigo TEXT,
    p_nombre TEXT,
    p_tipo academico.tipo_asignatura,
    p_descripcion TEXT,
    p_imparte_nivel_10 BOOLEAN,
    p_imparte_nivel_11 BOOLEAN
)
RETURNS TEXT
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_codigo TEXT := academico.fn_normalizar_codigo_asignatura(p_codigo);
    v_nombre CITEXT := api.fn_limpiar(p_nombre)::CITEXT;
BEGIN
    PERFORM api.fn_validar_admin_activo(p_id_usuario_actor);

    IF v_codigo IS NULL OR v_codigo !~ '^[A-Z0-9]{2,10}$' THEN
        PERFORM api.fn_lanzar_excepcion('AS004', 'El código de la asignatura no es válido.');
    END IF;

    IF EXISTS (SELECT 1 FROM academico.asignaturas WHERE codigo = v_codigo) THEN
        PERFORM api.fn_lanzar_excepcion('AS001', 'Ya existe una asignatura con ese código.');
    END IF;

    IF EXISTS (SELECT 1 FROM academico.asignaturas WHERE nombre = v_nombre) THEN
        PERFORM api.fn_lanzar_excepcion('AS002', 'Ya existe una asignatura con ese nombre.');
    END IF;

    PERFORM academico.fn_validar_niveles_asignatura(p_imparte_nivel_10, p_imparte_nivel_11);
    PERFORM academico.fn_validar_tipo_asignatura(v_codigo, p_tipo);

    INSERT INTO academico.asignaturas (codigo, nombre, tipo, descripcion, imparte_nivel_10, imparte_nivel_11)
    VALUES (v_codigo, v_nombre, p_tipo, api.fn_limpiar(p_descripcion), p_imparte_nivel_10, p_imparte_nivel_11);

    RETURN v_codigo;
END;
$$;

-- CU 27 - Consultar asignaturas. Filtros opcionales por tipo y nivel (NULL = todos).
CREATE OR REPLACE FUNCTION academico.fn_admin_listar_asignaturas(p_id_usuario_actor UUID, 
    p_tipo academico.tipo_asignatura, p_nivel INTEGER, p_pagina INTEGER, p_tamano_pagina INTEGER)
RETURNS SETOF academico.asignatura_admin
LANGUAGE sql STABLE
SET search_path = academico, auth, api, public
AS $$
    SELECT api.fn_validar_admin_activo(p_id_usuario_actor);   -- RP-12 (las lecturas también)
    SELECT a.codigo, a.nombre, a.tipo, a.descripcion, a.imparte_nivel_10, a.imparte_nivel_11
    FROM academico.asignaturas a
    WHERE (p_tipo IS NULL OR a.tipo = p_tipo)
      AND (p_nivel IS NULL OR (p_nivel = 10 AND a.imparte_nivel_10) OR (p_nivel = 11 AND a.imparte_nivel_11))
    ORDER BY a.nombre
    LIMIT api.fn_tamano_pagina(p_tamano_pagina)
    OFFSET api.fn_offset(p_pagina, p_tamano_pagina);
$$;

CREATE OR REPLACE FUNCTION academico.fn_admin_contar_asignaturas(p_id_usuario_actor UUID, p_tipo academico.tipo_asignatura, p_nivel INTEGER)
RETURNS BIGINT
LANGUAGE sql STABLE
SET search_path = academico, auth, api, public
AS $$
    SELECT api.fn_validar_admin_activo(p_id_usuario_actor);   -- RP-12 (las lecturas también)
    SELECT COUNT(*)
    FROM academico.asignaturas a
    WHERE (p_tipo IS NULL OR a.tipo = p_tipo)
      AND (p_nivel IS NULL OR (p_nivel = 10 AND a.imparte_nivel_10) OR (p_nivel = 11 AND a.imparte_nivel_11));
$$;

CREATE OR REPLACE FUNCTION academico.fn_admin_obtener_asignatura(p_id_usuario_actor UUID, p_codigo TEXT)
RETURNS SETOF academico.asignatura_admin
LANGUAGE sql STABLE
SET search_path = academico, auth, api, public
AS $$
    SELECT api.fn_validar_admin_activo(p_id_usuario_actor);   -- RP-12 (las lecturas también)
    SELECT a.codigo, a.nombre, a.tipo, a.descripcion, a.imparte_nivel_10, a.imparte_nivel_11
    FROM academico.asignaturas a
    WHERE a.codigo = academico.fn_normalizar_codigo_asignatura(p_codigo);
$$;

-- CU 28 - Modificar asignatura (todo menos el código). Devuelve 'OK' o 'SIN_CAMBIOS' y el snapshot previo.
-- AS006 tipo con notas o monografías; AS007 nivel con asignaciones; AS008 CAS no TRONCAL.
CREATE OR REPLACE FUNCTION academico.fn_admin_actualizar_asignatura(
    p_id_usuario_actor UUID,
    p_codigo TEXT,
    p_nombre TEXT,
    p_tipo academico.tipo_asignatura,
    p_descripcion TEXT,
    p_imparte_nivel_10 BOOLEAN,
    p_imparte_nivel_11 BOOLEAN
)
RETURNS TABLE(out_status TEXT, out_datos_anteriores JSONB)
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_prev academico.asignaturas%ROWTYPE;
    v_nuevo academico.asignaturas%ROWTYPE;
BEGIN
    PERFORM api.fn_validar_admin_activo(p_id_usuario_actor);

    SELECT * INTO v_prev
    FROM academico.asignaturas
    WHERE codigo = academico.fn_normalizar_codigo_asignatura(p_codigo)
    FOR UPDATE;

    IF NOT FOUND THEN
        PERFORM api.fn_lanzar_excepcion('NF007', 'La asignatura no existe.');
    END IF;

    PERFORM academico.fn_validar_niveles_asignatura(p_imparte_nivel_10, p_imparte_nivel_11);
    PERFORM academico.fn_validar_tipo_asignatura(v_prev.codigo, p_tipo);

    v_nuevo := v_prev;
    v_nuevo.nombre := api.fn_limpiar(p_nombre)::CITEXT;
    v_nuevo.tipo := p_tipo;
    v_nuevo.descripcion := api.fn_limpiar(p_descripcion);
    v_nuevo.imparte_nivel_10 := p_imparte_nivel_10;
    v_nuevo.imparte_nivel_11 := p_imparte_nivel_11;

    -- Comparación sensible a mayúsculas: corregir "matemáticas" -> "Matemáticas" es un cambio.
    IF (v_nuevo.nombre::TEXT, v_nuevo.tipo, v_nuevo.descripcion, v_nuevo.imparte_nivel_10, v_nuevo.imparte_nivel_11)
       IS NOT DISTINCT FROM
       (v_prev.nombre::TEXT, v_prev.tipo, v_prev.descripcion, v_prev.imparte_nivel_10, v_prev.imparte_nivel_11) THEN
        RETURN QUERY SELECT 'SIN_CAMBIOS'::TEXT, NULL::JSONB;
        RETURN;
    END IF;

    IF EXISTS (SELECT 1 FROM academico.asignaturas
               WHERE nombre = v_nuevo.nombre AND id_asignatura <> v_prev.id_asignatura) THEN
        PERFORM api.fn_lanzar_excepcion('AS002', 'Ya existe una asignatura con ese nombre.');
    END IF;

    -- RN-73: el tipo define la escala de la nota y la materia de monografía (RN-78); no cambia si ya se usa.
    IF v_nuevo.tipo <> v_prev.tipo AND (
        EXISTS (SELECT 1 FROM academico.evaluaciones ev
                JOIN academico.asignaciones_docentes a ON a.id_asignacion = ev.id_asignacion
                WHERE a.id_asignatura = v_prev.id_asignatura)
        OR EXISTS (SELECT 1 FROM academico.monografias mo WHERE mo.id_asignatura = v_prev.id_asignatura)
    ) THEN
        PERFORM api.fn_lanzar_excepcion('AS006', 'No se puede cambiar el tipo de una asignatura con notas o monografías registradas.');
    END IF;

    -- RN-43: AS007 si se quita un nivel en el que la asignatura ya está asignada a alguna sección.
    IF EXISTS (SELECT 1 FROM academico.asignaciones_docentes a
               JOIN academico.secciones s ON s.id_seccion = a.id_seccion
               WHERE a.id_asignatura = v_prev.id_asignatura
                 AND ((s.nivel = 10 AND NOT v_nuevo.imparte_nivel_10) OR (s.nivel = 11 AND NOT v_nuevo.imparte_nivel_11))) THEN
        PERFORM api.fn_lanzar_excepcion('AS007', 'La asignatura tiene asignaciones en un nivel que se quiere quitar.');
    END IF;

    UPDATE academico.asignaturas
    SET nombre = v_nuevo.nombre,
        tipo = v_nuevo.tipo,
        descripcion = v_nuevo.descripcion,
        imparte_nivel_10 = v_nuevo.imparte_nivel_10,
        imparte_nivel_11 = v_nuevo.imparte_nivel_11
    WHERE id_asignatura = v_prev.id_asignatura;

    RETURN QUERY SELECT 'OK'::TEXT, to_jsonb(v_prev) - 'id_asignatura';
END;
$$;

-- CU 29 - Eliminar asignatura. Devuelve el snapshot previo. Si otras entidades la referencian
-- (asignaciones docentes) con FK RESTRICT, Postgres lanza 23001.
CREATE OR REPLACE FUNCTION academico.fn_admin_eliminar_asignatura(
    p_id_usuario_actor UUID,
    p_codigo TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_prev academico.asignaturas%ROWTYPE;
BEGIN
    PERFORM api.fn_validar_admin_activo(p_id_usuario_actor);

    SELECT * INTO v_prev
    FROM academico.asignaturas
    WHERE codigo = academico.fn_normalizar_codigo_asignatura(p_codigo)
    FOR UPDATE;

    IF NOT FOUND THEN
        PERFORM api.fn_lanzar_excepcion('NF007', 'La asignatura no existe.');
    END IF;

    DELETE FROM academico.asignaturas WHERE id_asignatura = v_prev.id_asignatura;

    RETURN to_jsonb(v_prev) - 'id_asignatura';
END;
$$;
