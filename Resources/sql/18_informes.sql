-- ============================================================
-- 18_informes.sql: reporte de bandas del guía (Guía CU08 por estudiante y CU09 de toda la sección).
-- El backend devuelve los datos y el front arma el PDF (RN-85). Por estudiante y asignación del semestre:
-- banda o nota mínima, nota registrada hasta el momento y si el profesor ya la confirmó (RN-75), ausentismo
-- (tardías, injustificadas y justificadas) y observaciones del profesor. nombre_guia: para la línea de firma.
-- CAS no va en este reporte: tiene su propio informe (RN-83).
-- La sección de monografía sale de fn_guia_reportes_monografia (16).
-- Al final: el tablero del Administrador (fn_admin_tablero, RP-62).
-- ============================================================
SET search_path = academico, api, auth, public;

CREATE TYPE academico.fila_reporte_bandas AS (
    cedula_estudiante VARCHAR(20),
    nombre_estudiante TEXT,
    codigo_asignatura VARCHAR(10),    -- NULL si la sección no tiene asignaciones
    asignatura TEXT,
    tipo_asignatura academico.tipo_asignatura,
    nombre_profesor TEXT,
    nota_minima VARCHAR(3),
    nota VARCHAR(3),
    aprobada BOOLEAN,
    tardias INTEGER,
    injustificadas INTEGER,
    justificadas INTEGER,
    observaciones VARCHAR(500),
    confirmada BOOLEAN,               -- NULL si la sección no tiene asignaciones
    nombre_guia TEXT
);

-- ------------------------------------------------------------
-- Guía CU08 / CU09 - Reporte de bandas de la sección guía en un semestre (AD005). p_cedula_estudiante NULL = toda
-- la sección; EV004 si el estudiante no se califica en la sección ese semestre.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION academico.fn_guia_reporte_bandas(
    p_id_usuario UUID, p_anio INTEGER, p_nivel INTEGER, p_numero INTEGER, p_semestre academico.numero_semestre,
    p_cedula_estudiante TEXT)
RETURNS SETOF academico.fila_reporte_bandas
LANGUAGE plpgsql STABLE
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_id_seccion BIGINT := academico.fn_validar_guia_seccion(p_id_usuario, p_anio, p_nivel, p_numero);
    v_cedula TEXT := api.fn_limpiar_cedula(p_cedula_estudiante);
    v_id_matricula BIGINT;
    v_nombre_guia TEXT := (SELECT concat_ws(' ', pr.nombre, pr.primer_apellido, pr.segundo_apellido)
                           FROM academico.secciones s JOIN academico.profesores pr ON pr.id_profesor = s.id_profesor_guia
                           WHERE s.id_seccion = v_id_seccion);
BEGIN
    SELECT ms.id_matricula INTO v_id_matricula
    FROM academico.fn_matriculas_del_semestre(v_id_seccion, p_semestre) ms
    JOIN academico.estudiantes e ON e.id_estudiante = ms.id_estudiante
    WHERE e.cedula = v_cedula;

    IF v_cedula IS NOT NULL AND v_id_matricula IS NULL THEN
        PERFORM api.fn_lanzar_excepcion('EV004', 'El estudiante no se califica en la sección ese semestre.');
    END IF;

    RETURN QUERY
    WITH conteo AS (SELECT * FROM academico.fn_conteo_ausentismo(v_id_seccion, NULL, p_semestre, v_id_matricula))
    SELECT (d.fila).cedula_estudiante, (d.fila).nombre_estudiante,
           asg.codigo, asg.nombre::TEXT, asg.tipo, (ad.fila).nombre_profesor,
           academico.fn_nota_minima(asg.tipo)::VARCHAR(3),
           ev.nota,
           academico.fn_nota_aprobada(asg.tipo, ev.nota),
           c.tardias, c.ausencias - c.justificadas, c.justificadas,
           ev.observaciones,
           CASE WHEN a.id_asignacion IS NOT NULL THEN cn.id_asignacion IS NOT NULL END,
           v_nombre_guia
    FROM academico.fn_matriculas_del_semestre(v_id_seccion, p_semestre) ms
    JOIN academico.fn_matriculas_detalle() d ON d.id_matricula = ms.id_matricula
    LEFT JOIN (academico.asignaciones_docentes a
               JOIN academico.asignaturas asg ON asg.id_asignatura = a.id_asignatura AND asg.codigo <> 'CAS')
           ON a.id_seccion = v_id_seccion
    LEFT JOIN academico.fn_asignaciones_detalle() ad ON ad.id_asignacion = a.id_asignacion
    LEFT JOIN academico.confirmaciones_notas cn ON cn.id_asignacion = a.id_asignacion AND cn.semestre = p_semestre
    LEFT JOIN academico.evaluaciones ev
           ON ev.id_asignacion = a.id_asignacion AND ev.id_matricula = ms.id_matricula AND ev.semestre = p_semestre
    LEFT JOIN conteo c ON c.id_matricula = ms.id_matricula AND c.id_asignacion = a.id_asignacion
    WHERE v_cedula IS NULL OR (d.fila).cedula_estudiante = v_cedula
    ORDER BY d.apellidos_nombre, asg.tipo, asg.nombre, (ad.fila).nombre_profesor;
END;
$$;

-- Guía - Reactivar la edición de las notas de su sección en un semestre (RN-75): borra las confirmaciones de las
-- asignaciones cuyo plazo de notas sigue abierto (la del profesor, con su prórroga); las notas no cambian y cada
-- profesor las corrige y vuelve a confirmar. AD005 si no es el guía de la sección; EV003 si había notas confirmadas
-- pero el plazo de todas ya cerró. Devuelve las asignaturas reactivadas, o NULL si no había nada confirmado.
CREATE OR REPLACE FUNCTION academico.fn_guia_reactivar_bandas_seccion(
    p_id_usuario UUID,
    p_anio INTEGER,
    p_nivel INTEGER,
    p_numero INTEGER,
    p_semestre academico.numero_semestre)
RETURNS JSONB
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_id_seccion BIGINT := academico.fn_validar_guia_seccion(p_id_usuario, p_anio, p_nivel, p_numero);
    v_periodo academico.periodos_academicos%ROWTYPE;
    v_confirmadas INTEGER;
    v_reactivadas JSONB;
BEGIN
    IF p_semestre IS NULL THEN
        PERFORM api.fn_lanzar_excepcion('22P02', 'Falta el semestre.');
    END IF;
    SELECT p.* INTO v_periodo FROM academico.periodos_academicos p WHERE p.anio = p_anio;

    -- RP-57: las asignaciones de la sección se bloquean (confirmar y corregir esperan).
    PERFORM 1 FROM academico.asignaciones_docentes WHERE id_seccion = v_id_seccion ORDER BY id_asignacion FOR UPDATE;

    SELECT count(*) INTO v_confirmadas
    FROM academico.confirmaciones_notas cn
    JOIN academico.asignaciones_docentes a ON a.id_asignacion = cn.id_asignacion
    WHERE a.id_seccion = v_id_seccion AND cn.semestre = p_semestre;
    IF v_confirmadas = 0 THEN
        RETURN NULL;
    END IF;

    WITH borradas AS (
        DELETE FROM academico.confirmaciones_notas cn
        USING academico.asignaciones_docentes a
        WHERE cn.id_asignacion = a.id_asignacion
          AND a.id_seccion = v_id_seccion
          AND cn.semestre = p_semestre
          AND api.fn_hoy() BETWEEN academico.fn_inicio_semestre(v_periodo, p_semestre)
                               AND academico.fn_cierre_notas(a.id_profesor, v_periodo, p_semestre)
        RETURNING a.id_asignatura, a.id_profesor
    )
    SELECT jsonb_agg(jsonb_build_object('asignatura', asg.codigo, 'cedulaProfesor', pr.cedula) ORDER BY asg.codigo)
    INTO v_reactivadas
    FROM borradas b
    JOIN academico.asignaturas asg ON asg.id_asignatura = b.id_asignatura
    JOIN academico.profesores pr ON pr.id_profesor = b.id_profesor;

    IF v_reactivadas IS NULL THEN
        PERFORM api.fn_lanzar_excepcion('EV003', 'El plazo de notas del semestre cerró para todas las asignaturas confirmadas.');
    END IF;

    RETURN jsonb_build_object('seccion', format('%s-%s', p_nivel, p_numero), 'semestre', p_semestre,
                              'reactivadas', v_reactivadas);
END;
$$;

-- ============================================================
-- Tablero del Administrador (RP-62): resumen de un curso lectivo en una sola llamada (solo lectura, no se audita).
-- p_anio NULL: el curso lectivo en curso; si no hay, el más reciente que ya empezó (o el próximo, si ninguno empezó).
-- NF004 si se pide un año que no existe. Sin cursos lectivos: periodo = null y el resto vacío.
-- Semestre de las notas: el que está en curso; en el receso o con el periodo finalizado, el último que empezó.
-- Alertas (código, nivel PRIORIDAD/AVISO/INFO, cantidad y detalle); el portal arma el texto y el enlace:
--   SECCIONES_SIN_GUIA y SECCIONES_SIN_CAS (sin asignación de la asignatura CAS; ambas no en periodos finalizados),
--   SIN_COORDINADOR_CAS,
--   SIN_COORDINADOR_MONOGRAFIA, ESTUDIANTES_SIN_MONOGRAFIA (nivel 11 sin retiro y sin monografía, RN-78; no en
--   periodos finalizados), NOTAS_PENDIENTES (plazo abierto, 30 días o menos para el cierre del profesor y notas
--   incompletas o sin confirmar, como el aviso de RN-76; PRIORIDAD con 15 días o menos), PRORROGAS_VIGENTES.
-- Actividad: las 20 acciones más recientes de api.logs que cambian datos (sin inicios ni cierres de sesión).
-- ============================================================
-- Tablero (RP-62): por asignación del periodo, los estudiantes que se califican en el semestre (RN-75), cuántos no
-- tienen nota, si el profesor la confirmó y su cierre de notas (RN-74).
CREATE OR REPLACE FUNCTION academico.fn_tablero_notas(p academico.periodos_academicos, p_semestre academico.numero_semestre)
RETURNS TABLE(id_asignacion BIGINT, nivel SMALLINT, seccion TEXT, asignatura TEXT, profesor TEXT,
              estudiantes INTEGER, sin_nota INTEGER, confirmada BOOLEAN, cierre DATE)
LANGUAGE plpgsql STABLE
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_fin DATE := academico.fn_fin_semestre(p, p_semestre);
BEGIN
    RETURN QUERY
    SELECT a.id_asignacion, s.nivel, s.nivel || '-' || s.numero, asg.nombre::TEXT,
           concat_ws(' ', pr.nombre, pr.primer_apellido),
           COUNT(m.id_matricula)::INTEGER,
           (COUNT(m.id_matricula) FILTER (WHERE ev.id_evaluacion IS NULL))::INTEGER,
           EXISTS (SELECT 1 FROM academico.confirmaciones_notas cn WHERE cn.id_asignacion = a.id_asignacion AND cn.semestre = p_semestre),
           academico.fn_cierre_notas(a.id_profesor, p, p_semestre)
    FROM academico.asignaciones_docentes a
    JOIN academico.secciones s ON s.id_seccion = a.id_seccion
    JOIN academico.asignaturas asg ON asg.id_asignatura = a.id_asignatura
    JOIN academico.profesores pr ON pr.id_profesor = a.id_profesor
    LEFT JOIN academico.matriculas m ON m.id_seccion = s.id_seccion
         AND m.fecha_matricula <= v_fin AND (m.fecha_retiro IS NULL OR m.fecha_retiro > v_fin)
    LEFT JOIN academico.evaluaciones ev ON ev.id_asignacion = a.id_asignacion AND ev.id_matricula = m.id_matricula AND ev.semestre = p_semestre
    WHERE s.id_periodo = p.id_periodo
    GROUP BY a.id_asignacion, a.id_profesor, s.nivel, s.numero, asg.nombre, pr.nombre, pr.primer_apellido;
END;
$$;

CREATE OR REPLACE FUNCTION academico.fn_admin_tablero(p_id_usuario_actor UUID, p_anio INTEGER)
RETURNS JSONB
LANGUAGE plpgsql STABLE
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_hoy DATE := api.fn_hoy();
    p academico.periodos_academicos%ROWTYPE;
    v_estado academico.estado_periodo;
    v_semestre_actual academico.numero_semestre;
    v_semestre academico.numero_semestre;
    v_fin DATE;
    v_anios JSONB;
    v_periodo JSONB;
    v_estudiantes JSONB;
    v_secciones JSONB;
    v_profesores JSONB;
    v_carga JSONB;
    v_notas JSONB;
    v_monografias JSONB;
    v_matricula JSONB;
    v_ausentismo JSONB;
    v_alertas JSONB := '[]'::JSONB;
    v_actividad JSONB;
    v_cantidad INTEGER;
    v_detalle JSONB;
    v_min_dias INTEGER;
BEGIN
    PERFORM api.fn_validar_admin_activo(p_id_usuario_actor);   -- RP-12 (las lecturas también)

    SELECT COALESCE(jsonb_agg(anio ORDER BY anio DESC), '[]'::JSONB) INTO v_anios FROM academico.periodos_academicos;

    -- Actividad reciente (no depende del periodo).
    -- registro: el correo si es un usuario, el nombre si es un profesor o estudiante (por cédula); si no, tal cual.
    SELECT COALESCE(jsonb_agg(jsonb_build_object('accion', l.accion, 'usuario', l.email_usuario, 'fecha', l.creado_en,
                   'registro', COALESCE((SELECT u.email::TEXT FROM api.usuarios u WHERE u.id_usuario::TEXT = l.id_registro_afectado),
                                        (SELECT concat_ws(' ', x.nombre, x.primer_apellido) FROM academico.profesores x WHERE x.cedula = l.id_registro_afectado),
                                        (SELECT concat_ws(' ', x.nombre, x.primer_apellido) FROM academico.estudiantes x WHERE x.cedula = l.id_registro_afectado),
                                        l.id_registro_afectado))
                              ORDER BY l.creado_en DESC), '[]'::JSONB)
    INTO v_actividad
    FROM (SELECT * FROM api.logs
          WHERE accion NOT IN ('LOGIN', 'LOGIN_FALLIDO', 'SESION_REUTILIZADA', 'LOGOUT', 'LOGOUT_ALL')
          ORDER BY creado_en DESC LIMIT 20) l;

    IF p_anio IS NOT NULL THEN
        SELECT * INTO p FROM academico.periodos_academicos WHERE anio = p_anio;
        IF NOT FOUND THEN
            PERFORM api.fn_lanzar_excepcion('NF004', 'El periodo académico no existe.');
        END IF;
    ELSE
        SELECT * INTO p FROM academico.periodos_academicos
        ORDER BY (v_hoy BETWEEN inicio_semestre_i AND fin_semestre_ii) DESC,   -- el que está en curso
                 (inicio_semestre_i <= v_hoy) DESC,                            -- si no, el último que empezó
                 CASE WHEN inicio_semestre_i <= v_hoy THEN -anio ELSE anio END   -- o el próximo
        LIMIT 1;
        IF NOT FOUND THEN
            RETURN jsonb_build_object('periodo', NULL, 'aniosDisponibles', v_anios, 'alertas', '[]'::JSONB,
                                      'actividad', v_actividad);
        END IF;
    END IF;

    v_estado := academico.fn_estado_periodo(p);
    v_semestre_actual := academico.fn_semestre_en_fecha(p, v_hoy);
    v_semestre := CASE WHEN v_hoy >= p.inicio_semestre_ii THEN 'II_SEMESTRE' ELSE 'I_SEMESTRE' END::academico.numero_semestre;
    v_fin := academico.fn_fin_semestre(p, v_semestre);

    v_periodo := jsonb_build_object(
        'anio', p.anio, 'estado', v_estado, 'semestreActual', v_semestre_actual, 'semestreNotas', v_semestre,
        'inicioSemestre', academico.fn_inicio_semestre(p, v_semestre), 'finSemestre', v_fin,
        'diasParaFinSemestre', CASE WHEN v_semestre_actual IS NOT NULL THEN v_fin - v_hoy END);

    -- Estudiantes: matrículas del año (activos = sin retiro).
    SELECT jsonb_build_object(
               'matriculados', COUNT(*) FILTER (WHERE m.fecha_retiro IS NULL),
               'retirados', COUNT(*) FILTER (WHERE m.fecha_retiro IS NOT NULL),
               'nivel11', COUNT(*) FILTER (WHERE m.fecha_retiro IS NULL AND s.nivel = 11),
               'nivel12', COUNT(*) FILTER (WHERE m.fecha_retiro IS NULL AND s.nivel = 12))
    INTO v_estudiantes
    FROM academico.matriculas m JOIN academico.secciones s ON s.id_seccion = m.id_seccion
    WHERE m.id_periodo = p.id_periodo;

    SELECT jsonb_build_object('total', COUNT(*), 'sinGuia', COUNT(*) FILTER (WHERE s.id_profesor_guia IS NULL))
    INTO v_secciones FROM academico.secciones s WHERE s.id_periodo = p.id_periodo;

    -- Profesores con cuenta: activos, inactivos y activos sin asignación ni sección guía en el año.
    SELECT jsonb_build_object(
               'activos', COUNT(*) FILTER (WHERE u.activo),
               'inactivos', COUNT(*) FILTER (WHERE NOT u.activo),
               'sinAsignacion', COUNT(*) FILTER (WHERE u.activo
                   AND NOT EXISTS (SELECT 1 FROM academico.asignaciones_docentes a JOIN academico.secciones s ON s.id_seccion = a.id_seccion
                                   WHERE a.id_profesor = pr.id_profesor AND s.id_periodo = p.id_periodo)
                   AND NOT EXISTS (SELECT 1 FROM academico.secciones s WHERE s.id_profesor_guia = pr.id_profesor AND s.id_periodo = p.id_periodo)))
    INTO v_profesores
    FROM academico.profesores pr JOIN api.usuarios u ON u.id_usuario = pr.id_usuario;

    SELECT jsonb_build_object(
               'asignaciones', (SELECT COUNT(*) FROM academico.asignaciones_docentes a JOIN academico.secciones s ON s.id_seccion = a.id_seccion
                                WHERE s.id_periodo = p.id_periodo),
               'seccionesSinAsignaciones', (SELECT COUNT(*) FROM academico.secciones s WHERE s.id_periodo = p.id_periodo
                                            AND NOT EXISTS (SELECT 1 FROM academico.asignaciones_docentes a WHERE a.id_seccion = s.id_seccion)))
    INTO v_carga;

    -- Notas del semestre por asignación (fn_tablero_notas) y su resumen por nivel.
    SELECT jsonb_build_object(
               'asignaciones', COUNT(*),
               'confirmadas', COUNT(*) FILTER (WHERE t.confirmada),
               'completasSinConfirmar', COUNT(*) FILTER (WHERE NOT t.confirmada AND t.sin_nota = 0),
               'incompletas', COUNT(*) FILTER (WHERE NOT t.confirmada AND t.sin_nota > 0),
               'porNivel', COALESCE((SELECT jsonb_agg(n ORDER BY (n->>'nivel')::INTEGER) FROM (
                    SELECT jsonb_build_object('nivel', t2.nivel,
                               'confirmadas', COUNT(*) FILTER (WHERE t2.confirmada),
                               'completasSinConfirmar', COUNT(*) FILTER (WHERE NOT t2.confirmada AND t2.sin_nota = 0),
                               'incompletas', COUNT(*) FILTER (WHERE NOT t2.confirmada AND t2.sin_nota > 0)) AS n
                    FROM academico.fn_tablero_notas(p, v_semestre) t2 GROUP BY t2.nivel) y), '[]'::JSONB))
    INTO v_notas FROM academico.fn_tablero_notas(p, v_semestre) t;

    -- Monografías de las cohortes que cursan el año (empiezan en 11, RN-78: cohorte = año de inicio, este o el anterior).
    SELECT jsonb_build_object(
               'enCurso', COUNT(*) FILTER (WHERE mo.estado <> 'TERMINADA'),
               'terminadas', COUNT(*) FILTER (WHERE mo.estado = 'TERMINADA'),
               'porCohorte', COALESCE((SELECT jsonb_agg(c ORDER BY c->>'cohorte') FROM (
                    SELECT jsonb_build_object('cohorte', pi.anio,
                               'capacitacion', COUNT(*) FILTER (WHERE mo2.estado = 'CAPACITACION'),
                               'investigacion', COUNT(*) FILTER (WHERE mo2.estado = 'INVESTIGACION'),
                               'terminada', COUNT(*) FILTER (WHERE mo2.estado = 'TERMINADA')) AS c
                    FROM academico.monografias mo2
                    JOIN academico.matriculas mi2 ON mi2.id_matricula = mo2.id_matricula_inicio
                    JOIN academico.periodos_academicos pi ON pi.id_periodo = mi2.id_periodo
                    WHERE pi.anio IN (p.anio, p.anio - 1)
                    GROUP BY pi.anio) x), '[]'::JSONB))
    INTO v_monografias
    FROM academico.monografias mo
    JOIN academico.matriculas mi ON mi.id_matricula = mo.id_matricula_inicio
    JOIN academico.periodos_academicos pi ON pi.id_periodo = mi.id_periodo
    WHERE pi.anio IN (p.anio, p.anio - 1);

    -- Matrícula por sección.
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
               'seccion', s.nivel || '-' || s.numero, 'nivel', s.nivel,
               'activos', (SELECT COUNT(*) FROM academico.matriculas m WHERE m.id_seccion = s.id_seccion AND m.fecha_retiro IS NULL),
               'retirados', (SELECT COUNT(*) FROM academico.matriculas m WHERE m.id_seccion = s.id_seccion AND m.fecha_retiro IS NOT NULL),
               'guia', (SELECT concat_ws(' ', g.nombre, g.primer_apellido) FROM academico.profesores g WHERE g.id_profesor = s.id_profesor_guia))
           ORDER BY s.nivel, s.numero), '[]'::JSONB)
    INTO v_matricula
    FROM academico.secciones s WHERE s.id_periodo = p.id_periodo;

    -- Ausentismo del semestre: las 5 secciones con más ausencias injustificadas por lección (RN-70).
    SELECT COALESCE(jsonb_agg(x ORDER BY (x->>'injustificadasPorLeccion')::NUMERIC DESC, x->>'seccion'), '[]'::JSONB)
    INTO v_ausentismo
    FROM (
        SELECT jsonb_build_object(
                   'seccion', s.nivel || '-' || s.numero,
                   'lecciones', COUNT(DISTINCT l.id_leccion),
                   'injustificadas', COUNT(au.id_leccion) FILTER (WHERE NOT au.tardia AND au.justificacion IS NULL),
                   'justificadas', COUNT(au.id_leccion) FILTER (WHERE au.justificacion IS NOT NULL),
                   'tardias', COUNT(au.id_leccion) FILTER (WHERE au.tardia),
                   'injustificadasPorLeccion', ROUND(COUNT(au.id_leccion) FILTER (WHERE NOT au.tardia AND au.justificacion IS NULL)::NUMERIC
                                                     / NULLIF(COUNT(DISTINCT l.id_leccion), 0), 2)) AS x
        FROM academico.secciones s
        JOIN academico.asignaciones_docentes a ON a.id_seccion = s.id_seccion
        JOIN academico.lecciones l ON l.id_asignacion = a.id_asignacion
             AND l.fecha BETWEEN academico.fn_inicio_semestre(p, v_semestre) AND v_fin
        LEFT JOIN academico.ausencias au ON au.id_leccion = l.id_leccion
        WHERE s.id_periodo = p.id_periodo
        GROUP BY s.id_seccion, s.nivel, s.numero
        ORDER BY COUNT(au.id_leccion) FILTER (WHERE NOT au.tardia AND au.justificacion IS NULL)::NUMERIC
                 / NULLIF(COUNT(DISTINCT l.id_leccion), 0) DESC NULLS LAST, s.nivel, s.numero
        LIMIT 5) t;

    -- Alertas. Las de secciones y monografías solo en periodos no finalizados (ya no se corrigen).
    SELECT COUNT(*), COALESCE(jsonb_agg(s.nivel || '-' || s.numero ORDER BY s.nivel, s.numero), '[]'::JSONB)
    INTO v_cantidad, v_detalle
    FROM academico.secciones s WHERE s.id_periodo = p.id_periodo AND s.id_profesor_guia IS NULL AND v_estado <> 'FINALIZADO';
    IF v_cantidad > 0 THEN
        v_alertas := v_alertas || jsonb_build_object('codigo', 'SECCIONES_SIN_GUIA', 'nivel', 'PRIORIDAD', 'cantidad', v_cantidad, 'detalle', v_detalle);
    END IF;

    SELECT COUNT(*), COALESCE(jsonb_agg(s.nivel || '-' || s.numero ORDER BY s.nivel, s.numero), '[]'::JSONB)
    INTO v_cantidad, v_detalle
    FROM academico.secciones s
    WHERE s.id_periodo = p.id_periodo
      AND NOT EXISTS (SELECT 1 FROM academico.asignaciones_docentes a JOIN academico.asignaturas asg ON asg.id_asignatura = a.id_asignatura
                      WHERE a.id_seccion = s.id_seccion AND asg.codigo = 'CAS')
      AND v_estado <> 'FINALIZADO';
    IF v_cantidad > 0 THEN
        v_alertas := v_alertas || jsonb_build_object('codigo', 'SECCIONES_SIN_CAS', 'nivel', 'AVISO', 'cantidad', v_cantidad, 'detalle', v_detalle);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM api.usuario_roles r JOIN api.usuarios u ON u.id_usuario = r.id_usuario WHERE r.rol = 'COORD_CAS' AND u.activo) THEN
        v_alertas := v_alertas || jsonb_build_object('codigo', 'SIN_COORDINADOR_CAS', 'nivel', 'AVISO', 'cantidad', 1, 'detalle', '[]'::JSONB);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM api.usuario_roles r JOIN api.usuarios u ON u.id_usuario = r.id_usuario WHERE r.rol = 'COORD_MONOGRAFIA' AND u.activo) THEN
        v_alertas := v_alertas || jsonb_build_object('codigo', 'SIN_COORDINADOR_MONOGRAFIA', 'nivel', 'AVISO', 'cantidad', 1, 'detalle', '[]'::JSONB);
    END IF;

    IF v_estado <> 'FINALIZADO' THEN
        SELECT COUNT(*), COALESCE(jsonb_agg(DISTINCT s.nivel || '-' || s.numero), '[]'::JSONB)
        INTO v_cantidad, v_detalle
        FROM academico.matriculas m JOIN academico.secciones s ON s.id_seccion = m.id_seccion
        WHERE m.id_periodo = p.id_periodo AND s.nivel = 11 AND m.fecha_retiro IS NULL
          AND NOT EXISTS (SELECT 1 FROM academico.monografias mo WHERE mo.id_estudiante = m.id_estudiante);
        IF v_cantidad > 0 THEN
            v_alertas := v_alertas || jsonb_build_object('codigo', 'ESTUDIANTES_SIN_MONOGRAFIA', 'nivel', 'AVISO', 'cantidad', v_cantidad, 'detalle', v_detalle);
        END IF;
    END IF;

    SELECT COUNT(*), MIN(t.cierre - v_hoy),
           COALESCE(jsonb_agg(jsonb_build_object('profesor', t.profesor, 'asignatura', t.asignatura, 'seccion', t.seccion,
                                                 'sinNota', t.sin_nota, 'estudiantes', t.estudiantes, 'confirmada', t.confirmada,
                                                 'diasParaCierre', t.cierre - v_hoy)
                              ORDER BY t.cierre, t.seccion, t.asignatura), '[]'::JSONB)
    INTO v_cantidad, v_min_dias, v_detalle
    FROM academico.fn_tablero_notas(p, v_semestre) t
    WHERE v_hoy BETWEEN academico.fn_inicio_semestre(p, v_semestre) AND t.cierre
      AND t.cierre - v_hoy <= 30
      AND NOT (t.sin_nota = 0 AND t.confirmada);
    IF v_cantidad > 0 THEN
        v_alertas := v_alertas || jsonb_build_object('codigo', 'NOTAS_PENDIENTES', 'nivel', CASE WHEN v_min_dias <= 15 THEN 'PRIORIDAD' ELSE 'AVISO' END,
                                                     'cantidad', v_cantidad, 'diasParaCierre', v_min_dias, 'detalle', v_detalle);
    END IF;

    SELECT COUNT(*), COALESCE(jsonb_agg(jsonb_build_object('profesor', concat_ws(' ', pr.nombre, pr.primer_apellido),
                                                            'semestre', pg.semestre, 'fechaLimite', pg.fecha_limite)
                                         ORDER BY pg.fecha_limite), '[]'::JSONB)
    INTO v_cantidad, v_detalle
    FROM academico.prorrogas pg JOIN academico.profesores pr ON pr.id_profesor = pg.id_profesor
    WHERE pg.id_periodo = p.id_periodo AND pg.fecha_limite >= v_hoy;
    IF v_cantidad > 0 THEN
        v_alertas := v_alertas || jsonb_build_object('codigo', 'PRORROGAS_VIGENTES', 'nivel', 'INFO', 'cantidad', v_cantidad, 'detalle', v_detalle);
    END IF;

    RETURN jsonb_build_object(
        'periodo', v_periodo, 'aniosDisponibles', v_anios, 'estudiantes', v_estudiantes, 'secciones', v_secciones,
        'profesores', v_profesores, 'cargaDocente', v_carga, 'notas', v_notas, 'monografias', v_monografias,
        'matriculaPorSeccion', v_matricula, 'ausentismo', v_ausentismo, 'alertas', v_alertas, 'actividad', v_actividad);
END;
$$;
