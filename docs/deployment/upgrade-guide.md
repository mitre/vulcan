# Vulcan Upgrade Guide

## Quick Start

The upgrade toolkit is built into every Vulcan image from v2.3.6+. No file injection, no extra installs — just pull and run.

### Docker Compose (most common)

```bash
# 1. Back up your database
docker compose exec db pg_dump -Fc -U postgres vulcan_postgres_production \
  > vulcan_backup_$(date +%Y%m%d).dump

# 2. Pull the new image (or update your image tag in docker-compose.yml)
docker compose pull

# 3. Preflight check (runs the NEW image against your EXISTING database)
docker compose run --rm web rails upgrade:preflight

# 4. Fix any issues it finds
docker compose run --rm web rails upgrade:fix

# 5. Start (db:prepare runs automatically via the entrypoint)
docker compose up -d

# 6. Verify
docker compose exec web rails upgrade:verify
```

### Kubernetes / ECS

```bash
# 1. Back up your database (use your standard backup procedure)

# 2. Run preflight as a one-shot pod/task with the NEW image
kubectl run vulcan-preflight --rm -it \
  --image=mitre/vulcan:v2.3.6 \
  --env-from=secret/vulcan-env \
  -- rails upgrade:preflight

# 3. Fix if needed
kubectl run vulcan-fix --rm -it \
  --image=mitre/vulcan:v2.3.6 \
  --env-from=secret/vulcan-env \
  -- rails upgrade:fix

# 4. Deploy the new image (your standard deploy process)
# 5. Verify
kubectl exec -it deploy/vulcan-web -- rails upgrade:verify
```

### Bare metal / systemd

```bash
# 1. Back up
pg_dump -Fc your_database > vulcan_backup_$(date +%Y%m%d).dump

# 2. Pull new code
cd /path/to/vulcan && git pull

# 3. Preflight
bundle exec rails upgrade:preflight

# 4. Fix
bundle exec rails upgrade:fix

# 5. Upgrade
bundle exec rails db:prepare

# 6. Verify
bundle exec rails upgrade:verify
```

### Can't even connect? (quick diagnostic)

If the new container won't start at all, use the standalone script from any machine with `psql`:

```bash
curl -fsSL https://raw.githubusercontent.com/mitre/vulcan/master/bin/upgrade-check.sh -o upgrade-check.sh
chmod +x upgrade-check.sh
./upgrade-check.sh "postgres://user:pass@your-db-host:5432/vulcan_production?sslmode=require"
```

No Rails, no Ruby, no container — just raw database diagnostics.

### What the tools do

| Command | When | What |
|---|---|---|
| `rails upgrade:preflight` | Before upgrade | Checks connectivity, SSL, schema, orphaned data, config (read-only) |
| `rails upgrade:fix` | Before upgrade | Fixes orphaned records, counter caches, missing dirs (safe writes) |
| `rails upgrade:verify` | After upgrade | Validates schema, models, routes, assets, admin user |
| `bin/upgrade-check.sh` | Can't start container | Raw psql diagnostic — tests connection, SSL, encoding |

The preflight reports:
- ✓ = good
- ⚠ = warning (review, but won't block)
- ✗ = blocker (must fix before upgrading)

### Upgrading from pre-v2.3.6 (toolkit not in image)

If your CURRENT image doesn't have the toolkit yet, run the preflight from the NEW image:

```bash
# Pull the new image but don't start it yet
docker pull mitre/vulcan:v2.3.6

# Run preflight from the new image against your existing database
docker run --rm --env-file .env mitre/vulcan:v2.3.6 rails upgrade:preflight
docker run --rm --env-file .env mitre/vulcan:v2.3.6 rails upgrade:fix
```

The `--env-file .env` passes your existing database credentials to the new container.

---

## Common Upgrade Scenarios

### Upgrading from v2.2.x to v2.3.x

This is a large jump (~90 migrations). Key changes:

| Version | What changed | Migration risk |
|---|---|---|
| v2.3.0 | Devise lockable, sessions table | Low — additive columns |
| v2.3.1 | OIDC provider fix, auth improvements | Low |
| v2.3.4 | Blueprinter JSON serialization | Low — no schema changes |
| v2.3.5 | Public comment review (PR-717) | **Medium** — 8 new columns on reviews, 6 FK constraints, orphan cleanup |
| v2.3.6 | Reactions, UBI9 Docker base | Low — 1 new table |

The **v2.3.5 migrations** are the ones most likely to surface data issues:
- Reviews referencing deleted users → automatically nullified
- Reviews referencing deleted rules → automatically deleted
- Reviews referencing deleted parent reviews → **blocks migration** (run `upgrade:fix`)

### Aurora RDS Specific

Aurora PostgreSQL is fully supported. Common connection issues:

```bash
# Required environment variables for Aurora
DATABASE_URL=postgres://user:pass@your-cluster.cluster-xxxx.rds.amazonaws.com:5432/vulcan_production?sslmode=require
DATABASE_GSSENCMODE=disable
```

**Checklist:**
- [ ] Use the **cluster endpoint** (not instance endpoint) — survives failover
- [ ] Add `?sslmode=require` to DATABASE_URL (Aurora enforces SSL)
- [ ] Set `DATABASE_GSSENCMODE=disable` (Aurora doesn't support GSSAPI)
- [ ] Enable `pg_trgm` in your Aurora DB parameter group (needed for search)
- [ ] If using a custom CA: add the [RDS CA bundle](https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem) to `certs/`

### Docker Image Change (v2.3.6+)

The base image changed from Debian (`ruby:3.4.9-slim`) to Red Hat UBI 9 (`ubi-minimal:9.7`). This affects:

- **SSL cert paths**: `/etc/ssl/certs/ca-certificates.crt` → `/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem`
- **Package manager**: `apt-get` → `microdnf` (only matters if you customized the Dockerfile)
- **PostgreSQL volume mount**: `/var/lib/postgresql/data` → `/var/lib/postgresql` (Postgres 18)

**If upgrading docker-compose with existing data:**
```bash
# 1. Stop the stack
docker compose down

# 2. Back up (see Step 2 above)

# 3. If using Postgres 18 with old volume:
#    The volume mount path changed. Your options:
#    a) Back up + restore into a fresh volume (safest)
#    b) Or keep the old mount path by overriding in docker-compose:
#       volumes:
#         - vulcan_dbdata:/var/lib/postgresql/data

# 4. Start with new image
docker compose up
```

---

## Troubleshooting

### "not seeing the db" / connection refused

Run `upgrade:preflight` — Phase 1 checks connectivity and reports exactly what's wrong. Most common causes:

1. **DATABASE_URL not set** (or set to the wrong host)
2. **SSL not configured** for cloud databases
3. **GSSAPI negotiation failure** (set `DATABASE_GSSENCMODE=disable`)
4. **Read replica endpoint** instead of writer endpoint
5. **Security group / firewall** blocking port 5432

### Migration fails mid-way

The preflight task catches most issues before they happen. If a migration does fail:

1. Check the error message — it usually names the constraint or column
2. Run `upgrade:preflight` again (it re-checks from current state)
3. Run `upgrade:fix` to remediate data issues
4. Re-run `rails db:prepare` (idempotent — picks up where it left off)

### Counter cache drift after upgrade

If the UI shows wrong rule counts after upgrading:

```bash
rails runner "Component.find_each { |c| Component.reset_counters(c.id, :rules) }"
```

Or use `upgrade:verify` which spot-checks and reports drift.
