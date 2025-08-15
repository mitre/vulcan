# Vulcan Greenfield Migration Analysis
## Rails 8 + Bootstrap 5 + Vue 3 Migration Strategy

### Executive Summary
This document analyzes the feasibility and approach for migrating Vulcan from its current stack (Rails 6.1, Ruby 2.7, Vue 2, Bootstrap 4) to a modern greenfield Rails 8 application.

## Current State Analysis

### Technology Stack
- **Ruby**: 2.7.5 (EOL March 2023)
- **Rails**: 6.1.4 (Released 2021)
- **Node**: 16.x (Maintenance mode)
- **Frontend**: Vue 2.7 + Bootstrap 4 + Webpacker 5
- **Database**: PostgreSQL 12
- **Authentication**: Devise + Omniauth (LDAP, GitHub, OIDC)

### Application Complexity
- **24 Models** with complex domain logic (STI, polymorphic associations)
- **13 Controllers** serving hybrid web/JSON responses
- **65 Database Migrations** (5 years of evolution)
- **72 Vue Components** tightly coupled with Rails views
- **37 XCCDF Processing Classes** (core business logic)
- **Multi-provider Authentication** with custom workflows

## Target State: Rails 8 Architecture

### Modern Stack Benefits
- **Rails 8**: Kamal deployment, Solid Cache/Queue, native PWA support
- **Ruby 3.3+**: 3x performance improvement, better memory management
- **jsbundling-rails**: Simplified JS toolchain with esbuild
- **Bootstrap 5**: Modern CSS without jQuery dependency
- **Vue 3**: Composition API, better TypeScript support, improved performance
- **Hotwire**: Optional for simpler interactions (reduce JS complexity)

## Migration Strategies Comparison

### Strategy A: Incremental In-Place Upgrade
**Approach**: Upgrade existing codebase step by step

**Steps**:
1. Ruby 2.7 → 3.0 → 3.1 → 3.2 → 3.3
2. Rails 6.1 → 7.0 → 7.1 → 7.2 → 8.0
3. Webpacker → jsbundling-rails
4. Vue 2 → Vue 2.7 → Vue 3 (with migration build)
5. Bootstrap 4 → Bootstrap 5

**Pros**:
- Continuous deployment possible
- Gradual risk mitigation
- Team learns incrementally
- Existing tests remain valid

**Cons**:
- Long timeline (6-12 months)
- Technical debt accumulates during transition
- Multiple breaking changes to manage
- Requires maintaining compatibility layers

**Risk Level**: MEDIUM

---

### Strategy B: Greenfield Rails 8 Application
**Approach**: Create new Rails 8 app, migrate features systematically

**Steps**:
1. Generate Rails 8 skeleton with modern defaults
2. Set up authentication fresh (devise-oidc or rodauth)
3. Recreate data models with modern patterns
4. Port business logic with refactoring
5. Rebuild UI with Vue 3/Bootstrap 5
6. Data migration strategy for production

**Pros**:
- Clean architecture from day one
- Modern patterns and conventions
- No legacy code baggage
- Opportunity to fix design issues
- Better performance baseline

**Cons**:
- Requires parallel development
- Complex data migration
- Higher initial effort
- Team needs to learn new patterns
- Testing effort doubles

**Risk Level**: HIGH

---

### Strategy C: Hybrid Strangler Fig Pattern
**Approach**: New Rails 8 app alongside existing, gradual feature migration

**Steps**:
1. Create Rails 8 application as microservice
2. Implement new features in Rails 8
3. Migrate features module by module
4. Share database (read-only from new app initially)
5. Gradually move write operations
6. Decommission old app when complete

**Pros**:
- Production stays stable
- Can validate approach early
- Rollback is straightforward
- Teams can work in parallel
- Learning happens gradually

**Cons**:
- Requires proxy/routing layer
- Database schema coordination
- Authentication complexity
- Longer total timeline
- Operational overhead

**Risk Level**: MEDIUM-LOW

## Detailed Greenfield Migration Plan

### Phase 1: Foundation (Week 1-2)
```bash
# Create new Rails 8 application
rails new vulcan-next -d postgresql -j esbuild -c bootstrap

# Core gems to add
bundle add devise rodauth-omniauth audited amoeba \
  nokogiri-happymapper fast_excel slack-ruby-client
```

### Phase 2: Core Models (Week 3-4)
- Recreate User, Project, Component models
- Implement STI for BaseRule hierarchy
- Set up polymorphic associations
- Migrate audit logging

### Phase 3: Authentication (Week 5)
- Implement multi-provider auth (OIDC, LDAP, GitHub)
- Port permission system
- Migrate user sessions

### Phase 4: Business Logic (Week 6-8)
- Port XCCDF processing library
- Migrate CCI mapping logic
- Implement rule satisfaction engine
- Port review workflows

### Phase 5: Frontend Migration (Week 9-12)
- Set up Vue 3 with Composition API
- Create component library with Bootstrap 5
- Port Vue components systematically
- Implement new routing structure

### Phase 6: Data Migration (Week 13-14)
- Create ETL scripts for data transfer
- Handle schema differences
- Validate data integrity
- Plan cutover strategy

### Phase 7: Testing & Validation (Week 15-16)
- Port and update test suite
- Performance testing
- Security audit
- User acceptance testing

## Critical Migration Challenges

### 1. Vue 2 → Vue 3 Breaking Changes
```javascript
// Vue 2 (Current)
export default {
  data() {
    return { rules: [] }
  },
  mounted() {
    this.loadRules()
  }
}

// Vue 3 (Target)
import { ref, onMounted } from 'vue'
export default {
  setup() {
    const rules = ref([])
    onMounted(() => loadRules())
    return { rules }
  }
}
```

### 2. Bootstrap 4 → 5 Migration
- jQuery removal impacts interactive components
- Utility class changes (e.g., `ml-2` → `ms-2`)
- Form control styling changes
- Modal and dropdown API changes

### 3. Database Schema Evolution
```ruby
# May need schema adjustments for Rails 8 conventions
class MigrateToRails8Schema < ActiveRecord::Migration[8.0]
  def change
    # Add missing timestamps
    add_timestamps :legacy_tables, null: true

    # Update STI column if needed
    rename_column :base_rules, :sti_type, :type

    # Add missing foreign key constraints
    add_foreign_key :rules, :projects
  end
end
```

### 4. Authentication System
- Devise compatibility with Rails 8
- Omniauth provider updates
- Session handling changes
- CORS configuration for API mode

## Recommended Approach

### **Recommendation: Hybrid Incremental Upgrade (Modified Strategy A)**

Instead of a full greenfield rewrite, I recommend:

1. **Immediate Fixes** (Week 1)
   - Upgrade Node to 18 (enables Claude Code)
   - Fix critical security vulnerabilities
   - Update documentation

2. **Foundation Upgrades** (Month 1-2)
   - Ruby 2.7 → 3.2 (skip intermediate versions)
   - Rails 6.1 → 7.0 (major milestone)
   - Keep existing Webpacker temporarily

3. **Modern Frontend** (Month 3-4)
   - Webpacker → jsbundling-rails
   - Keep Vue 2.7 (provides Composition API)
   - Gradual Bootstrap 4 → 5 migration

4. **Rails 8 Preparation** (Month 5-6)
   - Rails 7.0 → 7.2 → 8.0
   - Adopt new Rails 8 features incrementally
   - Performance optimizations

5. **Future Vue 3** (Month 7+)
   - Component-by-component migration
   - Use Vue 3 migration build
   - Maintain backwards compatibility

## Cost-Benefit Analysis

### Greenfield Approach
- **Cost**: 16-20 weeks development, high risk
- **Benefit**: Clean architecture, modern stack, better performance
- **ROI**: Long-term maintenance savings, but high upfront cost

### Incremental Approach
- **Cost**: 6-8 months calendar time, medium risk
- **Benefit**: Continuous delivery, gradual improvement
- **ROI**: Immediate security benefits, manageable risk

### Hybrid Approach
- **Cost**: 8-10 months, low-medium risk
- **Benefit**: Best of both worlds, validation opportunity
- **ROI**: Balanced risk and reward

## Decision Factors

Choose **Greenfield** if:
- Team has Rails 8 experience
- Willing to pause feature development
- Have resources for parallel development
- Want to fix fundamental architecture issues

Choose **Incremental** if:
- Need continuous deployment
- Limited team resources
- Want to preserve existing investment
- Risk tolerance is low

Choose **Hybrid** if:
- Have dedicated team for new development
- Want to validate modern architecture
- Can manage operational complexity
- Long-term migration timeline acceptable

## Next Steps

1. **Team Assessment**: Evaluate team's Rails 8/Vue 3 experience
2. **Stakeholder Buy-in**: Present timeline and resource needs
3. **Proof of Concept**: Build small Rails 8 prototype with core features
4. **Risk Analysis**: Detailed assessment of migration risks
5. **Decision Point**: Choose strategy based on POC results

## Appendix: Tool Comparison

### Build Tools
| Current | Target | Benefit |
|---------|--------|---------|
| Webpacker 5 | jsbundling + esbuild | 100x faster builds |
| Sprockets | Propshaft | Simpler, faster |
| Node 16 | Node 20+ | Modern JS features |

### Framework Features
| Rails 6.1 | Rails 8 | Benefit |
|-----------|---------|---------|
| Classic deployment | Kamal | Container-native |
| Redis cache | Solid Cache | SQLite-based |
| Sidekiq | Solid Queue | Simplified stack |
| Action Cable | Turbo Streams | Better real-time |

### Frontend Stack
| Current | Target | Benefit |
|---------|--------|---------|
| Vue 2.7 | Vue 3.5 | Composition API, performance |
| Bootstrap 4 | Bootstrap 5 | No jQuery, modern CSS |
| Webpacker | esbuild | Faster, simpler |
| Turbolinks | Turbo | Better SPA feel |

---

*Document created: $(date)*
*Author: Aaron Lippold <lippold@gmail.com>*