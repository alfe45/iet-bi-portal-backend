-- ============================================================
-- VIEWS
-- ============================================================

-- Usuarios con sus roles y numero de sesiones
CREATE OR REPLACE VIEW api.vw_usuarios AS
SELECT
    u.id_usuario,
    u.email,
    u.activo,
    u.bloqueado_hasta,
    COALESCE(array_agg(ur.rol) FILTER (WHERE ur.rol IS NOT NULL), ARRAY[]::api.roles[]) AS roles,
    COUNT(s.id_sesion) AS cantidad_sesiones
FROM api.usuarios u
LEFT JOIN api.usuario_roles ur ON ur.id_usuario = u.id_usuario
LEFT JOIN api.sesiones s ON s.id_usuario = u.id_usuario
GROUP BY u.id_usuario, u.email, u.activo, u.bloqueado_hasta;

-- Ver los logs y usuarios relacionados
CREATE OR REPLACE VIEW api.vw_logs AS
SELECT 
    l.id_log, l.id_usuario, u.email, l.accion, 
    l.tabla_afectada, l.id_registro_afectado,
    l.datos_anteriores, l.datos_nuevos, l.direccion_ip, l.agente_usuario,
    l.creado_en
FROM api.logs l
LEFT JOIN api.usuarios u ON l.id_usuario = u.id_usuario
ORDER BY l.creado_en DESC;

-- Sesiones con sus usuarios
CREATE OR REPLACE VIEW api.vw_sesiones AS
SELECT s.id_usuario, u.email, s.creado_en, s.expira_en, s.rotado_en, s.direccion_ip, s.agente_usuario
FROM api.sesiones s
JOIN api.usuarios u ON u.id_usuario = s.id_usuario
ORDER BY s.creado_en DESC;

SELECT * FROM api.vw_usuarios;
SELECT * FROM api.vw_logs;
SELECT * FROM api.vw_sesiones;