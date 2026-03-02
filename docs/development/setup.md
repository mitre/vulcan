# Development Setup

This guide walks through setting up a local Vulcan development environment.

## Prerequisites

### Required Software

- **Ruby 3.4.8** (use rbenv or rvm for version management)
- **Node.js 22 LTS** and **Yarn** package manager
- **PostgreSQL 18** database server
- **Git** version control

### Recommended Tools

- **VSCode** or **RubyMine** for IDE
- **Docker Desktop** for containerized development
- **Postman** or **HTTPie** for API testing
- **pgAdmin** or **TablePlus** for database management

## Quick Start

### 1. Clone Repository

```bash
git clone https://github.com/mitre/vulcan.git
cd vulcan
```

### 2. Install Dependencies

#### Ruby Dependencies
```bash
# Install bundler
gem install bundler

# Install gems
bundle install
```

#### JavaScript Dependencies
```bash
# Install yarn if not present
npm install -g yarn

# Install packages
yarn install
```

### 3. Database Setup

#### Option A: Docker PostgreSQL (Recommended)

```bash
# Start PostgreSQL container
docker compose up db -d

# Wait for healthy status
docker compose ps db   # should show "healthy"

# Create and migrate development database
bin/rails db:prepare

# Seed development data (optional — creates demo users, projects, SRGs, STIGs)
bin/rails db:seed
```

#### Option B: Local PostgreSQL

```bash
# macOS
brew install postgresql@18
brew services start postgresql@18

# Create and migrate
bin/rails db:prepare
bin/rails db:seed
```

#### Setting Up Parallel Test Databases

`parallel_rspec` uses one database per CPU core. Set them up once after initial database creation:

```bash
# 1. Create parallel test databases (vulcan_vue_test, vulcan_vue_test2, ..., vulcan_vue_testN)
bundle exec rake parallel:create

# 2. Migrate the primary test database (loads schema_migrations)
bin/rails db:migrate RAILS_ENV=test

# 3. Load schema into all parallel test databases
bundle exec rake parallel:load_schema
```

After schema changes (new migrations), re-sync parallel databases:

```bash
bin/rails db:migrate RAILS_ENV=test
bundle exec rake parallel:load_schema
```

### 4. Start Development Server

```bash
# Using Foreman (recommended)
foreman start -f Procfile.dev

# Or manually in separate terminals:
# Terminal 1: Rails server
rails server

# Terminal 2: JavaScript bundler
yarn build:watch
```

Visit http://localhost:3000

## Detailed Setup

### Ruby Environment

#### Using rbenv

```bash
# Install rbenv
git clone https://github.com/rbenv/rbenv.git ~/.rbenv
echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
echo 'eval "$(rbenv init -)"' >> ~/.bashrc

# Install ruby-build
git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build

# Install Ruby
rbenv install 3.4.8
rbenv local 3.4.8
```

#### Using rvm

```bash
# Install RVM
\curl -sSL https://get.rvm.io | bash -s stable

# Install Ruby
rvm install 3.4.8
rvm use 3.4.8

# Create gemset (optional)
rvm gemset create vulcan
rvm use 3.4.8@vulcan
```

### Database Configuration

#### PostgreSQL Installation

```bash
# macOS
brew install postgresql@18
brew services start postgresql@18

# Ubuntu/Debian
sudo apt-get install postgresql postgresql-contrib
sudo systemctl start postgresql

# Create user and database
createuser -d vulcan_dev
```

#### Database Configuration File

The project's `config/database.yml` supports `DB_SUFFIX` for worktree isolation:

```yaml
development:
  database: vulcan_vue_development<%= ENV['DB_SUFFIX'] %>

test:
  database: vulcan_vue_test<%= ENV['DB_SUFFIX'] %><%= ENV['TEST_ENV_NUMBER'] %>
```

#### Worktree Database Isolation

When working with multiple git worktrees (e.g., v2.x and v3.x branches), set `DB_SUFFIX` in each worktree's `.env` to prevent migration conflicts:

```bash
# v2.x worktree
DB_SUFFIX=_v2    # → vulcan_vue_development_v2

# v3.x worktree
DB_SUFFIX=_v3    # → vulcan_vue_development_v3
```

To set up a new worktree database, clone from the existing one:

```bash
# Clone the development database for a new worktree
docker exec <postgres-container> psql -U postgres -c \
  "CREATE DATABASE vulcan_vue_development_v2 WITH TEMPLATE vulcan_vue_development OWNER postgres;"
```

### Environment Variables

Create `.env.development`:

```bash
# Database
DATABASE_URL=postgresql://vulcan_dev:password@localhost/vulcan_development

# Application
SECRET_KEY_BASE=development_secret_key_minimum_30_characters_long
RAILS_ENV=development

# Email (optional)
VULCAN_ENABLE_SMTP=false
VULCAN_CONTACT_EMAIL=dev@localhost  # Also used as default SMTP username when SMTP enabled

# Authentication (optional)
VULCAN_ENABLE_USER_REGISTRATION=true
VULCAN_ENABLE_LOCAL_LOGIN=true
VULCAN_SESSION_TIMEOUT=1h    # Accepts: 30s, 15m, 1h, or plain numbers

# Development features
RAILS_LOG_LEVEL=debug
VULCAN_WELCOME_TEXT="Development Environment"
```

### Authentication Setup

#### Local Authentication

Enabled by default. Create test users:

```ruby
# Rails console
rails console

User.create!(
  email: 'admin@example.com',
  password: 'S3cure!#Pass001',
  admin: true,
  confirmed_at: Time.now
)

User.create!(
  email: 'user@example.com',
  password: 'S3cure!#Pass001',
  confirmed_at: Time.now
)
```

#### GitHub OAuth (Development)

1. Create GitHub OAuth App:
   - Go to GitHub Settings > Developer settings > OAuth Apps
   - Set callback URL: `http://localhost:3000/users/auth/github/callback`

2. Add to `config/vulcan.yml` under the `providers` key:
```yaml
providers:
  - { name: 'github',
      app_id: 'your_client_id',
      app_secret: 'your_client_secret',
      args: { scope: 'user:email' } }
```

## Development Workflow

### Branch Strategy

```bash
# Create feature branch
git checkout -b feature/your-feature-name

# Make changes and commit
git add specific_files
git commit -m "feat: Add new feature"

# Push to GitHub
git push origin feature/your-feature-name
```

### Code Style

#### Ruby Style
```bash
# Run RuboCop
bundle exec rubocop

# Auto-fix issues
bundle exec rubocop --autocorrect-all
```

#### JavaScript Style
```bash
# Run ESLint
yarn lint

# Auto-fix issues
yarn lint --fix

# CI mode (fails on warnings)
yarn lint:ci
```

### Testing

#### Run All Tests
```bash
# Ruby tests (use parallel_rspec for full suite — 3-4x faster)
bundle exec parallel_rspec spec/

# JavaScript tests
yarn test:unit

# Specific test file
bundle exec rspec spec/models/user_spec.rb

# Specific test line
bundle exec rspec spec/models/user_spec.rb:42
```

#### Test Coverage
```bash
# Generate coverage report
COVERAGE=true bundle exec rspec

# View report
open coverage/index.html
```

### Database Tasks

```bash
# Reset database
rails db:reset

# Run specific migration
rails db:migrate VERSION=20240101000000

# Rollback migration
rails db:rollback

# Database console
rails dbconsole
```

### Asset Management

```bash
# Compile assets
rails assets:precompile

# Clean assets
rails assets:clean

# Watch for changes
yarn build:watch
```

## IDE Configuration

### VSCode

Recommended extensions:
- Ruby LSP
- Rails
- ESLint
- Prettier
- GitLens

`.vscode/settings.json`:
```json
{
  "ruby.useBundler": true,
  "ruby.rubocop.executePath": "bundle exec rubocop",
  "editor.formatOnSave": true,
  "editor.tabSize": 2,
  "files.trimTrailingWhitespace": true,
  "files.insertFinalNewline": true
}
```

### RubyMine

1. Set Ruby SDK to 3.4.8
2. Configure Rails project
3. Enable RuboCop inspection
4. Set JavaScript version to ES6+

## Common Issues

### Bundle Install Failures

```bash
# Missing native extensions
sudo apt-get install libpq-dev # Linux
brew install postgresql # macOS

# Permission issues
bundle config set --local path 'vendor/bundle'
bundle install
```

### Database Connection Issues

```bash
# Check PostgreSQL is running
pg_isready

# Check connection
psql -U vulcan_dev -d vulcan_development -h localhost

# Reset database
rails db:drop db:create db:migrate
```

### Asset Compilation Issues

```bash
# Clear cache
rails tmp:clear
yarn cache clean

# Reinstall dependencies
rm -rf node_modules yarn.lock
yarn install

# Rebuild
yarn build
```

### Port Already in Use

```bash
# Find process using port 3000
lsof -i :3000

# Kill process
kill -9 <PID>

# Or use different port
rails server -p 3001
```

## Docker Development

### Database-Only (Recommended for Local Dev)

Use Docker for PostgreSQL while running Rails natively for faster iteration:

```bash
# Start PostgreSQL only
docker compose up db -d

# Verify healthy
docker compose ps db

# Set up databases (dev + parallel test)
bin/rails db:prepare
bundle exec rake parallel:create
bin/rails db:migrate RAILS_ENV=test
bundle exec rake parallel:load_schema

# Run Rails natively
foreman start -f Procfile.dev
```

### Full Docker Stack (Production-Like Testing)

```bash
# Generate secrets
./setup-docker-secrets.sh

# Build and start everything
docker compose -f docker-compose.prod.yml up --build

# Database setup runs automatically via docker-entrypoint
# First user becomes admin when VULCAN_FIRST_USER_ADMIN=true (default in Docker)
```

### Multi-Project Setup

When running multiple MITRE projects simultaneously, assign unique ports to avoid conflicts. See `docs/development/port-registry.md` for port assignments.

```bash
# Example .env for vulcan-v2.x alongside other projects
DATABASE_PORT=5435
POSTGRES_PORT=5435
PORT=3000
DATABASE_GSSENCMODE=disable
```

### Docker Tips

1. Use `docker compose up db -d` (database-only) for fastest development cycle
2. Use `.dockerignore` for faster builds (excludes docs/, downloads/, coverage/)
3. Production image uses multi-stage build with jemalloc (~596MB)
4. `docker-compose.prod.yml` supports Caddy or nginx reverse proxy profiles

## Performance Optimization

### Development Speed

1. **Bootsnap** (enabled by default):
```ruby
# config/boot.rb
require 'bootsnap/setup'
```

3. **Parallel Testing**:
```bash
bundle exec parallel_rspec spec/
```

### Database Performance

```sql
-- Add indexes for slow queries
CREATE INDEX index_rules_on_project_id ON rules(project_id);

-- Analyze query performance
EXPLAIN ANALYZE SELECT * FROM rules WHERE project_id = 1;
```

## Debugging

### Rails Console

```bash
# Start console
rails console

# With sandbox (rollback on exit)
rails console --sandbox

# Production console (careful!)
RAILS_ENV=production rails console
```

### Debugging Tools

```ruby
# Add to Gemfile
group :development do
  gem 'pry-rails'
  gem 'better_errors'
  gem 'binding_of_caller'
  gem 'letter_opener'
end
```

### Debug in Code

```ruby
# Using pry
binding.pry

# Rails logger
Rails.logger.debug "Variable value: #{variable}"

# JavaScript console
console.log('Debug output:', variable);
```

## Security in Development

### Credentials Management

```bash
# Edit credentials
EDITOR=nano rails credentials:edit

# Access in code
Rails.application.credentials.secret_key
```

### Security Scanning

```bash
# Ruby security audit
bundle exec bundler-audit check --update

# Brakeman for Rails
bundle exec brakeman

# JavaScript audit
yarn audit
```

## Useful Commands

### Rails Generators

```bash
# Generate model
rails generate model User name:string email:string

# Generate controller
rails generate controller Users index show

# Generate migration
rails generate migration AddAdminToUsers admin:boolean
```

### Database Seeds

```ruby
# db/seeds.rb
10.times do |i|
  User.create!(
    email: "user#{i}@example.com",
    password: '1qaz!QAZ1qaz!QAZ'
  )
end
```

### Rails Tasks

```bash
# List all tasks
rails -T

# Custom tasks in lib/tasks/
rails vulcan:custom_task
```

## Resources

- [Rails Guides](https://guides.rubyonrails.org/)
- [Ruby Style Guide](https://rubystyle.guide/)
- [Vue.js Documentation](https://vuejs.org/)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)