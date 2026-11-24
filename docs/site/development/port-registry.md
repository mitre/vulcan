# Multi-Project Port Registry

When running multiple MITRE projects simultaneously, assign unique ports to avoid conflicts.

## Default Behavior

`DATABASE_PORT` is the only database port setting. `config/database.yml`
connects to it and `docker-compose.dev.yml` publishes the dev container on it,
so the two can never disagree. It defaults to 5432 and Puma's `PORT` defaults
to 3000, which means a single-project checkout — local PostgreSQL *or* the dev
container — needs no port configuration at all.

Set `DATABASE_PORT` only when 5432 is already taken, either by another
project's database or by a PostgreSQL you installed on the host.

## Port Assignments

| Project | PORT (app) | DATABASE_PORT |
|---|---|---|
| Vulcan | 3000 | 5435 |

Vulcan's assignment is 5435 for developers running several MITRE projects at
once; a single-project checkout can leave it unset and use the 5432 default.
If you run other MITRE projects alongside Vulcan, assign them different ports in their own `.env` files to avoid conflicts.

## Setup

Each project uses the same pattern: env vars with standard defaults.

1. Copy `.env.example` to `.env`
2. Set `DATABASE_PORT` from the table above (only needed when sharing the host)
3. Set `PORT` for the app server
4. `docker compose -f docker-compose.dev.yml up db -d`
5. `bin/rails db:prepare` (or equivalent)

### Example `.env` (Vulcan, running alongside other projects)

```bash
DATABASE_PORT=5435
DATABASE_HOST=127.0.0.1
DATABASE_GSSENCMODE=disable
PORT=3000
```

## Environment Variable Naming Convention

All MITRE projects follow `UPPERCASE_WITH_UNDERSCORES` using full descriptive words:

| Variable | Used By | Purpose |
|---|---|---|
| `DATABASE_PORT` | `database.yml`, `docker-compose.dev.yml` | PostgreSQL port: the port Rails connects to, and the host port the dev container publishes |
| `DATABASE_HOST` | `database.yml` | PostgreSQL host (default: 127.0.0.1) |
| `DATABASE_GSSENCMODE` | `database.yml` | GSSAPI encryption mode (set to `disable` on macOS with Kerberos) |
| `DATABASE_URL` | `database.yml` | Full connection string (12-factor, takes precedence in production) |
| `POSTGRES_USER` | `docker-compose.yml` | Docker PostgreSQL init: username to create |
| `POSTGRES_PASSWORD` | `docker-compose.yml` | Docker PostgreSQL init: password to set |
| `POSTGRES_DB` | `docker-compose.yml` | Docker PostgreSQL init: database to create |
| `PORT` | `bin/dev`, `config/puma.rb` | App server listen port. `bin/dev` walks upward from it if the port is taken |
| `DATABASE_NAME` | `database.yml` | Override default database name |
| `VULCAN_PORT` | `docker-compose.yml`, `docker-compose.dev.yml` | Host-side port mapping for the web container |

**Why one port variable?** The host-side port the dev container publishes and the port Rails dials are the same port by definition, so there is nothing to keep in sync — `docker-compose.dev.yml` reads `DATABASE_PORT` directly. The earlier `POSTGRES_PORT` was a second name for the same number and has been removed; a leftover `POSTGRES_PORT` in `.env` is simply ignored, so delete it.

**Why not `PG*` shorthand?** PostgreSQL's libpq defines `PGPORT`, `PGHOST`, etc. but our project convention uses full descriptive words with underscores (`DATABASE_PORT`, `VULCAN_ENABLE_OIDC`, etc.) for consistency and readability across all MITRE projects.

## OrbStack / k8s Note

OrbStack's built-in Kubernetes can shadow port 5432 on the host. If `docker logs` shows no incoming connections but Rails reports connection errors, another PostgreSQL is intercepting traffic. Assign a different port.
