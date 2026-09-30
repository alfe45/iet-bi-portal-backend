-- ============================================================
-- ROLES, ESQUEMAS Y PERMISOS INICIALES
-- Para el server de la UCR ejecutar solo el primer bloque de codigo, para localhost ejecutar todo el script (quitar el FALSE).
-- ============================================================
BEGIN;
    -- ============================================================
    -- 1. CREAR ESQUEMAS
    -- ============================================================
    DROP SCHEMA IF EXISTS academico CASCADE;
    DROP SCHEMA IF EXISTS api CASCADE;
    DROP SCHEMA IF EXISTS auth CASCADE;

    CREATE SCHEMA academico;
    CREATE SCHEMA api;
    CREATE SCHEMA auth;

    -- ============================================================
    -- 2. EXTENSIONES
    -- ============================================================
    CREATE EXTENSION IF NOT EXISTS citext SCHEMA academico;
    CREATE EXTENSION IF NOT EXISTS pgcrypto SCHEMA academico;
    CREATE EXTENSION IF NOT EXISTS btree_gist SCHEMA academico;
    CREATE EXTENSION IF NOT EXISTS unaccent SCHEMA academico;   -- búsquedas sin acentos (api.fn_coincide)

    -- ============================================================
    -- 3. SEARCH PATH DE INSTALACIÓN
    -- ============================================================
    SET search_path = academico, auth, api, public, pg_catalog;
COMMIT;

BEGIN;
-- ============================================================
-- 3. CREAR ROLES
-- ============================================================
DO $$
BEGIN
    IF (FALSE) THEN
        -- Rol de administración
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'bi_admin') THEN
            CREATE ROLE bi_admin NOLOGIN;
        END IF;

        -- Rol utilizado por el API
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'bi_api') THEN
            CREATE ROLE bi_api NOLOGIN;
        END IF;

        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'svc_admin') THEN
            CREATE ROLE svc_admin LOGIN PASSWORD '1234';
        END IF;

        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'svc_api') THEN
            CREATE ROLE svc_api LOGIN PASSWORD '1234';
        END IF;

        -- Herencia de permisos
        GRANT bi_admin TO svc_admin;
        GRANT bi_api TO svc_api;

        -- Descripciones
        COMMENT ON ROLE svc_admin IS 'Cuenta de conexión del backoffice/administración.';
        COMMENT ON ROLE svc_api IS 'Cuenta de conexión utilizada por el API.';

        -- ============================================================
        -- 4. SEGURIDAD DE LOS ESQUEMAS
        -- ============================================================
        REVOKE ALL ON SCHEMA academico FROM PUBLIC;
        REVOKE ALL ON SCHEMA api FROM PUBLIC;
        REVOKE ALL ON SCHEMA auth FROM PUBLIC;

        -- ============================================================
        -- 5. ACCESO A LOS ESQUEMAS PARA EL API
        -- ============================================================
        GRANT USAGE ON SCHEMA academico TO bi_api;
        GRANT USAGE ON SCHEMA api TO bi_api;
        GRANT USAGE ON SCHEMA auth TO bi_api;

        -- ============================================================
        -- 6. PERMISOS SOBRE ACADEMICO
        -- ============================================================
        GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA academico TO bi_api;
        GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA academico TO bi_api;
        GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA academico TO bi_api;
        GRANT EXECUTE ON ALL PROCEDURES IN SCHEMA academico TO bi_api;

        -- ============================================================
        -- 7. PERMISOS SOBRE API
        -- ============================================================
        GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA api TO bi_api;
        GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA api TO bi_api;
        GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA api TO bi_api;
        GRANT EXECUTE ON ALL PROCEDURES IN SCHEMA api TO bi_api;

        -- ============================================================
        -- 8. PERMISOS SOBRE AUTH
        -- ============================================================
        GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA auth TO bi_api;
        GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA auth TO bi_api;
        GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA auth TO bi_api;
        GRANT EXECUTE ON ALL PROCEDURES IN SCHEMA auth TO bi_api;

        -- ============================================================
        -- 9. PRIVILEGIOS POR DEFECTO
        -- ============================================================
        -- ACADEMICO
        ALTER DEFAULT PRIVILEGES IN SCHEMA academico GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO bi_api;
        ALTER DEFAULT PRIVILEGES IN SCHEMA academico GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO bi_api;
        ALTER DEFAULT PRIVILEGES IN SCHEMA academico GRANT EXECUTE ON FUNCTIONS TO bi_api;

        -- API
        ALTER DEFAULT PRIVILEGES IN SCHEMA api GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO bi_api;
        ALTER DEFAULT PRIVILEGES IN SCHEMA api GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO bi_api;
        ALTER DEFAULT PRIVILEGES IN SCHEMA api GRANT EXECUTE ON FUNCTIONS TO bi_api;

        -- AUTH
        ALTER DEFAULT PRIVILEGES IN SCHEMA auth GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO bi_api;
        ALTER DEFAULT PRIVILEGES IN SCHEMA auth GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO bi_api;
        ALTER DEFAULT PRIVILEGES IN SCHEMA auth GRANT EXECUTE ON FUNCTIONS TO bi_api;

        -- ============================================================
        -- 10. EVITAR EJECUCIÓN DE FUNCIONES POR PUBLIC
        -- ============================================================
        ALTER DEFAULT PRIVILEGES IN SCHEMA academico REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
        ALTER DEFAULT PRIVILEGES IN SCHEMA api REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
        ALTER DEFAULT PRIVILEGES IN SCHEMA auth REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
    END IF;
END;
$$;
COMMIT;



