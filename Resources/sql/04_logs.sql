SET search_path = academico, api, auth, public;

-- ============================================================
-- TABLAS
-- ============================================================
-- LOGS
CREATE TABLE api.logs (
    id_log UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_usuario UUID NULL,                    -- quién lo hizo (NULL = sistema/background)
    accion TEXT NOT NULL,                     -- 'LOGIN', 'ASIGNAR_ROL', etc. (catálogo en Modules/Logs/log_codes.md)
    tabla_afectada TEXT NULL,                 -- 'api.usuario_roles', si aplica
    id_registro_afectado TEXT NULL,           -- PK de la fila afectada, como texto
    datos_anteriores JSONB NULL,              -- estado previo (UPDATE/DELETE)
    datos_nuevos JSONB NULL,                  -- estado nuevo (INSERT/UPDATE)
    direccion_ip TEXT NULL,
    agente_usuario TEXT NULL,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_logs_usuario FOREIGN KEY (id_usuario) REFERENCES api.usuarios (id_usuario) ON DELETE SET NULL,
    CONSTRAINT ck_logs_accion_not_empty CHECK (trim(accion) <> '')
);

CREATE INDEX ix_logs_usuario ON api.logs (id_usuario);
CREATE INDEX ix_logs_creado_en ON api.logs (creado_en DESC);
CREATE INDEX ix_logs_accion ON api.logs (accion);

-- ============================================================
-- FUNCIONES DE LOGS
-- ============================================================
CREATE OR REPLACE FUNCTION api.fn_registrar_log(
    p_id_usuario UUID,
    p_accion TEXT,
    p_tabla_afectada TEXT DEFAULT NULL,
    p_id_registro_afectado TEXT DEFAULT NULL,
    p_datos_anteriores JSONB DEFAULT NULL,
    p_datos_nuevos JSONB DEFAULT NULL,
    p_direccion_ip TEXT DEFAULT NULL,
    p_agente_usuario TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SET search_path = academico, auth, api, public
AS $$
DECLARE
    v_id_log UUID;
BEGIN
    INSERT INTO api.logs (
        id_usuario, accion, tabla_afectada, id_registro_afectado,
        datos_anteriores, datos_nuevos, direccion_ip, agente_usuario
    )
    VALUES (
        p_id_usuario, upper(trim(p_accion)), p_tabla_afectada, p_id_registro_afectado,
        p_datos_anteriores, p_datos_nuevos, p_direccion_ip, p_agente_usuario
    )
    RETURNING id_log INTO v_id_log;

    RETURN v_id_log;
END;
$$;