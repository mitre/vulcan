# Multi-Project Port Registry

When running multiple MITRE projects simultaneously, assign unique ports to avoid conflicts.

## Default Behavior

Every project defaults to PostgreSQL on port 5432 and the app on port 3000. This works out of the box for single-project development. Only set custom ports if you run multiple projects at once.

## Port Assignments

| Project | PORT (app) | DATABASE_PORT | Notes |
|---|---|---|---|
| vulcan-v2.x | 3000 | 5435 | |
| vulcan-v3.x | 3001 | 5436 | |
| vulcan-enterprise | 3002 | 5434 | already using 5434 |
| heimdall2 | 3010 | 5438 | |
| heimdall-clean | 3011 | 5439 | |
| memcord | -- | 5433 | already using 5433 |
| k8s helm testing | -- | 5440+ | via kubectl port-forward |

## Setup

Each project uses the same pattern: env vars with standard defaults.

1. Copy `.env.example` to `.env`
2. Set `DATABASE_PORT` and `POSTGRES_PORT` to the same value from the table above
3. Set `PORT` for the app server
4. `docker compose up db -d`
5. `bin/rails db:prepare` (or equivalent)

### Example `.env` (vulcan-v2.x)

```bash
DATABASE_PORT=5435
DATABASE_HOST=127.0.0.1
DATABASE_GSSENCMODE=disable
POSTGRES_PORT=5435
PORT=3000
DB_SUFFIX=_v2
```

## Environment Variable Naming Convention

All MITRE projects follow `UPPERCASE_WITH_UNDERSCORES` using full descriptive words:

| Variable | Used By | Purpose |
|---|---|---|
| `DATABASE_PORT` | `database.yml` | PostgreSQL client connection port |
| `DATABASE_HOST` | `database.yml` | PostgreSQL host (default: 127.0.0.1) |
| `DATABASE_GSSENCMODE` | `database.yml` | GSSAPI encryption mode (set to `disable` on macOS with Kerberos) |
| `DATABASE_URL` | `database.yml` | Full connection string (12-factor, takes precedence in production) |
| `POSTGRES_PORT` | `docker-compose.yml` | Docker host-side port mapping (must match DATABASE_PORT) |
| `POSTGRES_USER` | `docker-compose.yml` | Docker PostgreSQL init: username to create |
| `POSTGRES_PASSWORD` | `docker-compose.yml` | Docker PostgreSQL init: password to set |
| `POSTGRES_DB` | `docker-compose.yml` | Docker PostgreSQL init: database to create |
| `PORT` | `Procfile.dev` | App server (Puma/Rails) listen port |
| `DB_SUFFIX` | `database.yml` | Worktree isolation suffix (e.g., `_v2`) |

**Why two port variables?** `DATABASE_PORT` is what Rails uses to connect. `POSTGRES_PORT` is what Docker uses to map the container's internal port 5432 to the host. Set both to the same value in `.env`.

**Why not `PG*` shorthand?** PostgreSQL's libpq defines `PGPORT`, `PGHOST`, etc. but our project convention uses full descriptive words with underscores (`DATABASE_PORT`, `VULCAN_ENABLE_OIDC`, etc.) for consistency and readability across all MITRE projects.

## OrbStack / k8s Note

OrbStack's built-in Kubernetes can shadow port 5432 on the host. If `docker logs` shows no incoming connections but Rails reports connection errors, another PostgreSQL is intercepting traffic. Assign a different port.
