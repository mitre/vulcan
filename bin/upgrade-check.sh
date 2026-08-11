#!/usr/bin/env bash
set -euo pipefail

# Vulcan Upgrade Diagnostic — standalone shell script
#
# Checks database connectivity and schema state WITHOUT requiring Rails.
# Use this when you can't install the rake task into a running container.
#
# Usage:
#   ./upgrade-check.sh postgres://user:pass@host:5432/vulcan_production
#   ./upgrade-check.sh  # uses DATABASE_URL from environment
#
# Requirements: psql (PostgreSQL client)

DB_URL="${1:-${DATABASE_URL:-}}"

if [ -z "$DB_URL" ]; then
  echo "Usage: $0 <DATABASE_URL>"
  echo "   or: DATABASE_URL=postgres://... $0"
  echo
  echo "Example:"
  echo "  $0 postgres://user:pass@your-cluster.rds.amazonaws.com:5432/vulcan_production?sslmode=require"
  exit 1
fi

if ! command -v psql &>/dev/null; then
  echo "ERROR: psql not found. Install postgresql-client."
  exit 1
fi

echo "======================================================================"
echo "  Vulcan Upgrade Diagnostic (standalone)"
echo "======================================================================"
echo

# ── Phase 1: Connection ──
echo "── Phase 1: Connection ──"
echo

PG_VERSION=$(psql "$DB_URL" -t -A -c "SELECT version()" 2>&1) || {
  echo "  ✗ Cannot connect to database"
  echo
  echo "  Error: $PG_VERSION"
  echo
  echo "  Checklist:"
  echo "    - Is the hostname correct? (use cluster endpoint for Aurora)"
  echo "    - Is sslmode=require in the URL? (required for Aurora/RDS)"
  echo "    - Is the port correct? (default: 5432)"
  echo "    - Can this machine reach the host? (security group / firewall)"
  echo "    - Try: psql '$DB_URL' -c 'SELECT 1'"
  exit 1
}

echo "  ✓ Connected"
echo "    $PG_VERSION"

if echo "$PG_VERSION" | grep -qi aurora; then
  echo "    Runtime: Amazon Aurora"
fi

# SSL
SSL_USED=$(psql "$DB_URL" -t -A -c "SELECT CASE WHEN ssl THEN 'yes' ELSE 'no' END FROM pg_stat_ssl WHERE pid = pg_backend_pid()" 2>/dev/null || echo "unknown")
if [ "$SSL_USED" = "yes" ]; then
  echo "  ✓ SSL connection active"
elif [ "$SSL_USED" = "no" ]; then
  echo "  ⚠ SSL NOT active — add ?sslmode=require for cloud databases"
else
  echo "  ℹ SSL status unknown (pg_stat_ssl not available)"
fi

# Read replica
IS_REPLICA=$(psql "$DB_URL" -t -A -c "SELECT pg_is_in_recovery()" 2>/dev/null || echo "unknown")
if [ "$IS_REPLICA" = "t" ]; then
  echo "  ✗ Database is a READ REPLICA — migrations cannot run"
  echo "    Use the writer/primary endpoint instead"
elif [ "$IS_REPLICA" = "f" ]; then
  echo "  ✓ Database is primary (writable)"
fi

# Encoding
ENCODING=$(psql "$DB_URL" -t -A -c "SELECT pg_encoding_to_char(encoding) FROM pg_database WHERE datname = current_database()")
if [ "$ENCODING" = "UTF8" ]; then
  echo "  ✓ Encoding: $ENCODING"
else
  echo "  ⚠ Encoding: $ENCODING (expected UTF8)"
fi

# pg_trgm
if psql "$DB_URL" -t -A -c "SELECT 'test' % 'test'" &>/dev/null; then
  echo "  ✓ pg_trgm extension available"
else
  echo "  ⚠ pg_trgm extension not available (needed for search)"
  echo "    Aurora: enable in DB parameter group"
  echo "    Vanilla PG: CREATE EXTENSION IF NOT EXISTS pg_trgm;"
fi

# ── Phase 2: Schema ──
echo
echo "── Phase 2: Schema ──"
echo

SCHEMA_VERSION=$(psql "$DB_URL" -t -A -c "SELECT MAX(version) FROM schema_migrations" 2>/dev/null || echo "none")
echo "  Current schema version: $SCHEMA_VERSION"

MIGRATION_COUNT=$(psql "$DB_URL" -t -A -c "SELECT COUNT(*) FROM schema_migrations" 2>/dev/null || echo "0")
echo "  Applied migrations: $MIGRATION_COUNT"

# ── Phase 3: Data Integrity ──
echo
echo "── Phase 3: Data Integrity ──"
echo

# Check if reviews table exists
HAS_REVIEWS=$(psql "$DB_URL" -t -A -c "SELECT EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name='reviews')")
if [ "$HAS_REVIEWS" = "t" ]; then
  ORPHAN_USERS=$(psql "$DB_URL" -t -A -c "SELECT COUNT(*) FROM reviews WHERE user_id IS NOT NULL AND user_id NOT IN (SELECT id FROM users)")
  if [ "$ORPHAN_USERS" = "0" ]; then
    echo "  ✓ No orphaned review.user_id"
  else
    echo "  ⚠ $ORPHAN_USERS review(s) with orphaned user_id (migration will nullify)"
  fi

  ORPHAN_RULES=$(psql "$DB_URL" -t -A -c "SELECT COUNT(*) FROM reviews WHERE rule_id IS NOT NULL AND rule_id NOT IN (SELECT id FROM base_rules)")
  if [ "$ORPHAN_RULES" = "0" ]; then
    echo "  ✓ No orphaned review.rule_id"
  else
    echo "  ⚠ $ORPHAN_RULES review(s) with orphaned rule_id (migration will delete)"
  fi

  REVIEW_COUNT=$(psql "$DB_URL" -t -A -c "SELECT COUNT(*) FROM reviews")
  USER_COUNT=$(psql "$DB_URL" -t -A -c "SELECT COUNT(*) FROM users")
  RULE_COUNT=$(psql "$DB_URL" -t -A -c "SELECT COUNT(*) FROM base_rules")
  echo
  echo "  Table sizes:"
  echo "    reviews:    $REVIEW_COUNT"
  echo "    users:      $USER_COUNT"
  echo "    base_rules: $RULE_COUNT"
else
  echo "  ℹ reviews table does not exist (fresh database)"
fi

AUDIT_COUNT=$(psql "$DB_URL" -t -A -c "SELECT COUNT(*) FROM audits" 2>/dev/null || echo "0")
echo "    audits:     $AUDIT_COUNT"

# ── Summary ──
echo
echo "── Summary ──"
echo
echo "  If all checks passed: proceed with the upgrade."
echo "  If connection failed: fix DATABASE_URL and re-run."
echo
echo "  Next steps:"
echo "    1. Back up: pg_dump -Fc \$DATABASE_URL > backup.dump"
echo "    2. Upgrade the container image"
echo "    3. Start the container (db:prepare runs automatically)"
echo "    4. Verify: rails upgrade:verify (inside the new container)"

if echo "$PG_VERSION" | grep -qi aurora; then
  echo
  echo "── Aurora Notes ──"
  echo "  • Use cluster endpoint (not instance) for DATABASE_URL"
  echo "  • Add ?sslmode=require to DATABASE_URL"
  echo "  • Set DATABASE_GSSENCMODE=disable in environment"
  echo "  • Enable pg_trgm in DB parameter group"
fi

echo
echo "======================================================================"
