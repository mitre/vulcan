# Vulcan

[![Run Test Suite](https://github.com/mitre/vulcan/actions/workflows/run-tests.yml/badge.svg)](https://github.com/mitre/vulcan/actions/workflows/run-tests.yml)
[![Docker Hub Push](https://github.com/mitre/vulcan/actions/workflows/push-to-docker.yml/badge.svg)](https://github.com/mitre/vulcan/actions/workflows/push-to-docker.yml)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![Latest Release](https://img.shields.io/github/v/release/mitre/vulcan)](https://github.com/mitre/vulcan/releases/latest)
[![Docker Pulls](https://img.shields.io/docker/pulls/mitre/vulcan)](https://hub.docker.com/r/mitre/vulcan)

## Overview

Vulcan is a comprehensive tool designed to streamline the creation of STIG-ready security guidance documentation and InSpec automated validation profiles. It bridges the gap between security requirements and practical implementation, enabling organizations to develop both human-readable instructions and machine-readable validation code simultaneously.

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

### Latest Release: [v2.2.1](https://github.com/mitre/vulcan/releases/tag/v2.2.1)

```bash
# Pull the latest Docker image
docker pull mitre/vulcan:v2.2.1

# Or use docker-compose for a complete setup
wget https://raw.githubusercontent.com/mitre/vulcan/master/docker-compose.yml
wget https://raw.githubusercontent.com/mitre/vulcan/master/setup-docker-secrets.sh
chmod +x setup-docker-secrets.sh
./setup-docker-secrets.sh
docker-compose up
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

## 🛠️ Technology Stack

### Core Framework
- **Ruby 3.3.9** with **Rails 8.0.2.1**
- **PostgreSQL 12+** database
- **Node.js 22 LTS** for JavaScript runtime

### Frontend
- **Vue 2.6.11** (14 separate instances for different pages)
- **Bootstrap 4.4.1** with Bootstrap-Vue 2.13.0
- **Turbolinks 5.2.0** for navigation optimization
- **esbuild** for JavaScript bundling (replaced Webpacker)

### Testing & Quality
- **RSpec** for Ruby testing (190+ tests)
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
- PostgreSQL 12+
- Node.js 22 LTS
- Yarn package manager

### Local Installation

```bash
# Clone the repository
git clone https://github.com/mitre/vulcan.git
cd vulcan

# Install Ruby dependencies
bundle install

# Install JavaScript dependencies
yarn install

# Setup database
bin/setup

# Seed the database with sample data
rails db:seed

# Start the development server
foreman start -f Procfile.dev

# Or start services separately
rails server
yarn build:watch
```

Access the application at `http://localhost:3000`

### Running Tests

```bash
# Run all tests
bundle exec rspec

# Run specific test file
bundle exec rspec spec/models/user_spec.rb

# Run linters
bundle exec rubocop --autocorrect-all
yarn lint

# Security scanning
bundle exec brakeman
bundle exec bundler-audit
```

## 🐳 Docker Deployment

### Production-Ready Docker Setup

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
- **Health checks** configured
- **Non-root user** execution

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

### Upcoming Features (v2.3+)

- **Vue 3 Migration**: Modernize frontend framework
- **Bootstrap 5 Upgrade**: Update UI components
- **Turbolinks Removal**: Simplify navigation architecture
- **API v2**: Enhanced REST API with GraphQL support
- **Multi-tenancy**: Support for multiple organizations
- **Advanced Reporting**: Custom dashboards and metrics

See our [detailed roadmap](./ROADMAP.md) for more information.

## 📄 License

© 2022-2025 The MITRE Corporation.

This project is licensed under the Apache License 2.0 - see the [LICENSE](./LICENSE.md) file for details.

**Approved for Public Release; Distribution Unlimited. Case Number 18-3678.**

### Notice

This software was produced for the U.S. Government under Contract Number HHSM-500-2012-00008I, and is subject to Federal Acquisition Regulation Clause 52.227-14, Rights in Data-General.

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
