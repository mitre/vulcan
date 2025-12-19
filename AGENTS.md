# Repository Overview

## Project Description
- Vulcan is a tool for creating STIG-ready security documentation and InSpec validation profiles, aligning DISA SRGs with system-specific STIGs.
- Key technologies: Ruby 3.4.7, Rails 8.0.2, PostgreSQL 16+, Vue 3.5, Bootstrap 5, Docker, GitHub Actions, Prometheus
- Capabilities include collaborative authoring, control management, authentication via OIDC/OKTA, LDAP, GitHub, and email verification, with Slack notifications and health check endpoints.

## Architecture Overview
- **MVC Pattern**: Rails backend for models (e.g., `Rule`, `Project`, `Component`) and controllers (e.g., `RulesController`, `ProjectsController`) managing business logic and database interactions.
- **Frontend Integration**: Vue 3 components with Pinia state management and Bootstrap-Vue-Next for UI, organized under `app/javascript/components`.
- **Single Page App (SPA)**: Vue Router-powered SPA with separate modules for `Projects`, `Rules`, `STIGs`, and `Security Requirements Guides`.
- **Data Flow**: RESTful API between frontend and backend, Active Storage for file attachments, and Redis for background jobs (commented in Gemfile).
- **CI/CD**: GitHub Actions workflows for testing, Docker deployment, and dependency updates.

## Directory Structure
- **Root Files**: `.env*` for configuration, `Dockerfile`/`docker-compose*` for deployment, `README.md`/`CHANGELOG.md` for documentation.
- **Rails App**: `app/models`, `app/controllers`, and `app/views` for core logic and views. `app/javascript` holds Vue components and esbuild bundle.
- **Database**: `db/migrate` includes timestamps for STIG/SRG imports, user auth, and component management. `schema.rb` defines structure.
- **Configuration**: `config/*` includes routes, initializers (e.g., `oidc_startup_validation.rb`), and environment-specific settings.
- **Tests**: `spec/` contains RSpec tests for models (e.g., `user_spec.rb`), controllers, and integration scenarios.
- **Frontend Build**: `package.json` with esbuild and Sass tools, replaced from older Webpacker setup.

## Development Workflow
- **Build**: `yarn install`, `bundle install`, `bin/setup`, `docker-compose up` for Docker.
- **Run**: Start with `foreman start -f Procfile.dev` or manually using `rails server` and `yarn build:watch`.
- **Test**: Run `bundle exec rspec`, `yarn lint`, and `bundle exec rubocop --autocorrect-all`.
- **Lint/Format**: Use `yarn lint` for JS/ESLint, `rubocop` for Ruby, and `prettier` for code formatting.
- **Docker**: Build images with `docker-compose`, and use `setup-docker-secrets.sh` for secure configuration.

## Landing the Plane (Session Completion)

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   bd sync
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds
