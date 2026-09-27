SET search_path = academico, api, auth, public;
-- ============================================================
-- ENUMS
-- ============================================================
CREATE TYPE api.roles AS ENUM (
    'ADMIN',
    'PROFESOR_REGULAR',
    'PROFESOR_CAS',
    'GUIA',
    'COORD_MONOGRAFIA',
    'COORD_CAS'
);

-- ============================================================
-- PUBLIC TYPES
-- ============================================================
CREATE TYPE api.usuario AS (
    id_usuario UUID,
    email CITEXT,
    password_hash TEXT,
    activo BOOLEAN,
    bloqueado_hasta TIMESTAMPTZ,
    roles api.roles[]
);

CREATE TYPE api.rotate_session_result AS (
    out_status TEXT,
    out_user_id UUID,
    out_email CITEXT, 
    out_roles api.roles[]
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
    email CITEXT NOT NULL,
    password_hash TEXT NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    intentos_fallidos_login INTEGER NOT NULL DEFAULT 0,
    bloqueado_hasta TIMESTAMPTZ NULL,
    ultimo_login TIMESTAMPTZ NULL,
    password_cambiada_en TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    actualizado_en TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    tokens_invalidados_desde TIMESTAMPTZ NULL,
    CONSTRAINT ck_usuarios_password_hash_not_empty CHECK (trim(password_hash) <> ''),
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

-- BOOTSTRAP ADMIN
CREATE TABLE IF NOT EXISTS api.bootstrap_admin (
    id_bootstrap INTEGER PRIMARY KEY,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    id_usuario UUID NOT NULL,
    CONSTRAINT fk_bootstrap_admin_usuario FOREIGN KEY (id_usuario) REFERENCES api.usuarios (id_usuario)
);

-- ============================================================
-- FUNCIONES DE BOOTSTRAP
-- ============================================================
CREATE OR REPLACE FUNCTION auth.fn_crear_primer_admin(
    p_email CITEXT,
    p_password_hash TEXT
)
RETURNS UUID
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_id_usuario UUID;
BEGIN
    PERFORM pg_advisory_xact_lock(hashtextextended('api.bootstrap_admin', 0));

    IF EXISTS (SELECT 1 FROM api.bootstrap_admin) THEN
        PERFORM auth.fn_lanzar_excepcion('AU001', 'El administrador inicial ya fue creado.');
    END IF;
    
    IF p_email IS NULL OR trim(p_email::TEXT) = '' THEN
        PERFORM auth.fn_lanzar_excepcion('NU001', 'El correo no puede estar vacío.');
    END IF;

    IF EXISTS (SELECT 1 FROM api.usuarios WHERE email = trim(p_email::TEXT)::CITEXT) THEN
        PERFORM auth.fn_lanzar_excepcion('TA001', 'El correo ya está en uso.');
    END IF;

    IF p_password_hash IS NULL OR trim(p_password_hash) = '' THEN
        PERFORM auth.fn_lanzar_excepcion('NU002', 'La contraseña no puede estar vacía.');
    END IF;

    INSERT INTO api.usuarios (email, password_hash, activo)
    VALUES (trim(p_email::TEXT)::CITEXT, p_password_hash, TRUE)
    RETURNING id_usuario INTO v_id_usuario;

    INSERT INTO api.usuario_roles (id_usuario, rol, asignado_por)
    VALUES (v_id_usuario, 'ADMIN', NULL);

    INSERT INTO api.bootstrap_admin (id_bootstrap, id_usuario)
    VALUES (1, v_id_usuario);

    RETURN v_id_usuario;
END;
$$;

-- ============================================================
-- FUNCIONES DE AUTENTICACIÓN
-- ============================================================
-- Registrar usuario. Devuelve el id nuevo, o NULL si el correo ya existe.
CREATE OR REPLACE FUNCTION auth.fn_registrar_usuario(
    p_email CITEXT,
    p_password_hash TEXT
)
RETURNS UUID
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_id UUID;
BEGIN
    IF p_email IS NULL OR trim(p_email::TEXT) = '' THEN
        PERFORM auth.fn_lanzar_excepcion('NU001', 'El correo no puede estar vacío.');
    END IF;

    IF p_password_hash IS NULL OR trim(p_password_hash) = '' THEN
        PERFORM auth.fn_lanzar_excepcion('NU002', 'La contraseña no puede estar vacía.');
    END IF;

    INSERT INTO api.usuarios (email, password_hash)
    VALUES (trim(p_email::TEXT)::CITEXT, p_password_hash)
    ON CONFLICT (email) DO NOTHING
    RETURNING id_usuario
    INTO v_id;

    IF v_id IS NOT NULL THEN
        INSERT INTO api.usuario_roles (id_usuario, rol)
        VALUES (v_id, 'PROFESOR_REGULAR');
    END IF;

    RETURN v_id;
END;
$$;

-- Obtener usuario por email. Devuelve 0 filas si no existe.
CREATE OR REPLACE FUNCTION auth.fn_obtener_usuario_por_email(
    p_email CITEXT
)
RETURNS SETOF api.usuario
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
BEGIN
    RETURN QUERY
    SELECT
        u.id_usuario,
        u.email,
        u.password_hash,
        u.activo,
        u.bloqueado_hasta,
        COALESCE(
            array_agg(ur.rol) FILTER (WHERE ur.rol IS NOT NULL),
            ARRAY[]::api.roles[]
        )
    FROM api.usuarios u
    LEFT JOIN api.usuario_roles ur
        ON ur.id_usuario = u.id_usuario
    WHERE u.email = trim(p_email::TEXT)::CITEXT
    GROUP BY
        u.id_usuario,
        u.email,
        u.password_hash,
        u.activo,
        u.bloqueado_hasta;
END;
$$;

-- Obtener usuario por ID. Devuelve 0 filas si no existe.
CREATE OR REPLACE FUNCTION auth.fn_obtener_usuario_por_id(
    p_id_usuario UUID
)
RETURNS SETOF api.usuario
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
BEGIN
    RETURN QUERY
    SELECT
        u.id_usuario,
        u.email,
        u.password_hash,
        u.activo,
        u.bloqueado_hasta,
        COALESCE(
            array_agg(ur.rol) FILTER (WHERE ur.rol IS NOT NULL),
            ARRAY[]::api.roles[]
        )
    FROM api.usuarios u
    LEFT JOIN api.usuario_roles ur
        ON ur.id_usuario = u.id_usuario
    WHERE u.id_usuario = p_id_usuario
    GROUP BY
        u.id_usuario,
        u.email,
        u.password_hash,
        u.activo,
        u.bloqueado_hasta;
END;
$$;

-- Renovar sesión (rotación de refresh token). Todo ocurre dentro de la transacción de la función.
-- out_status:
--   'ok'       -> token válido; se marcó como usado y se creó uno nuevo
--   'invalid'  -> no existe / usuario inactivo
--   'expired'  -> el token expiró
--   'reused'   -> se intentó usar un token ya usado.
--                 Se cierran todas las sesiones del usuario y
--                 se invalidan los access tokens emitidos.
CREATE OR REPLACE FUNCTION auth.fn_rotar_sesion(
    p_old_token_hash TEXT,
    p_new_token_hash TEXT,
    p_new_expires_at TIMESTAMPTZ,
    p_direccion_ip TEXT,
    p_agente_usuario TEXT
)
RETURNS SETOF api.rotate_session_result
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_sesion api.sesiones%ROWTYPE;
    v_usuario api.usuarios%ROWTYPE;
    v_roles api.roles[];
BEGIN
    -- Buscar y bloquear el refresh token.
    SELECT *
    INTO v_sesion
    FROM api.sesiones s
    WHERE s.token_hash = p_old_token_hash
    FOR UPDATE;

    -- Token inexistente.
    IF NOT FOUND THEN
        RETURN QUERY
        SELECT
            'invalid'::TEXT,
            NULL::UUID,
            NULL::CITEXT,
            ARRAY[]::api.roles[];
        RETURN;
    END IF;

    -- El token ya fue utilizado.
    -- Posible reutilización/robo del refresh token.
    IF v_sesion.rotado_en IS NOT NULL THEN
        -- Revocar todos los refresh tokens del usuario.
        DELETE FROM api.sesiones
        WHERE id_usuario = v_sesion.id_usuario;

        -- Invalidar los access tokens emitidos anteriormente.
        UPDATE api.usuarios
        SET tokens_invalidados_desde = NOW()
        WHERE id_usuario = v_sesion.id_usuario;

        RETURN QUERY
        SELECT
            'reused'::TEXT,
            NULL::UUID,
            NULL::CITEXT,
            ARRAY[]::api.roles[];
        RETURN;
    END IF;

    -- Token expirado.
    IF v_sesion.expira_en <= NOW() THEN
        RETURN QUERY
        SELECT
            'expired'::TEXT,
            NULL::UUID,
            NULL::CITEXT,
            ARRAY[]::api.roles[];
        RETURN;
    END IF;

    -- Obtener usuario.
    SELECT *
    INTO v_usuario
    FROM api.usuarios u
    WHERE u.id_usuario = v_sesion.id_usuario;

    -- Usuario inexistente o inactivo.
    IF NOT FOUND OR NOT v_usuario.activo THEN
        RETURN QUERY
        SELECT
            'invalid'::TEXT,
            NULL::UUID,
            NULL::CITEXT,
            ARRAY[]::api.roles[];
        RETURN;
    END IF;

    -- Obtener roles.
    SELECT COALESCE(
        array_agg(ur.rol),
        ARRAY[]::api.roles[]
    )
    INTO v_roles
    FROM api.usuario_roles ur
    WHERE ur.id_usuario = v_usuario.id_usuario;

    -- Marcar el refresh token anterior como rotado.
    UPDATE api.sesiones
    SET rotado_en = NOW()
    WHERE id_sesion = v_sesion.id_sesion;

    -- Crear el nuevo refresh token.
    INSERT INTO api.sesiones (
        id_usuario,
        token_hash,
        expira_en,
        direccion_ip,
        agente_usuario
    )
    VALUES (
        v_sesion.id_usuario,
        p_new_token_hash,
        p_new_expires_at,
        p_direccion_ip,
        p_agente_usuario
    );

    -- Éxito.
    RETURN QUERY
    SELECT
        'ok'::TEXT,
        v_usuario.id_usuario,
        v_usuario.email,
        v_roles;
END;
$$;

-- Asignar rol. No reemplaza los roles existentes.
CREATE OR REPLACE FUNCTION auth.fn_asignar_rol(
    p_id_usuario_actor UUID,
    p_id_usuario_objetivo UUID,
    p_rol api.roles
)
RETURNS TEXT
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_es_admin BOOLEAN;
BEGIN
    -- El actor debe ser un administrador activo.
    SELECT EXISTS (
        SELECT 1
        FROM api.usuarios u
        JOIN api.usuario_roles ur
            ON ur.id_usuario = u.id_usuario
        WHERE u.id_usuario = p_id_usuario_actor
            AND u.activo = TRUE
            AND ur.rol = 'ADMIN'
    )
    INTO v_es_admin;

    IF NOT v_es_admin THEN
        PERFORM auth.fn_lanzar_excepcion('AU002', 'No tienes permisos para modificar roles.');
    END IF;

    -- El usuario objetivo debe existir.
    IF NOT EXISTS (
        SELECT 1
        FROM api.usuarios
        WHERE id_usuario = p_id_usuario_objetivo
    ) THEN
        PERFORM auth.fn_lanzar_excepcion('NF001', 'El usuario objetivo no existe.');
    END IF;

    -- Asignar el rol si todavía no lo tiene.
    INSERT INTO api.usuario_roles (
        id_usuario,
        rol,
        asignado_por
    )
    VALUES (
        p_id_usuario_objetivo,
        p_rol,
        p_id_usuario_actor
    )
    ON CONFLICT (id_usuario, rol) DO NOTHING;

    -- El rol ya existía.
    IF NOT FOUND THEN
        RETURN 'SIN_CAMBIOS';
    END IF;

    -- Cambio de roles: revocar sesiones y tokens ya emitidos.
    DELETE FROM api.sesiones
    WHERE id_usuario = p_id_usuario_objetivo;

    UPDATE api.usuarios
    SET tokens_invalidados_desde = NOW()
    WHERE id_usuario = p_id_usuario_objetivo;

    RETURN 'OK';
END;
$$;

-- ============================================================
-- Revoca un rol.
-- Reglas:
--   1. El actor debe ser un administrador activo.
--   2. El usuario objetivo debe existir.
--   3. El usuario debe tener el rol que se quiere revocar.
--   4. El usuario no puede quedarse sin roles.
--   5. Un administrador no puede quitarse a sí mismo el rol ADMIN.
--   6. No se puede eliminar el último ADMIN del sistema.
-- ============================================================
CREATE OR REPLACE FUNCTION auth.fn_revocar_rol(
    p_id_usuario_actor UUID,
    p_id_usuario_objetivo UUID,
    p_rol api.roles
)
RETURNS TEXT
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_es_admin BOOLEAN;
    v_cantidad_roles INTEGER;
    v_cantidad_admins INTEGER;
BEGIN
    -- 1. El actor debe ser un administrador activo.
    SELECT EXISTS (
        SELECT 1
        FROM api.usuarios u
        JOIN api.usuario_roles ur
            ON ur.id_usuario = u.id_usuario
        WHERE u.id_usuario = p_id_usuario_actor
            AND u.activo = TRUE
            AND ur.rol = 'ADMIN'
    )
    INTO v_es_admin;

    IF NOT v_es_admin THEN
        PERFORM auth.fn_lanzar_excepcion('AU002', 'No tienes permisos para modificar roles.');
    END IF;

    -- 2. El usuario objetivo debe existir.
    IF NOT EXISTS (
        SELECT 1
        FROM api.usuarios
        WHERE id_usuario = p_id_usuario_objetivo
    ) THEN
        PERFORM auth.fn_lanzar_excepcion('NF001', 'El usuario objetivo no existe.');
    END IF;

    -- 3. Comprobar que el usuario tenga el rol.
    IF NOT EXISTS (
        SELECT 1
        FROM api.usuario_roles
        WHERE id_usuario = p_id_usuario_objetivo
            AND rol = p_rol
    ) THEN
        RETURN 'SIN_CAMBIOS';
    END IF;

    -- 4. Un ADMIN no puede quitarse a sí mismo el ADMIN.
    IF p_rol = 'ADMIN'
        AND p_id_usuario_actor = p_id_usuario_objetivo THEN
        PERFORM auth.fn_lanzar_excepcion('AU003', 'Un administrador no puede quitarse a sí mismo el rol ADMIN.');
    END IF;

    -- 5. No eliminar el último ADMIN del sistema.
    IF p_rol = 'ADMIN' THEN
        SELECT COUNT(*)
        INTO v_cantidad_admins
        FROM api.usuario_roles ur
        JOIN api.usuarios u
            ON u.id_usuario = ur.id_usuario
        WHERE ur.rol = 'ADMIN'
          AND u.activo = TRUE;
        IF v_cantidad_admins <= 1 THEN
            PERFORM auth.fn_lanzar_excepcion('AU004', 'No se puede revocar el último administrador activo del sistema.');
        END IF;
    END IF;

    -- 6. Contar roles actuales del usuario.
    SELECT COUNT(*)
    INTO v_cantidad_roles
    FROM api.usuario_roles
    WHERE id_usuario = p_id_usuario_objetivo;

    -- 7. No permitir que el usuario quede sin ningún rol.
    IF v_cantidad_roles <= 1 THEN
        PERFORM auth.fn_lanzar_excepcion('AU005', 'No se puede quitar el único rol que tiene el usuario.');
    END IF;

    -- 8. Revocar el rol.
    DELETE FROM api.usuario_roles
    WHERE id_usuario = p_id_usuario_objetivo
        AND rol = p_rol;

    -- 9. Revocar sesiones y tokens existentes.
    -- TODO: esto podria ser una funcion aparte, pero por ahora lo dejamos aquí.
    DELETE FROM api.sesiones
    WHERE id_usuario = p_id_usuario_objetivo;

    UPDATE api.usuarios
    SET tokens_invalidados_desde = NOW()
    WHERE id_usuario = p_id_usuario_objetivo;

    RETURN 'OK';
END;
$$;

-- Login fallido: suma un intento; al llegar al máximo bloquea la cuenta.
CREATE OR REPLACE PROCEDURE auth.sp_registrar_login_fallido(
    p_id_usuario UUID,
    p_intentos_maximos INTEGER,
    p_minutos_bloqueo INTEGER
)
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
BEGIN
    UPDATE api.usuarios
    SET
        bloqueado_hasta =
            CASE
                WHEN intentos_fallidos_login + 1 >= p_intentos_maximos
                     AND (
                         bloqueado_hasta IS NULL
                         OR bloqueado_hasta <= NOW()
                     )
                THEN NOW() + make_interval(mins => p_minutos_bloqueo)

                ELSE bloqueado_hasta
            END,
        intentos_fallidos_login =
            CASE
                WHEN intentos_fallidos_login + 1 >= p_intentos_maximos
                     AND (
                         bloqueado_hasta IS NULL
                         OR bloqueado_hasta <= NOW()
                     )
                THEN 0

                ELSE intentos_fallidos_login + 1
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
SET search_path = academico, auth, api, public
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
SET search_path = academico, auth, api, public
AS $$
BEGIN
    INSERT INTO api.sesiones (
        id_usuario, 
        token_hash, 
        expira_en, 
        direccion_ip, 
        agente_usuario
    ) VALUES (
        p_id_usuario, 
        p_token_hash,
        p_expira_en,
        p_direccion_ip, 
        p_agente_usuario
    );
END;
$$;

-- Logout (esta sesión) y logout global (todas las sesiones)
CREATE OR REPLACE PROCEDURE auth.sp_logout(
    p_token_hash TEXT
)
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
BEGIN
    DELETE FROM api.sesiones WHERE token_hash = p_token_hash;
END;
$$;

-- Logout global (todas las sesiones)
CREATE OR REPLACE PROCEDURE auth.sp_logout_all(
    p_id_usuario UUID
)
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
BEGIN
    UPDATE api.usuarios
    SET tokens_invalidados_desde = NOW(),
        actualizado_en = NOW()
    WHERE id_usuario = p_id_usuario;

    DELETE FROM api.sesiones
    WHERE id_usuario = p_id_usuario;
END;
$$;

CREATE OR REPLACE PROCEDURE auth.sp_cambiar_contrasena(
    p_id_usuario UUID,
    p_new_password_hash TEXT
)
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
BEGIN

    IF NOT EXISTS (SELECT 1 FROM api.usuarios WHERE id_usuario = p_id_usuario) THEN
        PERFORM auth.fn_lanzar_excepcion('NF001', 'El usuario objetivo no existe.');
    END IF;

    IF p_new_password_hash IS NULL
       OR trim(p_new_password_hash) = '' THEN
        PERFORM auth.fn_lanzar_excepcion('NU002', 'La contraseña no puede estar vacía.');
    END IF;

    UPDATE api.usuarios
    SET
        password_hash = p_new_password_hash,
        password_cambiada_en = NOW(),
        intentos_fallidos_login = 0,
        bloqueado_hasta = NULL,
        tokens_invalidados_desde = NOW(),
        actualizado_en = NOW()
    WHERE id_usuario = p_id_usuario;

    DELETE FROM api.sesiones
    WHERE id_usuario = p_id_usuario;
END;
$$;

-- Elimina las sesiones (refresh tokens) ya expiradas. La corre SessionCleanupService cada 24hs.
CREATE OR REPLACE PROCEDURE auth.sp_purgar_sesiones_expiradas()
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
BEGIN
    DELETE FROM api.sesiones
    WHERE expira_en <= NOW();
END;
$$;