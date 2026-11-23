# Multi-Project Port Registry

When running multiple MITRE projects simultaneously, assign unique ports to avoid conflicts.

## Default Behavior

`config/database.yml` defaults to port 5432 and Puma to 3000, so a local
PostgreSQL install needs no port configuration at all.

The dev Docker database is the exception: `docker-compose.dev.yml` publishes
`${POSTGRES_PORT:-5435}:5432`, so it lands on host port **5435** while Rails
still looks for 5432. Using that container therefore requires
`DATABASE_PORT=5435` in `.env` — which is why Vulcan's row below reads 5435.

## Port Assignments

| Project | PORT (app) | DATABASE_PORT |
|---|---|---|
| Vulcan | 3000 | 5435 |

If you run other MITRE projects alongside Vulcan, assign them different ports in their own `.env` files to avoid conflicts.

## Setup

Each project uses the same pattern: env vars with standard defaults.

1. Copy `.env.example` to `.env`
2. Set `DATABASE_PORT` and `POSTGRES_PORT` to the same value from the table above
3. Set `PORT` for the app server
4. `docker compose up db -d`
5. `bin/rails db:prepare` (or equivalent)

### Example `.env` (Vulcan)

```bash
DATABASE_PORT=5435
DATABASE_HOST=127.0.0.1
DATABASE_GSSENCMODE=disable
POSTGRES_PORT=5435
PORT=3000
```

## Environment Variable Naming Convention

All MITRE projects follow `UPPERCASE_WITH_UNDERSCORES` using full descriptive words:

| Variable | Used By | Purpose |
|---|---|---|
| `DATABASE_PORT` | `database.yml` | PostgreSQL client connection port |
| `DATABASE_HOST` | `database.yml` | PostgreSQL host (default: 127.0.0.1) |
| `DATABASE_GSSENCMODE` | `database.yml` | GSSAPI encryption mode (set to `disable` on macOS with Kerberos) |
| `DATABASE_URL` | `database.yml` | Full connection string (12-factor, takes precedence in production) |
| `POSTGRES_PORT` | `docker-compose.dev.yml` | Host-side port mapping for the dev database, default 5435 (must match DATABASE_PORT) |
| `POSTGRES_USER` | `docker-compose.yml` | Docker PostgreSQL init: username to create |
| `POSTGRES_PASSWORD` | `docker-compose.yml` | Docker PostgreSQL init: password to set |
| `POSTGRES_DB` | `docker-compose.yml` | Docker PostgreSQL init: database to create |
| `PORT` | `bin/dev`, `config/puma.rb` | App server listen port. `bin/dev` walks upward from it if the port is taken |
| `DATABASE_NAME` | `database.yml` | Override default database name |
| `VULCAN_PORT` | `docker-compose.yml`, `docker-compose.dev.yml` | Host-side port mapping for the web container |

**Why two port variables?** `DATABASE_PORT` is what Rails uses to connect. `POSTGRES_PORT` is what Docker uses to map the container's internal port 5432 to the host. Set both to the same value in `.env`.

**Why not `PG*` shorthand?** PostgreSQL's libpq defines `PGPORT`, `PGHOST`, etc. but our project convention uses full descriptive words with underscores (`DATABASE_PORT`, `VULCAN_ENABLE_OIDC`, etc.) for consistency and readability across all MITRE projects.

## OrbStack / k8s Note

OrbStack's built-in Kubernetes can shadow port 5432 on the host. If `docker logs` shows no incoming connections but Rails reports connection errors, another PostgreSQL is intercepting traffic. Assign a different port.
