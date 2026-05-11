# Vulcan Upgrade Guide

## Quick Start (for any version upgrade)

### Step 1: Install the upgrade toolkit

Choose the method that matches your deployment:

#### Bare metal / systemd

```bash
# Download directly into your Vulcan source tree
cd /path/to/vulcan
curl -fsSL https://raw.githubusercontent.com/mitre/vulcan/master/lib/tasks/upgrade_preflight.rake \
  -o lib/tasks/upgrade_preflight.rake
```

#### Docker Compose

```bash
# Copy the rake file into your RUNNING container (no image rebuild needed)
curl -fsSL https://raw.githubusercontent.com/mitre/vulcan/master/lib/tasks/upgrade_preflight.rake \
  -o /tmp/upgrade_preflight.rake
docker cp /tmp/upgrade_preflight.rake $(docker compose ps -q web):/rails/lib/tasks/upgrade_preflight.rake
```

#### ECS / Kubernetes / any container orchestrator

```bash
# Option A: Exec into the running task/pod and download
kubectl exec -it deploy/vulcan-web -- bash -c \
  "curl -fsSL https://raw.githubusercontent.com/mitre/vulcan/master/lib/tasks/upgrade_preflight.rake \
   -o lib/tasks/upgrade_preflight.rake"

# Option B: If curl isn't available in the container, copy from local
kubectl cp /tmp/upgrade_preflight.rake vulcan-web-pod:/rails/lib/tasks/upgrade_preflight.rake

# ECS equivalent (using aws cli + ssm exec)
aws ecs execute-command --cluster vulcan --task $TASK_ID --container web \
  --command "curl -fsSL https://raw.githubusercontent.com/mitre/vulcan/master/lib/tasks/upgrade_preflight.rake \
  -o lib/tasks/upgrade_preflight.rake" --interactive
```

#### Can't modify the container at all?

Use the standalone diagnostic script — no Rails required, just `psql`:

```bash
# Download and run from any machine that can reach your database
curl -fsSL https://raw.githubusercontent.com/mitre/vulcan/master/bin/upgrade-check.sh \
  -o upgrade-check.sh && chmod +x upgrade-check.sh

# Point it at your database
./upgrade-check.sh postgres://user:pass@your-db-host:5432/vulcan_production
```

No gem installs, no Gemfile changes, no image rebuilds. The rake task is one file that uses Rails APIs already in the app. The shell script uses only `psql`.

### Step 2: Back up your database

**Do this before anything else.** Every upgrade path is tested, but your data is unique.

```bash
# Vanilla PostgreSQL
pg_dump -Fc your_database > vulcan_backup_$(date +%Y%m%d).dump

# Aurora RDS (from a bastion or local machine with psql access)
pg_dump -Fc -h your-cluster.cluster-xxxx.us-east-1.rds.amazonaws.com \
  -U vulcan_user -d vulcan_production > vulcan_backup_$(date +%Y%m%d).dump

# Docker Compose
docker compose exec db pg_dump -Fc -U postgres vulcan_postgres_production \
  > vulcan_backup_$(date +%Y%m%d).dump

# ECS / Kubernetes (exec into the db container or use a bastion)
kubectl exec -it deploy/vulcan-db -- pg_dump -Fc -U postgres vulcan_production \
  > vulcan_backup_$(date +%Y%m%d).dump
```

### Step 3: Run the preflight check

```bash
# Bare metal / systemd
bundle exec rails upgrade:preflight

# Docker Compose
docker compose exec web rails upgrade:preflight

# Docker (new image against existing database)
docker run --rm --env-file .env vulcan:new-version rails upgrade:preflight

# ECS / Kubernetes
kubectl exec -it deploy/vulcan-web -- rails upgrade:preflight
```

The preflight reports:
- ✓ = good
- ⚠ = warning (review, but won't block)
- ✗ = blocker (must fix before upgrading)

### Step 4: Fix any issues

```bash
# Auto-fix safe issues (orphaned records, counter caches, missing dirs)
bundle exec rails upgrade:fix

# Or in Docker
docker compose exec web rails upgrade:fix
```

The fix task only runs **safe, reversible operations** — it will NOT:
- Delete data without telling you exactly what and how many rows
- Modify schema (that's what db:prepare does)
- Change configuration (it tells you what to set)

For connection issues (the most common upgrade blocker), the fix task prints the exact environment variables you need to set.

### Step 5: Run the upgrade

```bash
# This runs pending migrations (safe — preflight already validated)
bundle exec rails db:prepare

# Docker: the entrypoint does this automatically on container start
docker compose up
```

### Step 6: Verify

```bash
bundle exec rails upgrade:verify
# or
docker compose exec web rails upgrade:verify
```

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
