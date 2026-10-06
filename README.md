# iet-bi-portal-backend
## Despliegue

- **API**: Render, servicio `iet-bi-portal-api` (Docker, plan free) → https://iet-bi-portal-api.onrender.com. Cada push a `develop` la compila y redespliega sola; si el build o el arranque fallan, sigue atendiendo la versión anterior. La configuración está en `render.yaml` (sirve para recrear el servicio; aplicarlo con el actual lo duplica).
- **Base de datos**: Neon, proyecto `iet-bi-portal`, base `ietbi` (PostgreSQL 18, N. Virginia). La API se conecta con la cuenta `svc_api` (permisos mínimos); el dueño `ietbi_owner` solo se usa para ejecutar los scripts.

### Cambios de SQL (no se despliegan solos)
Render solo despliega el código C#. Si un cambio necesita SQL nuevo:
1. Ejecutar el script en Neon **antes** del merge a `develop` (si no, el endpoint dará 500).
2. Reiniciar la API en Render (Manual Deploy → Restart): Npgsql guarda en caché los tipos de la base.

Los scripts `01..19` recrean los esquemas desde cero (`DROP SCHEMA ... CASCADE`): **borran todos los datos** de una base compartida. Para cambiar una función basta ejecutar su archivo, revisando que no haga `DROP` de tablas.

### Recrear la base desde cero
Con la cadena de conexión del dueño (consola de Neon → Connect, endpoint **sin** `-pooler`):
```bash
for f in Resources/sql/[01][0-9]_*.sql; do psql "$NEON_OWNER_URL" -v ON_ERROR_STOP=1 -f "$f" || break; done
```
`01_roles_schemas.sql` crea las cuentas `svc_api` y `svc_admin` (desactivable con `PGOPTIONS="-c ietbi.crear_roles=off"`). Sus contraseñas se ponen aparte y nunca van al repo:
```sql
ALTER ROLE svc_api PASSWORD '...';
ALTER ROLE svc_admin PASSWORD '...';
```
Después: actualizar `DB_PASSWORD` en Render si cambió, reiniciar la API y crear el primer administrador con `POST /api/setup/primer-admin` (token `ADMIN_BOOTSTRAP_TOKEN`, en Environment del servicio).

### Variables en Render
`DB_HOST` (endpoint directo de Neon), `DB_USER=svc_api`, `DB_PASSWORD`, `CORS_ORIGINS` (separados por comas y sin barra final; incluir `http://localhost:4200` para el frontend local) y `CONFIAR_PROXY=true`. El resto está en `render.yaml`.

Plan free: la API se duerme tras 15 min sin tráfico (la primera petición tarda ~1 min) y Neon suspende la base sin uso (la primera conexión tarda ~1 s).
