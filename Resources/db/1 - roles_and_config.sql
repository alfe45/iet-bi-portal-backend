-- name=roles_and_config.sql
-- Roles, esquemas y extensiones. Incluye cuentas de conexión LOGIN
-- y configuraciones de search_path necesarias para que los procedimientos
-- SECURITY DEFINER funcionen de forma segura.
-- Ejecutar primero: crea esquemas, extensiones y roles técnicos.

BEGIN;

-- 1) Crear roles de aplicación (NOLOGIN) y cuentas de servicio (LOGIN)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'bi_admin') THEN
        CREATE ROLE bi_admin NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'bi_profesor') THEN
        CREATE ROLE bi_profesor NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'bi_guia') THEN
        CREATE ROLE bi_guia NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'bi_coord_monografia') THEN
        CREATE ROLE bi_coord_monografia NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'bi_estudiante') THEN
        CREATE ROLE bi_estudiante NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'bi_api') THEN
        CREATE ROLE bi_api NOLOGIN;
    END IF;
END;
$$;

-- Herencia técnica entre roles (GUIA y COORD_MONOGRAFIA heredan de PROFESOR)
GRANT bi_profesor TO bi_guia;
GRANT bi_profesor TO bi_coord_monografia;

-- Crear cuentas LOGIN por portal (cuentas de conexión de la aplicación).
-- NOTA: las contraseñas de ejemplo deben rotarse en despliegue.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'svc_admin_portal') THEN
        CREATE ROLE svc_admin_portal LOGIN PASSWORD 'admin1234';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'svc_profesor_portal') THEN
        CREATE ROLE svc_profesor_portal LOGIN PASSWORD 'profesor1234';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'svc_estudiante_portal') THEN
        CREATE ROLE svc_estudiante_portal LOGIN PASSWORD 'estudiante1234';
    END IF;
END;
$$;

GRANT bi_admin TO svc_admin_portal;
GRANT bi_profesor TO svc_profesor_portal;
GRANT bi_estudiante TO svc_estudiante_portal;

COMMENT ON ROLE svc_admin_portal IS 'Cuenta de conexión del backoffice/registro académico. Miembro de bi_admin.';
COMMENT ON ROLE svc_profesor_portal IS 'Cuenta de conexión del portal docente. Miembro de bi_profesor.';
COMMENT ON ROLE svc_estudiante_portal IS 'Cuenta de conexión del portal estudiantil. Miembro de bi_estudiante.';

-- 2) Crear esquemas sin borrar datos u objetos existentes.
CREATE SCHEMA IF NOT EXISTS academico;
CREATE SCHEMA IF NOT EXISTS api;

-- 3) Crear extensiones dentro del esquema "academico"
-- Razonamiento: todos los procedimientos SECURITY DEFINER usan
-- SET search_path = pg_catalog, academico, api (sin public).
-- Si las extensiones quedan en public las funciones fallarán en runtime.
CREATE EXTENSION IF NOT EXISTS citext SCHEMA academico;
CREATE EXTENSION IF NOT EXISTS pgcrypto SCHEMA academico;
CREATE EXTENSION IF NOT EXISTS btree_gist SCHEMA academico;

-- 4) Ajuste temporal del search_path para la instalación
-- (esto facilita la definición de columnas que usan CITEXT sin calificar)
SET search_path = academico, public, pg_catalog;

-- 5) Revocar accesos públicos por seguridad
REVOKE ALL ON SCHEMA academico FROM PUBLIC;
REVOKE ALL ON SCHEMA api FROM PUBLIC;

GRANT USAGE ON SCHEMA api TO bi_api, bi_admin, bi_profesor, bi_guia,
    bi_coord_monografia, bi_estudiante;
GRANT USAGE ON SCHEMA academico TO bi_api, bi_admin, bi_profesor, bi_guia,
    bi_coord_monografia, bi_estudiante;

-- Las rutinas se conceden explícitamente en procedures.sql; no heredar
-- EXECUTE a PUBLIC ni a objetos creados posteriormente.
ALTER DEFAULT PRIVILEGES IN SCHEMA api REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;

COMMIT;