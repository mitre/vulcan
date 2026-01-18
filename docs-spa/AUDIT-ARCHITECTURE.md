# Audit Layer Architecture

## Overview

The audit layer provides visibility into system activity for security, compliance, and change tracking. Built on the `audited` gem, it serves multiple personas with different views of the same underlying data.

## User Personas & Needs

| Persona | Primary Concerns | What They Need |
|---------|-----------------|----------------|
| **Vulcan Admin** | System security, compliance | Who did what, when, security anomalies |
| **Project Admin** | Project governance | Changes in my project, release readiness |
| **Component Lead** | Content quality, progress | Rule history, review trail, version diffs |
| **Author** | My work, collaboration | What I changed, revert capability |
| **Reviewer** | Quality assurance | What changed since last review |
| **DISA/External** | Compliance, traceability | Full audit trail for certification |

## Implementation Phases

### Phase 1: Admin Audit Log (Current)
- Backend: Controller, routes, blueprints ✅
- Frontend: Types → API → Store → Composable → Page
- Basic filtering: by type, action, user, date range
- Security scopes for admin-only access

### Phase 2: Component Changelog (Future)
- `AuditScope.for_component(id)` - filter audits by component
- `ChangelogService` - group by request_uuid, format for display
- Component view tab: "Change History"
- Export as Markdown for DISA submission

### Phase 3: Security Indicators (Future)
- `SecurityAuditService` - anomaly detection queries
- Dashboard widget: "Security Events"
- Configurable thresholds (bulk changes, off-hours, etc.)

## Data Model

The `audited` gem provides:

```
audits table:
├── id
├── auditable_type    # Rule, Component, Project, User, Membership
├── auditable_id
├── associated_type   # Parent association (e.g., Rule → Component)
├── associated_id
├── user_id           # Who made the change
├── username          # Cached username
├── action            # create, update, destroy
├── audited_changes   # JSON diff of changed fields
├── version           # Audit version number
├── comment           # Optional audit comment
├── remote_address    # IP address
├── request_uuid      # Groups related changes in same request
└── created_at
```

### Models Currently Audited

| Model | Fields Tracked | Associated With |
|-------|---------------|-----------------|
| `User` | admin, name, email | - |
| `Project` | name, description, visibility | - |
| `Component` | name, version, prefix, etc. | - |
| `Rule` | All except component_id, timestamps | Component |
| `Membership` | role, user_id | Project/Component |
| `RuleDescription` | All | Rule |
| `DisaRuleDescription` | All | Rule |
| `Check` | All | Rule |
| `AdditionalAnswer` | answer | Rule |
| `AdditionalQuestion` | All | Component |

## Frontend Architecture

Following the standard pattern: **API → Store → Composable → Page**

```
app/javascript/
├── types/
│   └── audit.ts              # IAudit, IAuditFilters, IAuditStats
├── apis/
│   └── audits.api.ts         # HTTP calls to /admin/audits
├── stores/
│   └── audits.store.ts       # Pinia store with state, actions
├── composables/
│   └── useAudits.ts          # Business logic, toast handling
└── pages/admin/
    └── AuditPage.vue         # Uses useAudits composable
```

## Backend Architecture

```
app/
├── controllers/admin/
│   └── audits_controller.rb  # Index, show, stats endpoints
├── blueprints/
│   ├── audit_blueprint.rb       # Full serializer (detail view)
│   └── audit_index_blueprint.rb # Slim serializer (list view)
└── services/ (Phase 2+)
    ├── changelog_service.rb     # Version diffing, export
    └── security_audit_service.rb # Anomaly detection
```

## API Endpoints

### GET /admin/audits
List audits with pagination and filtering.

**Query Parameters:**
- `page` - Page number (default: 1)
- `per_page` - Items per page (default: 50, max: 100)
- `auditable_type` - Filter by model (Rule, Component, etc.)
- `action_type` - Filter by action (create, update, destroy)
- `user_id` - Filter by user who made change
- `from_date` - Start date (ISO format)
- `to_date` - End date (ISO format)
- `search` - Text search in changes JSON

**Response:**
```json
{
  "audits": [...],
  "pagination": {
    "page": 1,
    "per_page": 50,
    "total": 1234,
    "total_pages": 25
  },
  "filters": {
    "auditable_types": ["Rule", "Component", "Project"],
    "actions": ["create", "update", "destroy"]
  }
}
```

### GET /admin/audits/:id
Get single audit detail.

### GET /admin/audits/stats
Get audit statistics (cached 5 minutes).

**Response:**
```json
{
  "total_audits": 15000,
  "audits_today": 45,
  "audits_this_week": 312,
  "by_type": { "Rule": 12000, "Component": 2500, ... },
  "by_action": { "update": 13000, "create": 1800, "destroy": 200 },
  "cached_at": "2025-12-02T12:00:00Z"
}
```

## Security Indicators (Phase 3)

| Indicator | Description | Query Strategy |
|-----------|-------------|----------------|
| Failed login spikes | Brute force attempts | Devise lockable events |
| Bulk changes | >10 rules in 1 request | Count by request_uuid |
| Off-hours activity | Changes outside 6am-8pm | Time-based filter |
| Sensitive field changes | Status, severity, ident | Field whitelist |
| Privilege escalation | Role/admin changes | Membership + User audits |
| Unusual IP | New IP for user | IP tracking comparison |
| Deletion spikes | Mass deletions | action='destroy' count |

## Caching Strategy

| Data | Cache Duration | Rationale |
|------|---------------|-----------|
| Stats | 5 minutes | Aggregates don't need real-time |
| Filter options | 10 minutes | Types/actions rarely change |
| Audit list | No cache | Must be current for security |
| User lookup | Request-scoped | Batch load per page |

## Testing Requirements

- API tests: All endpoints with auth, pagination, filters
- Store tests: State management, actions
- Composable tests: Business logic, error handling
- Page tests: Integration with composable

## Future Considerations

1. **Retention Policy**: Archive audits older than N months?
2. **Export**: CSV/PDF export for compliance reports?
3. **Real-time**: WebSocket updates for live audit feed?
4. **Materialized Views**: If query performance degrades?
