#!/bin/bash
set -e

# Vulcan Docker Entrypoint Script
# Performs preflight checks and database setup before starting the application

echo "🚀 Starting Vulcan container initialization..."

# Function to check if database is ready
wait_for_database() {
  echo "⏳ Waiting for database to be ready..."
  until PGPASSWORD=$DATABASE_PASSWORD psql -h "$DATABASE_HOST" -U "$DATABASE_USERNAME" -d "$DATABASE_NAME" -c '\q' 2>/dev/null; do
    echo "   Database is unavailable - sleeping"
    sleep 2
  done
  echo "✅ Database is ready!"
}

# Function to run migrations
run_migrations() {
  echo "🔄 Running database migrations..."
  bundle exec rails db:migrate
  if [ $? -eq 0 ]; then
    echo "✅ Migrations completed successfully"
  else
    echo "❌ Migration failed!"
    exit 1
  fi
}

# Parse DATABASE_URL if provided
if [ -n "$DATABASE_URL" ]; then
  # Extract components from DATABASE_URL
  proto="$(echo $DATABASE_URL | grep :// | sed -e's,^\(.*://\).*,\1,g')"
  url="$(echo ${DATABASE_URL/$proto/})"
  userpass="$(echo $url | grep @ | cut -d@ -f1)"
  hostport="$(echo ${url/$userpass@/} | cut -d/ -f1)"

  export DATABASE_USERNAME="$(echo $userpass | cut -d: -f1)"
  export DATABASE_PASSWORD="$(echo $userpass | cut -d: -f2)"
  export DATABASE_HOST="$(echo $hostport | cut -d: -f1)"
  export DATABASE_PORT="$(echo $hostport | cut -d: -f2)"
  export DATABASE_NAME="$(echo $url | grep / | cut -d/ -f2- | cut -d? -f1)"
fi

# Set defaults if not provided
export DATABASE_HOST=${DATABASE_HOST:-postgres}
export DATABASE_PORT=${DATABASE_PORT:-5432}
export DATABASE_NAME=${DATABASE_NAME:-vulcan_production}

# Run preflight check
echo "🔍 Running preflight checks..."
if bin/preflight-check; then
  echo "✅ Preflight checks passed"
else
  echo "❌ Preflight checks failed! Please check your configuration."
  echo "   Run 'docker-compose logs vulcan' for details"
  exit 1
fi

# Wait for database
if [ "$SKIP_DB_WAIT" != "true" ]; then
  wait_for_database
fi

# Run migrations if not skipped
if [ "$SKIP_DB_SETUP" != "true" ]; then
  run_migrations
fi

# Create initial admin user if requested
if [ -n "$CREATE_ADMIN_EMAIL" ] && [ -n "$CREATE_ADMIN_PASSWORD" ]; then
  echo "👤 Creating admin user..."
  bundle exec rails runner "
    unless User.find_by(email: '$CREATE_ADMIN_EMAIL')
      User.create!(
        email: '$CREATE_ADMIN_EMAIL',
        password: '$CREATE_ADMIN_PASSWORD',
        name: 'Admin User',
        admin: true
      )
      puts '✅ Admin user created'
    else
      puts '⚠️  Admin user already exists'
    end
  "
fi

# Remove any existing server.pid
rm -f tmp/pids/server.pid

echo "🎉 Vulcan is ready! Starting application server..."

# Execute the main command
exec "$@"