# iet-bi-portal-backend
## Despliegue en Render

`render.yaml` define la API (Docker, plan free) y una base PostgreSQL administrada. Cada push a `develop` redespliega la API.

1. Abrir https://dashboard.render.com/blueprint/new?repo=https://github.com/alfe45/iet-bi-portal-backend, rama `develop`, y aplicar el Blueprint.
2. Llenar `CORS_ORIGINS` con la URL del frontend (separadas por comas). `JWT_KEY` y `ADMIN_BOOTSTRAP_TOKEN` se generan solos (ver su valor en Environment).
3. Cargar la base una sola vez (borra todo lo que haya): copiar la *External Database URL* de la base en Render y ejecutar los scripts en orden:
   ```bash
   for f in Resources/sql/[01][0-9]_*.sql; do psql "$RENDER_DB_URL" -v ON_ERROR_STOP=1 -f "$f" || break; done
   ```
   Después reiniciar la API en Render (Manual Deploy → Restart) por la caché de tipos de Npgsql.
4. Crear el primer administrador con `POST /api/setup/primer-admin` usando `ADMIN_BOOTSTRAP_TOKEN`.

Notas del plan free: la API se duerme tras 15 min sin tráfico (la primera petición tarda ~1 min) y la base free expira a los 30 días.
