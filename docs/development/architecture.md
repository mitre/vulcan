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
- **Ruby 3.4.7** - Programming language
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
FROM ruby:3.4.7-slim as builder
# Build dependencies and assets

FROM ruby:3.4.7-slim
# Runtime with jemalloc for memory optimization
```

### Platform Support
- **Heroku** - Platform as a Service
- **Kubernetes** - Container orchestration
- **Docker Compose** - Local development
- **AWS/Azure/GCP** - Cloud platforms

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