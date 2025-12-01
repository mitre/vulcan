# Vulcan

[![Run Test Suite](https://github.com/mitre/vulcan/actions/workflows/run-tests.yml/badge.svg)](https://github.com/mitre/vulcan/actions/workflows/run-tests.yml)
[![Docker Hub Push](https://github.com/mitre/vulcan/actions/workflows/push-to-docker.yml/badge.svg)](https://github.com/mitre/vulcan/actions/workflows/push-to-docker.yml)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![Latest Release](https://img.shields.io/github/v/release/mitre/vulcan)](https://github.com/mitre/vulcan/releases/latest)
[![Docker Pulls](https://img.shields.io/docker/pulls/mitre/vulcan)](https://hub.docker.com/r/mitre/vulcan)

## Overview

Vulcan is a comprehensive tool designed to streamline the creation of STIG-ready security guidance documentation and InSpec automated validation profiles. It bridges the gap between security requirements and practical implementation, enabling organizations to develop both human-readable instructions and machine-readable validation code simultaneously.

### Live Deployments

- **Production**: [https://mitre-vulcan-prod.herokuapp.com](https://mitre-vulcan-prod.herokuapp.com/users/sign_in)
- **Staging**: [https://mitre-vulcan-staging.herokuapp.com](https://mitre-vulcan-staging.herokuapp.com/users/sign_in)

### What is Vulcan?

Vulcan models the Security Technical Implementation Guide (STIG) creation process, facilitating the alignment of security controls from high-level DISA Security Requirements Guides (SRGs) into [STIGs](https://public.cyber.mil/stigs/) tailored to specific system components. Content developed with Vulcan can be submitted to DISA for peer review and formal publication as official STIGs.

### Key Features

- **📋 STIG Process Modeling**: Manages the complete workflow between vendors and sponsors
- **🔍 InSpec Integration**: Write and test validation code locally or across SSH, AWS, and Docker targets
- **📊 Control Management**: Track control status, revision history, and relationships
- **👥 Collaborative Authoring**: Multiple authors can work on control sets with built-in review workflows
- **🔗 Cross-Reference Capabilities**: Look up related controls across published STIGs
- **📚 STIG Library**: View and reference DISA-published STIG content
- **🔒 Security**: Database encryption for confidential data using symmetric encryption
- **🔑 Flexible Authentication**: Support for local, GitHub, LDAP, and OIDC/OKTA providers
- **📬 Notifications**: Email and Slack integration for workflow updates

## 🚀 Quick Start

### Latest Release: [v2.3.0](https://github.com/mitre/vulcan/releases/tag/v2.3.0)

#### Using the Vulcan CLI (Recommended)

```bash
git clone https://github.com/mitre/vulcan.git && cd vulcan

# Development setup (interactive wizard)
./bin/vulcan setup dev

# Start services
./bin/vulcan start
```

The CLI handles everything: PostgreSQL, dependencies, frontend build, database setup, and starts the server.

#### Alternative: Traditional Setup Script

```bash
git clone https://github.com/mitre/vulcan.git && cd vulcan && bin/setup
```

#### Production Docker

```bash
# Clone and setup with CLI
git clone https://github.com/mitre/vulcan.git && cd vulcan

# Production setup (interactive wizard)
./bin/vulcan setup production

# Or manual setup
./bin/vulcan config edit    # Configure .env
./bin/vulcan start -d       # Start in background
```

Default credentials for testing:
- **Email**: admin@example.com
- **Password**: 1234567ab!

For detailed release notes, see the [Changelog](./CHANGELOG.md).

## 📚 Documentation

- **[📖 Full Documentation](https://mitre.github.io/vulcan/)** - Comprehensive guides and references
- [Installation Guide](https://mitre.github.io/vulcan/getting-started/installation/)
- [Configuration Reference](https://mitre.github.io/vulcan/getting-started/environment-variables/)
- [User Guide](https://mitre.github.io/saf-training/courses/guidance/) - Complete training materials
- [API Documentation](https://mitre.github.io/vulcan/api/overview/)
- [Contributing Guidelines](./CONTRIBUTING.md)

### Working with Documentation

The documentation uses [VitePress](https://vitepress.dev/) and is located in the `docs/` directory.

**Important:** The documentation has its own `package.json` separate from the main application to avoid Vue version conflicts (main app uses Vue 2, VitePress uses Vue 3). This separation will be removed once the main application migrates to Vue 3.

```bash
# Start documentation dev server
pnpm docs:dev  # Runs at http://localhost:5173/vulcan/

# Build documentation (only works in CI/CD currently)
pnpm docs:build

# Work directly in docs directory
cd docs
pnpm install  # Install docs-specific dependencies
pnpm dev      # Start dev server
```

## 🛠️ Technology Stack

### Core Framework
- **Ruby 3.3.9** with **Rails 8.0.2.1**
- **PostgreSQL 16** database
- **Node.js 22 LTS** for JavaScript runtime

### Frontend
- **Vue 3.5** with Composition API and Pinia state management
- **Bootstrap 5.3** with Bootstrap-Vue-Next
- **Vue Router 4** for SPA navigation
- **esbuild** for JavaScript bundling

### Testing & Quality
- **RSpec** with parallel_tests for Ruby testing (453 tests)
- **Vitest** for Vue component testing (381 tests)
- **ESLint** & **Prettier** for JavaScript linting
- **RuboCop** for Ruby style enforcement
- **Brakeman** for security scanning
- **bundler-audit** for dependency vulnerability scanning

### DevOps & Deployment
- **Docker** with optimized production images (1.76GB)
- **GitHub Actions** for CI/CD
- **Heroku** compatible
- **SonarCloud** integration for code quality

## 💻 Development Setup

### Prerequisites

- Ruby 3.3.9 (use rbenv or rvm)
- PostgreSQL 16 (or Docker)
- Node.js 22 LTS
- pnpm package manager
- Go 1.21+ (only if rebuilding CLI)

### Using the CLI (Recommended)

```bash
# Clone the repository
git clone https://github.com/mitre/vulcan.git
cd vulcan

# Interactive setup wizard
./bin/vulcan setup dev

# Start development server
./bin/vulcan start

# Common development commands
./bin/vulcan status           # Check service status
./bin/vulcan logs -f          # Follow logs
./bin/vulcan db migrate       # Run migrations
./bin/vulcan test             # Run test suite
```

Access the application at `http://localhost:3000`

### Manual Installation (Alternative)

```bash
# Clone the repository
git clone https://github.com/mitre/vulcan.git
cd vulcan

# Start PostgreSQL with Docker
docker-compose -f docker-compose.dev.yml up -d

# Install dependencies
bundle install
pnpm install

# Build frontend assets
pnpm build

# Setup database
rails db:create db:migrate db:seed

# Start the development server
foreman start -f Procfile.dev
```

**Note:** The `docker-compose.dev.yml` starts PostgreSQL 16 on port 5432 with:
- User: `postgres`
- Password: `postgres`
- Database: `vulcan_vue_development`

### Running Tests

```bash
# Run all tests (frontend + backend)
pnpm test

# Run frontend tests only (Vitest)
pnpm vitest run

# Run backend tests only (parallel - fast)
bundle exec parallel_rspec spec/

# Run backend tests (single-threaded)
bundle exec rspec

# Run specific test file
bundle exec rspec spec/models/user_spec.rb

# Run linters
bundle exec rubocop --autocorrect-all
pnpm lint

# Security scanning
bundle exec brakeman
bundle exec bundler-audit
```

## 🐳 Docker Deployment

### Production-Ready Docker Setup

#### Using the CLI (Recommended)

```bash
# Interactive production setup
./bin/vulcan setup production

# Configure authentication
./bin/vulcan auth setup-oidc    # or setup-ldap

# Start in background
./bin/vulcan start -d

# Monitor
./bin/vulcan status
./bin/vulcan logs -f
```

#### Manual Setup (Alternative)

1. **Generate secure configuration**:
   ```bash
   ./setup-docker-secrets.sh
   # Choose option 2 for production
   ```

2. **Configure environment** (edit `.env`):
   - Authentication settings (OIDC/LDAP)
   - Application URL and contact email
   - SMTP configuration for notifications

3. **Add SSL certificates** (if behind corporate proxy):
   ```bash
   cp /path/to/certificate.pem ./certs/
   ```

4. **Start the application**:
   ```bash
   docker-compose up -d
   ```

5. **Initialize database** (first time only):
   ```bash
   docker-compose run --rm web bundle exec rake db:create db:schema:load db:migrate
   ```

### Docker Image Features

- **Optimized size**: 1.76GB (reduced from 6.5GB)
- **Memory efficiency**: jemalloc for 20-40% reduction
- **Multi-stage builds** for security and size
- **Health checks** configured (see below)
- **Non-root user** execution

## 🏥 Health Check Endpoints

Vulcan provides comprehensive health check endpoints for Kubernetes probes and monitoring:

### `/up` - Basic Liveness Check
Rails 8 built-in endpoint. Returns 200 if application is running.
```bash
curl http://localhost:3000/up
# Returns: green HTML page with 200 status
```

**Use for:** Kubernetes liveness probes

### `/health_check` - Comprehensive Health Check
Validates database connectivity and migration status.
```bash
curl http://localhost:3000/health_check
# Returns: "ok" or error message

curl http://localhost:3000/health_check.json
# Returns: {"healthy":true,"message":"success"}
```

**Use for:** Kubernetes readiness probes, monitoring dashboards

### `/health_check/database` - Database-Specific Check
Checks only database connectivity.
```bash
curl http://localhost:3000/health_check/database
# Returns: "ok" if database is accessible
```

**Use for:** Troubleshooting database issues

### `/status` - Application Status
Detailed application status including configuration and setup state.
```bash
curl http://localhost:3000/status | jq
```

Returns:
- Application version and environment
- Health status (database, LDAP, OIDC)
- Setup state (admin user, auth providers, features)
- System metrics (uptime, database connections)

**Use for:** Deployment verification, support troubleshooting

## 🔐 Authentication Configuration

### OIDC/OKTA Setup (Auto-Discovery)

Vulcan v2.2+ includes automatic OIDC endpoint discovery, requiring only 4 configuration variables:

```bash
VULCAN_ENABLE_OIDC=true
VULCAN_OIDC_ISSUER_URL=https://your-domain.okta.com
VULCAN_OIDC_CLIENT_ID=your-client-id
VULCAN_OIDC_CLIENT_SECRET=your-client-secret
```

Supported providers:
- **Okta**
- **Auth0**
- **Keycloak**
- **Azure AD**
- Any OIDC-compliant provider

### LDAP Configuration

```bash
VULCAN_ENABLE_LDAP=true
VULCAN_LDAP_HOST=ldap.example.com
VULCAN_LDAP_PORT=636
VULCAN_LDAP_BASE=dc=example,dc=com
VULCAN_LDAP_BIND_DN=cn=admin,dc=example,dc=com
VULCAN_LDAP_BIND_PASSWORD=your-password
```

## 🖥️ Vulcan CLI

Vulcan includes a command-line interface for managing deployments, built with Go and the [Charm](https://charm.sh/) stack.

### Quick Start

```bash
# Run from project root
./bin/vulcan --help

# Or add to PATH
export PATH="$PATH:$(pwd)/bin"
vulcan --help
```

### Common Commands

```bash
# Service Management
vulcan start                    # Start services (auto-detects dev/prod)
vulcan stop                     # Stop services
vulcan status                   # Check status
vulcan logs -f                  # Follow logs

# Database
vulcan db migrate               # Run migrations
vulcan db snapshot before-change # Create named snapshot
vulcan db snapshot --restore latest # Restore snapshot
vulcan db backup -o backup.sql  # Create backup
vulcan db restore backup.sql    # Restore backup

# User Management
vulcan user list                # List users
vulcan user create-admin        # Create admin
vulcan user reset-password      # Reset password

# Configuration
vulcan config show              # Show config
vulcan config rotate            # Rotate secrets
vulcan auth setup-oidc          # Configure OIDC
```

See [cli/README.md](./cli/README.md) for full documentation.

## 📋 Maintenance Tasks

### Pull Latest STIGs/SRGs

```bash
# Manual execution
bundle exec rails stig_and_srg_puller:pull

# Schedule in production (cron example)
0 2 * * * cd /app && bundle exec rails stig_and_srg_puller:pull
```

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guidelines](./CONTRIBUTING.md) for details.

### Development Workflow

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'feat: add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Code Standards

- Follow Ruby style guide (enforced by RuboCop)
- Follow JavaScript style guide (enforced by ESLint)
- Write tests for new features
- Update documentation as needed
- Ensure all tests pass before submitting PR

## 📈 Roadmap

### Completed in v2.3.0

- ✅ **Vue 3 Migration**: Full SPA with Composition API and Pinia
- ✅ **Bootstrap 5 Upgrade**: Modern UI with Bootstrap-Vue-Next
- ✅ **Turbolinks Removal**: Vue Router for SPA navigation
- ✅ **Command Palette**: Global search with Cmd+K shortcut
- ✅ **Parallel Tests**: 453 backend tests run in ~90 seconds

### Upcoming Features (v2.4+)

- **API v2**: Enhanced REST API with GraphQL support
- **Multi-tenancy**: Support for multiple organizations
- **Advanced Reporting**: Custom dashboards and metrics
- **Database Refactor**: 3NF normalization for better performance

See our [detailed roadmap](./ROADMAP.md) for more information.

## 🙏 Acknowledgments

- DISA for STIG and SRG specifications
- The InSpec community for validation framework
- All contributors who have helped improve Vulcan

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/mitre/vulcan/issues)
- **Discussions**: [GitHub Discussions](https://github.com/mitre/vulcan/discussions)
- **Wiki**: [Project Wiki](https://github.com/mitre/vulcan/wiki)
- **Security Issues**: saf-security@mitre.org
- **General Inquiries**: saf@mitre.org

## 🏢 About MITRE SAF

Vulcan is part of the [MITRE Security Automation Framework (SAF)](https://saf.mitre.org/), a comprehensive suite of tools and libraries designed to automate security validation and compliance checking.

### Related SAF Projects

- **[InSpec](https://www.inspec.io/)**: Compliance automation framework
- **[Heimdall](https://github.com/mitre/heimdall2)**: Security results visualization
- **[SAF CLI](https://github.com/mitre/saf-cli)**: Command-line tools for security automation
- **[InSpec Profile Development](https://github.com/mitre/inspec-profile-developer-course)**: Training resources

---

<p align="center">
  Made with ❤️ by the <a href="https://saf.mitre.org/">MITRE Security Automation Framework</a> team
  <br>
A <a href="https://saf.mitre.org">MITRE SAF</a> Initiative
</p>
