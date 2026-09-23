CREATE TYPE api.roles AS ENUM ('ADMIN','PROFESOR','GUIA','COORD_MONOGRAFIA','COORD_CAS');

CREATE TYPE api.usuario AS (
    id_usuario UUID,
    email TEXT,
    password_hash TEXT,
    activo BOOLEAN,
    bloqueado_hasta TIMESTAMPTZ,
    roles TEXT[]
);

CREATE TYPE api.rotate_session_result AS (
    out_status TEXT,
    out_user_id UUID,
    out_email TEXT, 
    out_roles TEXT[]
);

-- ============================================================
-- FUNCIONES AUXILIARES
-- ============================================================
CREATE OR REPLACE FUNCTION auth.fn_lanzar_excepcion(
    p_codigo TEXT,
    p_mensaje TEXT
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION USING ERRCODE = p_codigo, MESSAGE = p_mensaje;
END;
$$;

-- ============================================================
-- TABLAS
-- ============================================================

-- USUARIOS
CREATE TABLE api.usuarios (
    id_usuario UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT NOT NULL,
    password_hash TEXT NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    intentos_fallidos_login INTEGER NOT NULL DEFAULT 0,
    bloqueado_hasta TIMESTAMPTZ NULL,
    ultimo_login TIMESTAMPTZ NULL,
    password_cambiada_en TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    actualizado_en TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    tokens_invalidados_desde TIMESTAMPTZ NULL,
    CONSTRAINT ck_usuarios_email_lower CHECK (email = lower(email)),
    CONSTRAINT uq_usuarios_email UNIQUE (email),
    CONSTRAINT ck_usuarios_email_length CHECK (length(email) BETWEEN 3 AND 254),
    CONSTRAINT ck_usuarios_intentos_fallidos CHECK (intentos_fallidos_login >= 0),
    CONSTRAINT ck_usuarios_email_format CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
);

-- ROLES DE USUARIO
CREATE TABLE api.usuario_roles (
    id_usuario UUID NOT NULL,
    rol api.roles NOT NULL,
    asignado_en TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    asignado_por UUID NULL,
    CONSTRAINT pk_usuario_roles PRIMARY KEY (id_usuario, rol),
    CONSTRAINT fk_usuario_roles_usuario FOREIGN KEY (id_usuario) REFERENCES api.usuarios (id_usuario) ON DELETE CASCADE,
    CONSTRAINT fk_usuario_roles_asignado_por FOREIGN KEY (asignado_por) REFERENCES api.usuarios (id_usuario) ON DELETE SET NULL
);
CREATE INDEX ix_usuario_roles_rol ON api.usuario_roles (rol);

-- SESIONES
CREATE TABLE api.sesiones (
    id_sesion UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_usuario UUID NOT NULL,
    token_hash TEXT NOT NULL,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expira_en TIMESTAMPTZ NOT NULL,
    rotado_en TIMESTAMPTZ NULL,
    direccion_ip TEXT NULL,
    agente_usuario TEXT NULL,
    CONSTRAINT fk_sesiones_usuario FOREIGN KEY (id_usuario) REFERENCES api.usuarios (id_usuario) ON DELETE CASCADE,
    CONSTRAINT ck_sesiones_expiracion CHECK (expira_en > creado_en)
);
CREATE UNIQUE INDEX ux_sesiones_token_hash ON api.sesiones (token_hash);
CREATE INDEX ix_sesiones_user_id ON api.sesiones (id_usuario);
CREATE INDEX ix_sesiones_expira_en ON api.sesiones (expira_en);

CREATE TABLE IF NOT EXISTS api.bootstrap_admin (
    id INTEGER PRIMARY KEY,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    id_usuario UUID NOT NULL,
    CONSTRAINT fk_bootstrap_admin_usuario FOREIGN KEY (id_usuario) REFERENCES api.usuarios (id_usuario)
);

-- ============================================================
-- FUNCIONES DE BOOTSTRAP
-- ============================================================
CREATE OR REPLACE FUNCTION auth.fn_crear_primer_admin(
    p_email TEXT,
    p_password_hash TEXT
)
RETURNS UUID
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_usuario UUID;
BEGIN
    PERFORM pg_advisory_xact_lock(hashtextextended('api.bootstrap_admin', 0));

    IF EXISTS (SELECT 1 FROM api.bootstrap_admin WHERE id = 1) THEN
        PERFORM auth.fn_lanzar_excepcion('AP004', 'El administrador inicial ya fue creado.');
    END IF;

    IF EXISTS (SELECT 1 FROM api.usuarios WHERE email = lower(trim(p_email))) THEN
        PERFORM auth.fn_lanzar_excepcion('AP005', 'El correo ya está en uso.');
    END IF;

    INSERT INTO api.usuarios (email, password_hash, activo)
    VALUES (lower(trim(p_email)), p_password_hash, TRUE)
    RETURNING id_usuario INTO v_id_usuario;

    INSERT INTO api.usuario_roles (id_usuario, rol, asignado_por)
    VALUES (v_id_usuario, 'ADMIN', NULL);

    INSERT INTO api.bootstrap_admin (id, id_usuario) VALUES (1, v_id_usuario);

    RETURN v_id_usuario;
END;
$$;

-- ============================================================
-- FUNCIONES DE AUTENTICACIÓN
-- ============================================================

-- Registrar usuario. Devuelve el id nuevo, o NULL si el correo ya existe.
CREATE OR REPLACE FUNCTION auth.fn_registrar_usuario(
    p_email text, 
    p_password_hash text)
RETURNS UUID
LANGUAGE plpgsql
AS $$
DECLARE
    v_id UUID;
BEGIN
    INSERT INTO api.usuarios (email, password_hash)
    VALUES (lower(trim(p_email)), p_password_hash)
    ON CONFLICT (email) DO NOTHING
    RETURNING id_usuario INTO v_id;

    IF v_id IS NOT NULL THEN
        INSERT INTO api.usuario_roles (id_usuario, rol) VALUES (v_id, 'PROFESOR');
    END IF;

    RETURN v_id;
END;
$$;

-- Obtener usuario por email. Devuelve NULL si no existe.
CREATE OR REPLACE FUNCTION auth.fn_obtener_usuario_por_email(
    p_email TEXT
)
RETURNS SETOF api.usuario
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT u.id_usuario, u.email, u.password_hash, u.activo, u.bloqueado_hasta,
           COALESCE(array_agg(ur.rol::text) FILTER (WHERE ur.rol IS NOT NULL), ARRAY[]::text[])
    FROM api.usuarios u
    LEFT JOIN api.usuario_roles ur ON ur.id_usuario = u.id_usuario
    WHERE u.email = lower(trim(p_email))
    GROUP BY u.id_usuario, u.email, u.password_hash, u.activo, u.bloqueado_hasta;
END;
$$;

-- Obtener usuario por id. Devuelve NULL si no existe.
CREATE OR REPLACE FUNCTION auth.fn_obtener_usuario_por_id(
    p_id_usuario UUID
)
RETURNS SETOF api.usuario
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT u.id_usuario, u.email, u.password_hash, u.activo, u.bloqueado_hasta,
           COALESCE(array_agg(ur.rol::text) FILTER (WHERE ur.rol IS NOT NULL), ARRAY[]::text[])
    FROM api.usuarios u
    LEFT JOIN api.usuario_roles ur ON ur.id_usuario = u.id_usuario
    WHERE u.id_usuario = p_id_usuario
    GROUP BY u.id_usuario, u.email, u.password_hash, u.activo, u.bloqueado_hasta;
END;
$$;

-- Renovar sesión (rotación de refresh token), todo en UNA transacción.
-- Devuelve out_status:
--   'ok'       -> token válido; se marcó como usado y se creó uno nuevo
--   'invalid'  -> no existe / usuario inactivo
--   'expired'  -> el token expiró
--   'reused'   -> alguien intentó usar un token ya usado (posible robo):
--                 se cierran TODAS las sesiones del usuario
CREATE OR REPLACE FUNCTION auth.fn_rotar_sesion(
    p_old_token_hash TEXT,
    p_new_token_hash TEXT,
    p_new_expires_at TIMESTAMPTZ,
    p_direccion_ip TEXT,
    p_agente_usuario TEXT
) RETURNS SETOF api.rotate_session_result
LANGUAGE plpgsql
AS $$
DECLARE
    v_sesion api.sesiones%ROWTYPE;
    v_usuario api.usuarios%ROWTYPE;
    v_roles TEXT[];
BEGIN
    SELECT * INTO v_sesion FROM api.sesiones s WHERE s.token_hash = p_old_token_hash FOR UPDATE;

    IF NOT FOUND THEN
        RETURN QUERY SELECT 'invalid'::TEXT, NULL::UUID, NULL::TEXT, NULL::TEXT[];
        RETURN;
    END IF;

    IF v_sesion.rotado_en IS NOT NULL THEN
        -- Reuso de un refresh token ya rotado = posible robo. No alcanza con
        -- borrar las sesiones (refresh tokens): hay que invalidar también los
        -- access tokens (JWT) ya emitidos, que si no siguen siendo válidos
        -- hasta su expiración natural pese a que el robo ya fue detectado.
        DELETE FROM api.sesiones WHERE id_usuario = v_sesion.id_usuario;
        UPDATE api.usuarios SET tokens_invalidados_desde = NOW() WHERE id_usuario = v_sesion.id_usuario;
        RETURN QUERY SELECT 'reused'::TEXT, NULL::UUID, NULL::TEXT, NULL::TEXT[];
        RETURN;
    END IF;

    IF v_sesion.expira_en <= NOW() THEN
        RETURN QUERY SELECT 'expired'::TEXT, NULL::UUID, NULL::TEXT, NULL::TEXT[];
        RETURN;
    END IF;

    SELECT * INTO v_usuario FROM api.usuarios u WHERE u.id_usuario = v_sesion.id_usuario;

    IF NOT FOUND OR NOT v_usuario.activo THEN
        RETURN QUERY SELECT 'invalid'::TEXT, NULL::UUID, NULL::TEXT, NULL::TEXT[];
        RETURN;
    END IF;

    SELECT COALESCE(array_agg(rol::text), ARRAY[]::text[]) INTO v_roles
    FROM api.usuario_roles WHERE id_usuario = v_usuario.id_usuario;

    UPDATE api.sesiones SET rotado_en = NOW() WHERE id_sesion = v_sesion.id_sesion;

    INSERT INTO api.sesiones (id_usuario, token_hash, expira_en, direccion_ip, agente_usuario)
    VALUES (v_sesion.id_usuario, p_new_token_hash, p_new_expires_at, p_direccion_ip, p_agente_usuario);

    RETURN QUERY SELECT 'ok'::TEXT, v_usuario.id_usuario, v_usuario.email, v_roles;
END;
$$;

-- Otorga un rol adicional (no reemplaza los que ya tiene)
CREATE OR REPLACE FUNCTION auth.fn_asignar_rol(
    p_id_usuario_actor UUID,
    p_id_usuario_objetivo UUID,
    p_rol api.roles
) RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    v_es_admin BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM api.usuarios u
        JOIN api.usuario_roles ur ON ur.id_usuario = u.id_usuario
        WHERE u.id_usuario = p_id_usuario_actor AND u.activo = TRUE AND ur.rol = 'ADMIN'
    ) INTO v_es_admin;

    IF NOT v_es_admin THEN
        PERFORM auth.fn_lanzar_excepcion('AP001', 'No tienes permisos para asignar roles.');
    END IF;

    IF NOT EXISTS (SELECT 1 FROM api.usuarios WHERE id_usuario = p_id_usuario_objetivo) THEN
        PERFORM auth.fn_lanzar_excepcion('AP002', 'El usuario objetivo no existe.');
    END IF;

    INSERT INTO api.usuario_roles (id_usuario, rol, asignado_por)
    VALUES (p_id_usuario_objetivo, p_rol, p_id_usuario_actor)
    ON CONFLICT (id_usuario, rol) DO NOTHING;

    IF NOT FOUND THEN
        RETURN 'SIN_CAMBIOS';
    END IF;

    -- Cierra sesiones e invalida access tokens ya emitidos (ver sección de revocación)
    DELETE FROM api.sesiones WHERE id_usuario = p_id_usuario_objetivo;
    UPDATE api.usuarios SET tokens_invalidados_desde = NOW() WHERE id_usuario = p_id_usuario_objetivo;

    RETURN 'OK';
END;
$$;

-- Quita un rol. No permite dejar al usuario sin ningún rol.
CREATE OR REPLACE FUNCTION auth.fn_revocar_rol(
    p_id_usuario_actor UUID,
    p_id_usuario_objetivo UUID,
    p_rol api.roles
) RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    v_es_admin BOOLEAN;
    v_cantidad_roles INTEGER;
BEGIN
    
    SELECT EXISTS (
        SELECT 1 FROM api.usuarios u
        JOIN api.usuario_roles ur ON ur.id_usuario = u.id_usuario
        WHERE u.id_usuario = p_id_usuario_actor AND u.activo = TRUE AND ur.rol = 'ADMIN'
    ) INTO v_es_admin;

    IF NOT v_es_admin THEN
        PERFORM auth.fn_lanzar_excepcion('AP001', 'No tienes permisos para revocar roles.');
    END IF;

    IF NOT EXISTS (SELECT 1 FROM api.usuarios WHERE id_usuario = p_id_usuario_objetivo) THEN
        PERFORM auth.fn_lanzar_excepcion('AP002', 'El usuario objetivo no existe.');
    END IF;

    DELETE FROM api.usuario_roles
    WHERE id_usuario = p_id_usuario_objetivo AND rol = p_rol;

    IF NOT FOUND THEN
        RETURN 'SIN_CAMBIOS';
    END IF;

    IF p_rol = 'PROFESOR' THEN
        PERFORM auth.fn_lanzar_excepcion('AP006', 'No se puede quitar el rol de PROFESOR.');
    END IF;

    SELECT COUNT(*) INTO v_cantidad_roles
    FROM api.usuario_roles WHERE id_usuario = p_id_usuario_objetivo;

    IF v_cantidad_roles = 0 THEN
        PERFORM auth.fn_lanzar_excepcion('AP003', 'No se puede quitar el único rol que tiene el usuario.');
    END IF;

    DELETE FROM api.sesiones WHERE id_usuario = p_id_usuario_objetivo;
    UPDATE api.usuarios SET tokens_invalidados_desde = NOW() WHERE id_usuario = p_id_usuario_objetivo;

    RETURN 'OK';
END;
$$;

-- Login fallido: suma un intento; al llegar al máximo bloquea la cuenta
-- p_minutos_bloqueo minutos y reinicia el contador.
CREATE OR REPLACE PROCEDURE auth.sp_registrar_login_fallido(
    p_id_usuario UUID,
    p_intentos_maximos INTEGER,
    p_minutos_bloqueo INTEGER
)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE api.usuarios
    SET
        bloqueado_hasta =
            CASE
                WHEN intentos_fallidos_login + 1 >= p_intentos_maximos THEN
                    NOW() + make_interval(mins => p_minutos_bloqueo)
                ELSE
                    bloqueado_hasta
            END,

        intentos_fallidos_login =
            CASE
                WHEN intentos_fallidos_login + 1 >= p_intentos_maximos THEN
                    0
                ELSE
                    intentos_fallidos_login + 1
            END,

        actualizado_en = NOW()

    WHERE id_usuario = p_id_usuario;
END;
$$;

-- Login exitoso: limpia contadores y registra la fecha
CREATE OR REPLACE PROCEDURE auth.sp_registrar_login_exitoso(
    p_id_usuario UUID
)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE api.usuarios
    SET intentos_fallidos_login = 0,
        bloqueado_hasta = NULL,
        ultimo_login = NOW(),
        actualizado_en  = NOW()
    WHERE id_usuario = p_id_usuario;
END;
$$;

-- Crear sesión (guarda el hash del refresh token)
CREATE OR REPLACE PROCEDURE auth.sp_crear_sesion(
    p_id_usuario UUID,
    p_token_hash TEXT,
    p_expira_en TIMESTAMPTZ,
    p_direccion_ip TEXT,
    p_agente_usuario TEXT
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO api.sesiones (
        id_usuario, token_hash, expira_en, direccion_ip, agente_usuario
    ) VALUES (
        p_id_usuario, p_token_hash, p_expira_en, p_direccion_ip, p_agente_usuario
    );
END;
$$;

-- Logout (esta sesión) y logout global (todas las sesiones)
CREATE OR REPLACE PROCEDURE auth.sp_logout(
    p_token_hash TEXT
)
LANGUAGE plpgsql
AS $$
BEGIN
    DELETE FROM api.sesiones WHERE token_hash = p_token_hash;
END;
$$;

-- Logout global (todas las sesiones)
CREATE OR REPLACE PROCEDURE auth.sp_logout_all(p_id_usuario UUID)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE api.usuarios SET tokens_invalidados_desde = NOW() WHERE id_usuario = p_id_usuario;
    DELETE FROM api.sesiones WHERE id_usuario = p_id_usuario;
END;
$$;

-- Cambio de contraseña: actualiza el hash y cierra TODAS las sesiones
-- (atómico: si algo falla, no se aplica nada)
CREATE OR REPLACE PROCEDURE auth.sp_cambiar_contrasena(
    p_id_usuario UUID,
    p_new_password_hash TEXT
)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE api.usuarios
    SET password_hash = p_new_password_hash,
        password_cambiada_en = NOW(),
        intentos_fallidos_login = 0,
        bloqueado_hasta = NULL,
        tokens_invalidados_desde = NOW(),
        actualizado_en = NOW()
    WHERE id_usuario = p_id_usuario;

    DELETE FROM api.sesiones WHERE id_usuario = p_id_usuario;
END;
$$;

-- Mantenimiento: borrar sesiones expiradas (programar 1 vez al día,
-- por ejemplo con pg_cron o un job del backend)
CREATE OR REPLACE PROCEDURE auth.sp_purgar_sesiones_expiradas()
LANGUAGE plpgsql
AS $$
BEGIN
    DELETE FROM api.sesiones WHERE expira_en < NOW();
END;
$$;

-- ver si el bootstrap ya fue ejecutado
SELECT * FROM api.bootstrap_admin;

-- sesiones
SELECT * FROM api.sesiones;

-- usuarios y sus roles
SELECT u.id_usuario, u.email, u.activo, u.bloqueado_hasta, array_agg(ur.rol) AS roles
FROM api.usuarios u
LEFT JOIN api.usuario_roles ur ON ur.id_usuario = u.id_usuario
GROUP BY u.id_usuario, u.email, u.activo, u.bloqueado_hasta;