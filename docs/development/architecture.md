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
- **Ruby 3.3.9** - Programming language
- **Rails 8.0.2.1** - Web application framework
- **PostgreSQL** - Primary database
- **Redis** - Caching and background jobs (optional)

### Frontend
- **Vue 2.6.11** - Reactive UI framework
- **Bootstrap 4.4.1** - CSS framework
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

Vulcan uses a unique approach with 14 separate Vue instances, one per page:

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
- `navbar.js` - Global navigation
- `toaster.js` - Global notifications
- `projects.js` - Projects listing
- `project.js` - Single project view
- `project_components.js` - Component management
- `project_component.js` - Single component
- `project_component_reviews.js` - Review workflow
- `project_component_history.js` - Audit history
- `project_component_review_summary.js` - Review summary
- `project_members.js` - Team management
- `project_access_requests.js` - Access requests
- `project_import.js` - Import functionality
- `project_export.js` - Export functionality
- `memberships.js` - User memberships

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
Rule belongs_to :srg_requirement
Component has_many :reviews
Review belongs_to :user
```

## API Design

### RESTful Endpoints
```
GET    /api/v1/projects
POST   /api/v1/projects
GET    /api/v1/projects/:id
PATCH  /api/v1/projects/:id
DELETE /api/v1/projects/:id

GET    /api/v1/projects/:project_id/components
POST   /api/v1/projects/:project_id/components
# ... similar patterns for all resources
```

### JSON Response Format
```json
{
  "data": {
    "id": "123",
    "type": "project",
    "attributes": {
      "name": "Example Project",
      "created_at": "2025-01-01T00:00:00Z"
    },
    "relationships": {
      "components": {
        "data": [
          { "id": "456", "type": "component" }
        ]
      }
    }
  }
}
```

## Security Architecture

### Defense in Depth
1. **Authentication** - Multiple provider support
2. **Authorization** - Role-based access control
3. **Input Validation** - Strong parameters, XSS prevention
4. **Audit Logging** - All changes tracked via `audited` gem
5. **Secure Headers** - CSP, HSTS, X-Frame-Options
6. **SQL Injection Prevention** - Parameterized queries
7. **CSRF Protection** - Rails built-in tokens

### Data Protection
- Passwords hashed with bcrypt
- API tokens stored encrypted
- SSL/TLS required in production
- Sensitive data filtered from logs

## Performance Considerations

### Optimizations
- Database query optimization with includes/joins
- Fragment caching for expensive views
- Turbolinks for faster page transitions
- CDN for static assets
- Docker multi-stage builds (1.76GB image)

### Monitoring
- Application Performance Monitoring (APM)
- Error tracking with rollbar/sentry
- Custom metrics via StatsD
- Health check endpoints

## Deployment Architecture

### Container-based
```dockerfile
# Multi-stage build for optimization
FROM ruby:3.3.9-slim as builder
# Build dependencies and assets

FROM ruby:3.3.9-slim
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

### Export Pipeline

**Formats by entity:**

| Entity | XCCDF | CSV | InSpec | Excel | DISA Excel |
|--------|-------|-----|--------|-------|------------|
| Component | Yes | Yes | Yes | — | — |
| Project | Yes (ZIP) | — | Yes (ZIP) | Yes | Yes |
| STIG | Yes | Yes | — | — | — |
| SRG | Yes | Yes | — | — | — |

**Key files:**
- `app/helpers/export_helper.rb` — XCCDF, InSpec, and Excel export logic
- `app/constants/export_constants.rb` — column definitions, headers, defaults
- `app/javascript/constants/csvColumns.js` — frontend column picker definitions
- `app/javascript/components/shared/ExportModal.vue` — reusable export UI

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