-- ============================================================
-- 03_auth.sql: TABLAS Y FUNCIONES DE AUTENTICACIÓN
-- (la administración de usuarios/roles vive en 05_admin_usuarios.sql)
-- ============================================================
SET search_path = academico, api, auth, public;

-- ============================================================
-- TABLAS
-- ============================================================
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

-- Una sola fila posible (id = 1). Si se borra el primer admin, la fila se conserva
-- (id_usuario pasa a NULL) y el bootstrap sigue bloqueado.
CREATE TABLE api.bootstrap_admin (
    id_bootstrap INTEGER PRIMARY KEY,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    id_usuario UUID NULL,
    CONSTRAINT ck_bootstrap_admin_unico CHECK (id_bootstrap = 1),
    CONSTRAINT fk_bootstrap_admin_usuario FOREIGN KEY (id_usuario) REFERENCES api.usuarios (id_usuario) ON DELETE SET NULL
);

-- ============================================================
-- INSERCIÓN DE USUARIOS (interna; la usan bootstrap y CU02)
-- Valida correo/contraseña, crea el usuario y su rol inicial.
-- ============================================================
CREATE OR REPLACE FUNCTION auth.fn_insertar_usuario(
    p_email CITEXT,
    p_password_hash TEXT,
    p_rol api.roles,
    p_asignado_por UUID
)
RETURNS UUID
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_email CITEXT := api.fn_limpiar(p_email::TEXT)::CITEXT;
    v_id UUID;
BEGIN
    IF v_email IS NULL THEN
        PERFORM api.fn_lanzar_excepcion('NU001', 'El correo no puede estar vacío.');
    END IF;

    IF api.fn_limpiar(p_password_hash) IS NULL THEN
        PERFORM api.fn_lanzar_excepcion('NU002', 'La contraseña no puede estar vacía.');
    END IF;

    IF EXISTS (SELECT 1 FROM api.usuarios WHERE email = v_email) THEN
        PERFORM api.fn_lanzar_excepcion('TA001', 'El correo ya está en uso.');
    END IF;

    INSERT INTO api.usuarios (email, password_hash)
    VALUES (v_email, p_password_hash)
    RETURNING id_usuario INTO v_id;

    INSERT INTO api.usuario_roles (id_usuario, rol, asignado_por)
    VALUES (v_id, p_rol, p_asignado_por);

    RETURN v_id;
END;
$$;

-- ============================================================
-- BOOTSTRAP: primer administrador (una sola vez, serializado con advisory lock)
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
    v_id UUID;
BEGIN
    PERFORM pg_advisory_xact_lock(hashtextextended('api.bootstrap_admin', 0));

    IF EXISTS (SELECT 1 FROM api.bootstrap_admin) THEN
        PERFORM api.fn_lanzar_excepcion('AU001', 'El administrador inicial ya fue creado.');
    END IF;

    v_id := auth.fn_insertar_usuario(p_email, p_password_hash, 'ADMIN', NULL);

    INSERT INTO api.bootstrap_admin (id_bootstrap, id_usuario) VALUES (1, v_id);

    RETURN v_id;
END;
$$;

-- ============================================================
-- LOGIN
-- ============================================================
CREATE OR REPLACE FUNCTION auth.fn_obtener_usuario_por_email(p_email CITEXT)
RETURNS TABLE(
    id_usuario UUID,
    email CITEXT,
    password_hash TEXT,
    activo BOOLEAN,
    bloqueado_hasta TIMESTAMPTZ,
    roles api.roles[]
)
LANGUAGE sql STABLE
SET search_path = academico, auth, api, public
AS $$
    SELECT u.id_usuario, u.email, u.password_hash, u.activo, u.bloqueado_hasta,
           api.fn_roles_de(u.id_usuario)
    FROM api.usuarios u
    WHERE u.email = api.fn_limpiar(p_email::TEXT)::CITEXT;
$$;

CREATE OR REPLACE FUNCTION auth.fn_obtener_usuario_por_id(p_id_usuario UUID)
RETURNS TABLE(
    id_usuario UUID,
    email CITEXT,
    password_hash TEXT,
    activo BOOLEAN,
    bloqueado_hasta TIMESTAMPTZ,
    roles api.roles[]
)
LANGUAGE sql STABLE
SET search_path = academico, auth, api, public
AS $$
    SELECT u.id_usuario, u.email, u.password_hash, u.activo, u.bloqueado_hasta,
           api.fn_roles_de(u.id_usuario)
    FROM api.usuarios u
    WHERE u.id_usuario = p_id_usuario;
$$;

-- Login fallido: suma un intento; al llegar al máximo bloquea la cuenta.
-- Devuelve TRUE si este intento bloqueó la cuenta (para auditoría).
CREATE OR REPLACE FUNCTION auth.fn_registrar_login_fallido(
    p_id_usuario UUID,
    p_intentos_maximos INTEGER,
    p_minutos_bloqueo INTEGER
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_bloquear BOOLEAN;
BEGIN
    SELECT u.intentos_fallidos_login + 1 >= p_intentos_maximos
           AND (u.bloqueado_hasta IS NULL OR u.bloqueado_hasta <= NOW())
    INTO v_bloquear
    FROM api.usuarios u
    WHERE u.id_usuario = p_id_usuario
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN FALSE;
    END IF;

    UPDATE api.usuarios
    SET
        bloqueado_hasta = CASE WHEN v_bloquear THEN NOW() + make_interval(mins => p_minutos_bloqueo) ELSE bloqueado_hasta END,
        intentos_fallidos_login = CASE WHEN v_bloquear THEN 0 ELSE intentos_fallidos_login + 1 END,
        actualizado_en = NOW()
    WHERE id_usuario = p_id_usuario;

    RETURN v_bloquear;
END;
$$;

CREATE OR REPLACE PROCEDURE auth.sp_registrar_login_exitoso(p_id_usuario UUID)
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
BEGIN
    UPDATE api.usuarios
    SET intentos_fallidos_login = 0,
        bloqueado_hasta = NULL,
        ultimo_login = NOW(),
        actualizado_en = NOW()
    WHERE id_usuario = p_id_usuario;
END;
$$;

-- ============================================================
-- SESIONES (refresh tokens hasheados, con rotación)
-- ============================================================
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
    INSERT INTO api.sesiones (id_usuario, token_hash, expira_en, direccion_ip, agente_usuario)
    VALUES (p_id_usuario, p_token_hash, p_expira_en, p_direccion_ip, p_agente_usuario);
END;
$$;

-- out_status: 'ok' | 'invalid' (no existe / usuario inactivo) | 'expired' |
--             'reused' (token ya rotado => robo: se revoca todo el acceso del usuario).
-- En 'reused' la función NO lanza excepción: así el revocado se confirma (commit).
CREATE OR REPLACE FUNCTION auth.fn_rotar_sesion(
    p_old_token_hash TEXT,
    p_new_token_hash TEXT,
    p_new_expires_at TIMESTAMPTZ,
    p_direccion_ip TEXT,
    p_agente_usuario TEXT
)
RETURNS TABLE(out_status TEXT, out_user_id UUID, out_email CITEXT, out_roles api.roles[])
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_sesion api.sesiones%ROWTYPE;
    v_usuario api.usuarios%ROWTYPE;
BEGIN
    SELECT * INTO v_sesion
    FROM api.sesiones s
    WHERE s.token_hash = p_old_token_hash
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN QUERY SELECT 'invalid'::TEXT, NULL::UUID, NULL::CITEXT, NULL::api.roles[];
        RETURN;
    END IF;

    -- Reutilización de un token ya rotado (posible robo): se revoca todo y se devuelve el dueño
    -- para auditarlo (sin email ni roles: no se emite sesión).
    IF v_sesion.rotado_en IS NOT NULL THEN
        CALL api.sp_revocar_acceso(v_sesion.id_usuario);
        RETURN QUERY SELECT 'reused'::TEXT, v_sesion.id_usuario, NULL::CITEXT, NULL::api.roles[];
        RETURN;
    END IF;

    IF v_sesion.expira_en <= NOW() THEN
        RETURN QUERY SELECT 'expired'::TEXT, NULL::UUID, NULL::CITEXT, NULL::api.roles[];
        RETURN;
    END IF;

    SELECT * INTO v_usuario
    FROM api.usuarios u
    WHERE u.id_usuario = v_sesion.id_usuario;

    IF NOT FOUND OR NOT v_usuario.activo THEN
        RETURN QUERY SELECT 'invalid'::TEXT, NULL::UUID, NULL::CITEXT, NULL::api.roles[];
        RETURN;
    END IF;

    UPDATE api.sesiones SET rotado_en = NOW() WHERE id_sesion = v_sesion.id_sesion;

    INSERT INTO api.sesiones (id_usuario, token_hash, expira_en, direccion_ip, agente_usuario)
    VALUES (v_sesion.id_usuario, p_new_token_hash, p_new_expires_at, p_direccion_ip, p_agente_usuario);

    RETURN QUERY SELECT 'ok'::TEXT, v_usuario.id_usuario, v_usuario.email, api.fn_roles_de(v_usuario.id_usuario);
END;
$$;

-- Logout de esta sesión. Devuelve el id del dueño, o NULL si el token no existía.
CREATE OR REPLACE FUNCTION auth.fn_logout(p_token_hash TEXT)
RETURNS UUID
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_id_usuario UUID;
BEGIN
    DELETE FROM api.sesiones
    WHERE token_hash = p_token_hash
    RETURNING id_usuario INTO v_id_usuario;

    RETURN v_id_usuario;
END;
$$;

CREATE OR REPLACE PROCEDURE auth.sp_logout_all(p_id_usuario UUID)
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
BEGIN
    CALL api.sp_revocar_acceso(p_id_usuario);
END;
$$;

-- Establece una contraseña nueva (ya hasheada), desbloquea y revoca el acceso.
-- La usan el cambio de contraseña propio y el reseteo por un admin.
CREATE OR REPLACE PROCEDURE auth.sp_establecer_contrasena(
    p_id_usuario UUID,
    p_password_hash TEXT
)
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM api.usuarios WHERE id_usuario = p_id_usuario) THEN
        PERFORM api.fn_lanzar_excepcion('NF001', 'El usuario no existe.');
    END IF;

    IF api.fn_limpiar(p_password_hash) IS NULL THEN
        PERFORM api.fn_lanzar_excepcion('NU002', 'La contraseña no puede estar vacía.');
    END IF;

    UPDATE api.usuarios
    SET password_hash = p_password_hash,
        password_cambiada_en = NOW(),
        intentos_fallidos_login = 0,
        bloqueado_hasta = NULL
    WHERE id_usuario = p_id_usuario;

    CALL api.sp_revocar_acceso(p_id_usuario);
END;
$$;

CREATE OR REPLACE PROCEDURE auth.sp_purgar_sesiones_expiradas()
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
BEGIN
    DELETE FROM api.sesiones WHERE expira_en <= NOW();
END;
$$;

-- ============================================================
-- REVOCACIÓN DE ACCESS TOKENS (la usa el middleware JWT en cada request)
-- 0 filas  => el usuario no existe (rechazar el token).
-- 1 fila   => existe; el valor es tokens_invalidados_desde (NULL si nunca se invalidó nada).
-- ============================================================
CREATE OR REPLACE FUNCTION auth.fn_obtener_marca_invalidacion(p_id_usuario UUID)
RETURNS SETOF TIMESTAMPTZ
LANGUAGE sql STABLE
SET search_path = academico, auth, api, public
AS $$
    SELECT u.tokens_invalidados_desde
    FROM api.usuarios u
    WHERE u.id_usuario = p_id_usuario;
$$;
