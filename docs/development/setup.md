# Development Setup

This guide walks through setting up a local Vulcan development environment.

## Prerequisites

### Required Software

- **Ruby 3.3.9** (use rbenv or rvm for version management)
- **Node.js 22 LTS** and **Yarn** package manager
- **PostgreSQL 12+** database server
- **Git** version control
- **Redis** (optional, for caching)

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

```bash
# Create database
rails db:create

# Run migrations
rails db:migrate

# Seed development data (optional)
rails db:seed
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
rbenv install 3.3.9
rbenv local 3.3.9
```

#### Using rvm

```bash
# Install RVM
\curl -sSL https://get.rvm.io | bash -s stable

# Install Ruby
rvm install 3.3.9
rvm use 3.3.9

# Create gemset (optional)
rvm gemset create vulcan
rvm use 3.3.9@vulcan
```

### Database Configuration

#### PostgreSQL Installation

```bash
# macOS
brew install postgresql@14
brew services start postgresql@14

# Ubuntu/Debian
sudo apt-get install postgresql postgresql-contrib
sudo systemctl start postgresql

# Create user and database
createuser -d vulcan_dev
```

#### Database Configuration File

Create `config/database.yml`:

```yaml
default: &default
  adapter: postgresql
  encoding: unicode
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  timeout: 5000

development:
  <<: *default
  database: vulcan_development
  username: vulcan_dev
  password: <%= ENV['DATABASE_PASSWORD'] %>
  host: localhost
  port: 5432

test:
  <<: *default
  database: vulcan_test
  username: vulcan_dev
  password: <%= ENV['DATABASE_PASSWORD'] %>
  host: localhost
  port: 5432
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
VULCAN_CONTACT_EMAIL=dev@localhost

# Authentication (optional)
VULCAN_ENABLE_USER_REGISTRATION=true
VULCAN_ENABLE_LOCAL_LOGIN=true
VULCAN_SESSION_TIMEOUT=60

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
  password: 'password123',
  admin: true,
  confirmed_at: Time.now
)

User.create!(
  email: 'user@example.com',
  password: 'password123',
  confirmed_at: Time.now
)
```

#### GitHub OAuth (Development)

1. Create GitHub OAuth App:
   - Go to GitHub Settings > Developer settings > OAuth Apps
   - Set callback URL: `http://localhost:3000/users/auth/github/callback`

2. Add to `.env.development`:
```bash
VULCAN_ENABLE_GITHUB_AUTH=true
VULCAN_GITHUB_APP_ID=your_client_id
VULCAN_GITHUB_APP_SECRET=your_client_secret
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
# Ruby tests
bundle exec rspec

# JavaScript tests
yarn test

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

1. Set Ruby SDK to 3.3.9
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

### Using Docker Compose

```bash
# Build containers
docker-compose build

# Start services
docker-compose up

# Run migrations
docker-compose run web rails db:create db:migrate

# Access container
docker-compose exec web bash
```

### Docker Development Tips

1. Use volumes for code hot-reload
2. Separate services for web, db, redis
3. Use .dockerignore for faster builds
4. Override configs with docker-compose.override.yml

## Performance Optimization

### Development Speed

1. **Spring** (Rails 7 and below):
```bash
spring stop
spring status
```

2. **Bootsnap** (enabled by default):
```ruby
# config/boot.rb
require 'bootsnap/setup'
```

3. **Parallel Testing**:
```bash
PARALLEL_WORKERS=4 bundle exec rspec
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
    password: 'password123'
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