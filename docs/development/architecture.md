# Architecture Overview

Vulcan is a Rails-based web application designed for creating and managing Security Technical Implementation Guide (STIG) documentation. The application uses a modern technology stack with Vue.js for frontend interactivity and PostgreSQL for data persistence.

## Core Architecture Principles

1. **Multi-page Application (MPA)** - Rather than a single-page application, Vulcan uses multiple Vue instances for different sections
2. **Server-side Rendering** - Rails handles routing and page rendering with Vue for interactive components
3. **RESTful API Design** - JSON APIs support both the Vue frontend and external integrations
4. **Role-based Access Control** - Projects and components have granular permissions
5. **Audit Trail** - All changes are tracked for compliance and review

## Technology Stack

### Backend
- **Ruby 3.4.8** - Programming language
- **Rails 8.0.2.1** - Web application framework
- **PostgreSQL** - Primary database

### Frontend
- **Vue 2.7.16** - Reactive UI framework
- **Bootstrap 4.6.2** - CSS framework
- **Bootstrap-Vue 2.13.0** - Vue Bootstrap components
- **Turbolinks 5.2.0** - Page navigation optimization
- **esbuild** - JavaScript bundling

### Testing
- **RSpec** - Ruby testing framework
- **Capybara** - System/integration testing
- **FactoryBot** - Test data factories
- **SimpleCov** - Code coverage reporting

## Application Structure

```
vulcan/
├── app/
│   ├── controllers/       # Request handlers
│   ├── models/            # Business logic and data
│   ├── views/            # HAML templates
│   ├── javascript/
│   │   ├── components/   # Vue components
│   │   ├── packs/       # Entry points for Vue apps
│   │   ├── mixins/      # Shared Vue functionality
│   │   └── store/       # Shared state management
│   └── lib/
│       └── xccdf/       # STIG/SRG XML parsing
├── config/              # Application configuration
├── db/                  # Database schema and migrations
├── spec/                # Test suite
└── public/              # Static assets
```

## Vue.js Architecture

Vulcan uses 16 JavaScript entry points — 14 Vue instances (one per page), a base application setup, and a global notification component:

```javascript
// Each pack file creates its own Vue instance
// Example: app/javascript/packs/projects.js
new Vue({
    el: '#projects-app',
    render: h => h(ProjectsIndex),
    store
});
```

### Vue Instances by Page
- `application.js` - Base application with Turbolinks/Rails UJS setup
- `login.js` - Login page
- `navbar.js` - Global navigation
- `project.js` - Single project view
- `project_component.js` - Single component editing
- `project_components.js` - Component management
- `projects.js` - Projects listing
- `released_component.js` - Released component view
- `rules.js` - Rule management
- `security_requirements_guides.js` - SRG listing and management
- `srg.js` - Single SRG view
- `stig.js` - Single STIG view
- `stigs.js` - STIGs listing
- `toaster.js` - Global notifications
- `user_profile.js` - User profile management
- `users.js` - User administration

### Benefits of Multiple Vue Instances
- Gradual migration path
- Isolated failure domains
- Faster initial page loads
- Simpler state management

### Drawbacks
- No shared component state between pages
- Duplicate component registration
- Complex build configuration

## Authentication

Authentication providers supported:

```ruby
# Devise with multiple strategies
devise :database_authenticatable  # Local accounts
devise :omniauthable              # OAuth providers
devise :ldap_authenticatable      # LDAP/AD
devise :oidc_authenticatable      # OIDC/SAML
```

## Database Schema

### Core Models
- **Project** - Top-level container
- **Component** - STIG documentation unit
- **Rule** - Individual security control
- **SecurityRequirementsGuide** - DISA SRG requirements
- **Stig** - Published STIG references

### Relationships
```ruby
Project has_many :components
Component has_many :rules
Rule belongs_to :srg_rule
Component has_many :reviews
Review belongs_to :user
```

## API Design

Vulcan is not a public REST API. The only external-facing API endpoint is `GET /api/search/global`, used internally by the navbar search. All other data is served via standard Rails HTML responses with JSON used for Vue component data.

## Security Architecture

### Defense in Depth
1. **Authentication** — Devise with multiple providers (local, GitHub, LDAP, OIDC)
2. **Authorization** — Deny-by-default RBAC enforced by automated test. See [Authorization Architecture](authorization.md) for the complete controller authorization map and safety net spec.
3. **Input Validation** — Strong parameters, XSS prevention
4. **Audit Logging** — All changes tracked via `audited` gem
5. **Secure Headers** — CSP, HSTS, X-Frame-Options
6. **SQL Injection Prevention** — Parameterized queries throughout
7. **CSRF Protection** — Rails built-in tokens

### Authorization Model

Every routed controller action requires an explicit `authorize_*` before_action callback. An automated spec (`spec/requests/authorization_coverage_spec.rb`) introspects the route table and fails if any action is uncovered. This prevents authorization gaps from being introduced by new code.

Permission hierarchy: `admin > author > reviewer > viewer`, scoped to Project or Component.

See [Authorization Architecture](authorization.md) for details.

### Data Protection
- Passwords hashed with PBKDF2-SHA512 (migrated from bcrypt in v2.3.1)
- API tokens stored encrypted
- SSL/TLS required in production
- Sensitive data filtered from logs

## Performance Considerations

### Optimizations
- Database query optimization with includes/joins
- Jbuilder collection caching for JSON views
- Composite indexes for severity count queries
- Turbolinks for faster page transitions
- Docker multi-stage builds with jemalloc for memory efficiency

### Monitoring
- Health check endpoints (`/up`, `/health_check`, `/health_check/database`, `/health_check/migrations`)
- Container-friendly logging (`RAILS_LOG_TO_STDOUT`, optional `STRUCTURED_LOGGING` for JSON output)
- Rack::Attack rate limiting on login and file upload endpoints

## Deployment Architecture

### Container-based
```dockerfile
# Multi-stage build for optimization
FROM ruby:3.4.8-slim as builder
# Build dependencies and assets

FROM ruby:3.4.8-slim
# Runtime with jemalloc for memory optimization
```

### Platform Support
- **Heroku** - Platform as a Service
- **Kubernetes** - Container orchestration
- **Docker Compose** - Local development
- **AWS/Azure/GCP** - Cloud platforms

## Data Import & Export

### Import Pipeline

**SRG/STIG XML Upload:**
1. Controller receives XML file via `POST /srgs` or `POST /stigs`
2. Parsed by `Xccdf::Benchmark.parse(xml)` (library in `app/lib/xccdf/`)
3. `SecurityRequirementsGuide.from_mapping()` or `Stig.from_mapping()` creates the record
4. `after_create` callback imports all rules from the parsed benchmark
5. Raw XML stored in database for re-export

**Component Creation from SRG:**
1. `Component#after_create :import_srg_rules` clones SRG requirements
2. `Component#from_mapping(srg)` maps each SRG rule to a component rule
3. Sequential rule IDs generated (000001, 000002, ...)

**Spreadsheet Import (XLSX/CSV):**
1. `Component#from_spreadsheet` parses XLSX or CSV via the `Roo` gem
2. Validates required headers against `ImportConstants::REQUIRED_MAPPING_CONSTANTS`
3. Maps columns to rule attributes, converts severity (`CAT I/II/III` → `high/medium/low`)

**Spreadsheet Re-import (Update from Spreadsheet):**
1. `POST /components/:id/update_from_spreadsheet` receives XLSX or CSV
2. `SpreadsheetParser` parses rows, matches rules by SRG ID
3. `Component#apply_spreadsheet_changes` compares fields using `Rule#field_editable?`
4. Only editable, changed fields are updated — locked sections are skipped
5. Returns a diff summary (changed rules, skipped fields, errors)

### Export Pipeline

The export system uses a service-based architecture with modes and formatters.

**Export modes** (project-level, purpose-first):

| Mode | Formats | Description |
|------|---------|-------------|
| Working Copy | CSV, Excel | Internal review and bulk editing |
| Vendor Submission | Excel | 17-column strict DISA template |
| STIG-Ready Publish Draft | XCCDF, InSpec | Draft content for DISA review |
| Backup | JSON Archive | Full-fidelity project backup |

**Formats by entity:**

| Entity | XCCDF | CSV | InSpec | Excel | JSON Archive |
|--------|-------|-----|--------|-------|-------------|
| Component | Yes | Yes | Yes | — | — |
| Project | Yes (ZIP) | Yes | Yes (ZIP) | Yes | Yes |
| STIG | Yes | Yes | — | — | — |
| SRG | Yes | Yes | — | — | — |

**Key files:**
- `app/services/export/` — service-based export pipeline (Registry, Base, modes, formatters)
- `app/services/export/formatters/excel_formatter.rb` — caxlsx-based Excel with locked sections
- `app/helpers/export_helper.rb` — legacy XCCDF/InSpec export (DISA format)
- `app/constants/export_constants.rb` — column definitions, headers, defaults
- `app/javascript/constants/csvColumns.js` — frontend column picker definitions
- `app/javascript/components/shared/ExportModal.vue` — mode-first export UI

**CSV architecture:**
- `BaseRule#csv_value_for(column_key)` maps 18 column keys to rule attribute values
- `ExportConstants::BENCHMARK_CSV_COLUMNS` defines available columns with defaults
- SRG exports override the `version` header from "STIG ID" to "SRG ID"
- Frontend `ExportModal` renders a column picker when `columnDefinitions` prop is provided

### Satisfaction Parsing (Postel's Law)

Rule satisfaction relationships (`Satisfied By` / `Satisfies`) are parsed from `vendor_comments` during component import. The implementation follows [Postel's Law](https://en.wikipedia.org/wiki/Robustness_principle): *be liberal in what you accept, conservative in what you produce.*

**Ingest (liberal):**
- Case-insensitive keyword matching (`Satisfied By:`, `satisfied by:`, `SATISFIED BY:`)
- Both directions: `Satisfied By:` and `Satisfies:`
- Comma or semicolon separators: `PREFIX-ID1, PREFIX-ID2` or `PREFIX-ID1; PREFIX-ID2`
- Optional trailing period
- Extra whitespace tolerated
- Other text may precede the keyword

**Export (canonical):**
```
Satisfied By: PREFIX-RULEID, PREFIX-RULEID.
```

**Implementation** (`app/models/component.rb#create_rule_satisfactions`):

```ruby
satisfaction_pattern = /\b(satisfi(?:ed\s+by|es))\s*:\s*/i
```

The method uses PostgreSQL `ILIKE` to find candidate rules, then applies the regex to extract the direction and identifier list. Each identifier is resolved to a rule within the same component.

**Database schema:** Rules use a self-referential many-to-many join table (`rules_satisfied_by`) with `rule_id` and `satisfied_by_rule_id` columns.

## Future Architecture Plans

### Vue 3 Migration
- Incremental page-by-page migration
- Remove Bootstrap-Vue dependency
- Native Bootstrap 5 integration
- Remove Turbolinks

### Rails Improvements
- GraphQL API consideration
- ActionCable for real-time updates
- ActiveStorage for file management
- Background job processing with Sidekiq

### Infrastructure
- Kubernetes operator for automated deployments
- Multi-region support
- Read replicas for scaling
- Caching layer improvements