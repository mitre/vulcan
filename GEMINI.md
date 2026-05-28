# Vulcan Project Context

## 1. Project Overview
**Vulcan** is a specialized security compliance tool designed to streamline the creation of STIG-ready security guidance and InSpec validation profiles. It bridges the gap between high-level DISA SRGs and system-specific STIGs.

- **Primary Goal:** Author, review, and export STIGs and InSpec profiles.
- **Key Features:** Collaborative authoring, STIG/SRG ingestion, InSpec integration, OIDC/LDAP auth, and role-based access control.
- **State:** Active development (v2.3.0), recently migrated to Vue 3 and Rails 8.
- **Key Concept:** Component ≈ "STIG in progress" - same structure, different lifecycle stage.

## 2. Technology Stack
- **Backend:** Ruby 3.4.7, Rails 8.0.2.1, PostgreSQL 16 (pg_search/pg_trgm).
- **Frontend:** Vue 3.5 (Composition API, Pinia), Bootstrap 5, Bootstrap-Vue-Next, Reka UI primitives.
- **Build:** Vite (via `vite_rails`), esbuild.
- **Deployment:** Docker (production), Heroku-compatible.
- **CLI:** Custom Go-based CLI wrapper (`bin/vulcan`) for easy management.

## 3. Architecture & Patterns

### Core Layers (Frontend)
Strict adherence to the **API → Store → Composable → Page** pattern:
1.  **API (`apis/*.ts`):** Raw HTTP calls to Rails endpoints.
2.  **STORE (`stores/*.store.ts`):** Pinia stores for state, caching, loading/error states.
3.  **COMPOSABLE (`composables/useXxx.ts`):** Business logic, computed properties. Wraps store.
4.  **PAGE (`pages/**/XxxPage.vue`):** Uses composables. Minimal logic.
5.  **COMPONENT (`components/**/*.vue`):** Reusable UI, props down, events up.

### Core Entities (`db/schema.rb`)
- **Projects:** Top-level containers.
- **Components:** System elements within a project.
- **Rules (`BaseRule`):** STI entity (`Rule`, `SrgRule`, `StigRule`).
- **Auth:** `Users` (Devise/OIDC), `Memberships` (RBAC).

### Responsive Design
**PRIORITY:** Use **CSS Container Queries** over media queries for new components.
- Pattern: `.my-component { container-type: inline-size; }` then `@container (max-width: ...)`

## 4. Development Workflow

### Setup & Run
Primary interface is the CLI wrapper:
```bash
./bin/vulcan setup dev   # Initial setup
./bin/vulcan start       # Start dev server (Rails + Vite)
# OR manual: foreman start -f Procfile.dev
```

### Testing
- **Backend:** RSpec (Parallel preferred).
  ```bash
  bundle exec parallel_rspec spec/  # Fast, parallel
  bundle exec rspec                 # Serial (debugging)
  ```
- **Frontend:** Vitest.
  ```bash
  pnpm vitest run
  ```
- **Full Suite:** `rake test_all` (or `pnpm test`)

### Linting
- **Ruby:** `bundle exec rubocop --autocorrect-all`
- **JS/TS:** `pnpm lint`

### Git Workflow
- **Rules:** NEVER use `git add -A` or `git add .`. Add files individually.
- **Commit Format:**
  ```text
  type: Short description

  - Detailed bullet points
  - explaining changes

  Authored by: Name<email>
  ```
- **Types:** `feat`, `fix`, `test`, `docs`, `refactor`, `chore`.

## 5. Critical Rules (Do Not Do)
1.  **NEVER** use `git add -A` or `git add .`.
2.  **NEVER** rewrite working code without reason.
3.  **NEVER** add code without tests.
4.  **NEVER** prioritize "fast" over "correct".
5.  **NEVER** create placeholder code and call it "complete".
6.  **ALWAYS** follow the API → Store → Composable → Page architecture.
7.  **ALWAYS** check `docs-spa/` for existing patterns first.

## 6. Key Documentation (`docs-spa/`)
- `COMMAND-PALETTE-ARCHITECTURE.md`
- `CONTROLS-PAGE-ARCHITECTURE.md`
- `PINIA-ARCHITECTURE.md`
- `TYPESCRIPT-TYPES.md`