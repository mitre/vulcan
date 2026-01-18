# Rails Best Practices Research Findings

**Research Date:** 2025-11-27
**Purpose:** Identify proven Rails patterns to adopt for Vulcan refactor
**Methodology:** Community research, production codebase analysis, gem evaluation

---

## Executive Summary

**Finding:** Initial audit suggested 235 hours of work. After researching Rails community practices, realistic estimate is 66-95 hours.

**Key Insight:** The audit counted work multiple times. Extracting services AUTOMATICALLY fixes fat models and controllers.

**Recommendation:** Adopt 4 proven patterns + build 2 features = 8 phases

---

## 1. SERVICE OBJECTS

### Research Sources
- Toptal Rails Service Objects Tutorial
- RailsConf 2021: "Missing Guide to Service Objects"
- Medium: Essential Rails Patterns - Service Objects
- Production codebases: Loomio, Forem, CartoDB

### Community Consensus
- ✅ **Widely accepted pattern** - Almost universal in mature Rails apps
- ⚠️ **Controversial among some** - Can be overused/misused
- ✅ **Best for:** Complex business logic, multi-step operations, external APIs
- ❌ **Not for:** Simple CRUD, one-liners, basic validations

### Gem Options Evaluated

| Option | Stars | Pros | Cons | Verdict |
|--------|-------|------|------|---------|
| **Plain POROs** | N/A | Simple, no deps, Rails standard | Manual pattern | ✅ **USE THIS** |
| Interactor | 454 | Lightweight, context objects | Extra abstraction | ❌ Skip |
| Dry-rb | 1000+ | Functional approach, powerful | Learning curve, overkill | ❌ Skip |
| rails-patterns | 200 | Thin wrapper | Extra dep for simple pattern | ❌ Skip |

### Recommended Pattern
```ruby
# app/services/application_service.rb
class ApplicationService
  def self.call(*args, **kwargs)
    new(*args, **kwargs).call
  end

  def call
    raise NotImplementedError
  end
end

# Usage
Imports::XccdfImportService.call(component, file)
```

### Directory Structure
```
app/services/
├── imports/
├── exports/
├── components/
├── projects/
└── rules/
```

### For Vulcan
- Extract 400+ LOC from Component model
- Establishes pattern for all future business logic
- **Estimate:** 15-20 hours (not 40h from audit)
- **Why less:** Logic exists, just needs extraction

---

## 2. AUTHORIZATION (PUNDIT)

### Research Sources
- GitHub: varvet/pundit (8,454 stars)
- Multiple production implementations
- Rails community tutorials
- Stack Overflow best practices

### Community Consensus
- ✅ **Clear winner:** Pundit is the Rails standard
- ✅ **Why Pundit won:** Simple, testable, no DSL magic
- ✅ **Used by:** GitHub, Shopify, many large Rails apps
- ❌ **CanCanCan:** Older, more complex, DSL-heavy
- ❌ **Action Policy:** Less adoption, similar to Pundit

### Gem Comparison

| Gem | Stars | Approach | Community | Verdict |
|-----|-------|----------|-----------|---------|
| **Pundit** | 8,454 | Policy objects | Very active | ✅ **USE THIS** |
| CanCanCan | 5,500 | Ability classes | Maintenance mode | ❌ Skip |
| Action Policy | 500 | Policy objects | Smaller community | ❌ Skip |

### Recommended Pattern
```ruby
# app/policies/component_policy.rb
class ComponentPolicy < ApplicationPolicy
  def show?
    user.can_view_component?(record)
  end

  def edit?
    user.can_author_component?(record) || admin?
  end
end

# Controller usage
authorize @component
```

### For Vulcan
- Consolidates 16 scattered permission methods
- Creates 2 policy classes (ComponentPolicy, ProjectPolicy)
- Removes god object anti-pattern from ApplicationController
- **Estimate:** 8-12 hours (not 25h from audit)
- **Why less:** Logic exists, just needs consolidation

---

## 3. SERIALIZERS

### Research Sources
- Reddit: "What serializer to use in 2024?"
- Medium: "Preparing for Life After Active Model Serializers"
- Production app discussions
- Gem documentation

### Community Consensus
- ❌ **ActiveModel::Serializers:** Considered "dead" (last update 2018)
- ✅ **Blueprinter:** Community favorite for non-JSONAPI apps
- ✅ **fast_jsonapi (Netflix):** Good if you need JSONAPI spec
- ⚠️ **Jbuilder:** Built into Rails but verbose, slow

### Gem Comparison

| Gem | Stars | Performance | Flexibility | Verdict |
|-----|-------|-------------|-------------|---------|
| **Blueprinter** | 1,100 | Fast | High | ✅ **USE THIS** |
| fast_jsonapi | 5,000+ | Fastest | JSONAPI only | ❌ Too strict |
| AMS | 5,000+ | Slow | High | ❌ Dead project |
| Jbuilder | Built-in | Slowest | High | ❌ Too verbose |

### Why Blueprinter Won
- Fast performance (close to fast_jsonapi)
- No strict spec requirement (unlike JSONAPI)
- Simple view-based API
- Production-proven (Procore, others)
- Active maintenance

### Recommended Pattern
```ruby
# app/blueprints/component_blueprint.rb
class ComponentBlueprint < Blueprinter::Base
  identifier :id
  fields :name, :prefix, :version

  field :rules_summary do |component|
    ComponentRulesSummaryQuery.call(component)
  end

  view :list do
    excludes :rules
  end

  view :detail do
    association :rules, blueprint: RuleBlueprint
  end
end

# Usage
ComponentBlueprint.render(@component, view: :detail)
```

### For Vulcan
- Replace 5 `as_json` methods
- Consistent JSON responses
- Foundation for API layer
- **Estimate:** 6-8 hours (not 15h from audit)
- **Why less:** as_json methods provide clear spec

---

## 4. QUERY OBJECTS

### Research Sources
- Medium: Essential Rails Patterns - Query Objects
- Thoughtbot: "A Case for Query Objects"
- Production examples: Forem, UK Government apps
- GitHub: Selleo/pattern gem

### Community Consensus
- ✅ **Widely adopted** - Standard pattern in large Rails apps
- ✅ **No gem needed** - Plain POROs
- ✅ **Best for:** Complex queries, multiple joins, aggregations, N+1 fixes
- ❌ **Not for:** Simple scopes, single-table queries

### Pattern Rules
1. Accept relation as first argument (composable)
2. Return ActiveRecord::Relation (chainable)
3. Use `.call` class method
4. Keep in `app/queries/` directory

### Recommended Pattern
```ruby
# app/queries/component_rules_summary_query.rb
class ComponentRulesSummaryQuery
  def self.call(component)
    new(component).call
  end

  def initialize(component)
    @component = component
  end

  def call
    # Single optimized query instead of 10+
    {
      total: @component.security_requirements_guide.srg_rules.count,
      by_status: @component.rules.group(:status).count
    }
  end
end
```

### For Vulcan
- Optimize `rules_summary` (10+ queries → 2-3)
- Fix N+1 issues
- Performance improvement
- **Estimate:** 4-6 hours (not 20h from audit)
- **Why less:** Only 3-4 queries need extraction

---

## 5. STATE MACHINES

### Research Sources
- GitHub: aasm/aasm (5,000+ stars)
- Reddit: "State Machines in Rails"
- RailsCasts: State Machine comparison
- Arkency: "Replace AASM with Rails Enum"

### Community Consensus
- ✅ **AASM:** Most popular state machine gem
- ✅ **Rails 7.1+ enums:** Powerful enough for simple cases
- ✅ **Statesman:** Best for audit trails
- ⚠️ **state_machine gem:** Unmaintained

### Gem Comparison

| Option | Stars | Approach | Best For | Verdict |
|--------|-------|----------|----------|---------|
| **AASM** | 5,000+ | DSL-based | Complex workflows | ✅ If needed |
| Rails Enum | Built-in | Native Rails | Simple states | ✅ **Try first** |
| Statesman | 1,000+ | Audit trails | Complex history | ⏸️ Future |

### For Vulcan
- Review model has simple states (requested → approved → locked)
- Current validation methods might be sufficient
- **Recommendation:** Start with Rails enums, add AASM only if needed
- **Estimate:** 2-3 hours (only if needed)
- **Decision:** Defer until Review workflow needs more complexity

---

## 6. FULL API

### Research Sources
- Rails API documentation
- JWT authentication patterns
- Rack::Attack best practices
- Swagger/rswag gem documentation

### Components Needed
1. **API namespace:** `/api/v1/` routes
2. **Authentication:** Token-based (Bearer tokens)
3. **Rate limiting:** Rack::Attack throttling
4. **CORS:** External client support
5. **Documentation:** Swagger/OpenAPI specs
6. **Error handling:** Consistent JSON errors

### Proven Patterns
- Namespace API controllers: `Api::V1::BaseController`
- Token in User model (secure random)
- Rate limiting by token + IP
- rswag for documentation generation

### For Vulcan
- Full REST API for external clients
- Token authentication
- Rate limiting (100/min per token, 20/min per IP)
- CORS configured
- Swagger docs at `/api-docs`
- **Estimate:** 20-30 hours

---

## Scope Creep Analysis

### Original Audit: 235 hours

**Why inflated:**
1. **Counted work twice:** "Extract services" + "slim models" = same work
2. **Counted work twice:** "Extract policies" + "slim controllers" = same work
3. **Included optional patterns:** Form objects, decorators, presenters
4. **Over-estimated effort:** Assumed building from scratch vs extraction

### Realistic Estimate: 66-95 hours

**Why realistic:**
1. Logic already exists (just needs extraction)
2. Only adopt proven, necessary patterns
3. Skip optional patterns (forms, decorators)
4. Use gems (Pundit, Blueprinter) vs building from scratch

### Breakdown
- Phase 1 (Database): 8-12h
- Phase 2 (Services): 15-20h
- Phase 3 (Pundit): 8-12h
- Phase 4 (Queries): 4-6h
- Phase 5 (Blueprinter): 6-8h
- Phase 6 (API): 20-30h
- Phase 7 (Update): 2-3h
- Phase 8 (Backup): 3-4h

**Total: 66-95 hours = 2.5-3 weeks**

---

## Gems to Adopt

### Install These:
```ruby
# Gemfile
gem 'pundit'           # Authorization
gem 'blueprinter'      # Serialization
gem 'rswag'            # API documentation
gem 'rack-cors'        # CORS (might already have)
gem 'bullet', group: :development  # N+1 detection
```

### Don't Install (Use POROs):
- Interactor (services)
- Dry-rb (services)
- rails-patterns (queries)
- Any form object gems

---

## Pattern Documentation

### Service Object Rules
1. One service = one business operation
2. Class method `.call` for convenience
3. Instance method `#call` does the work
4. Return success/failure consistently
5. Collect errors in `@errors` array
6. Keep services small (<100 LOC)

### Policy Object Rules
1. One policy per model
2. Method names match controller actions (`show?`, `edit?`, etc.)
3. Return boolean
4. Keep authorization logic simple
5. Test all roles/scenarios

### Query Object Rules
1. Accept relation as argument (composable)
2. Return relation or hash
3. Use `.call` class method
4. Optimize for single query when possible
5. Keep queries readable

### Blueprint Rules
1. One blueprint per model
2. Use views for different contexts (list/detail)
3. Eager load associations
4. Keep serialization logic in blueprint

---

## Anti-Patterns to Avoid

### Don't Do This:
- ❌ Service objects for everything (CRUD doesn't need services)
- ❌ Policies that call other policies (complexity explosion)
- ❌ Query objects for simple scopes (overkill)
- ❌ Blueprints with business logic (keep them pure)
- ❌ Callbacks that call services (implicit is bad)

### Do This Instead:
- ✅ Services only for complex operations
- ✅ Policies stay simple and isolated
- ✅ Scopes for simple queries
- ✅ Blueprints only serialize data
- ✅ Explicit service calls in controllers

---

## Testing Strategy

### Service Tests
```ruby
RSpec.describe Imports::XccdfImportService do
  describe '#call' do
    it 'imports successfully' do
      service = described_class.new(component, file)
      result = service.call

      expect(result).to be true
      expect(service.errors).to be_empty
    end

    it 'handles errors gracefully' do
      service = described_class.new(component, invalid_file)
      result = service.call

      expect(result).to be false
      expect(service.errors).not_to be_empty
    end
  end
end
```

### Policy Tests
```ruby
RSpec.describe ComponentPolicy do
  subject { described_class.new(user, component) }

  context 'for admin' do
    let(:user) { create(:user, admin: true) }
    it { is_expected.to permit_actions([:show, :edit, :destroy]) }
  end

  context 'for viewer' do
    let(:user) { create(:user) }
    it { is_expected.to permit_action(:show) }
    it { is_expected.to forbid_actions([:edit, :destroy]) }
  end
end
```

### Query Tests
```ruby
RSpec.describe ComponentRulesSummaryQuery do
  it 'optimizes query count' do
    component = create(:component_with_rules)

    queries = track_queries do
      result = described_class.call(component)
    end

    expect(queries.count).to be <= 3 # Was 10+
  end
end
```

---

## Performance Targets

### Before Refactor
- Component rules_summary: 10+ queries
- N+1 issues in several places
- Raw SQL in 3 locations

### After Refactor
- Component rules_summary: 2-3 queries
- No N+1 issues (Bullet verification)
- No raw SQL (use query objects)

### Tools
- Bullet gem (development)
- Rails query logging
- Benchmark tests

---

## Community Best Practices Summary

### What the Rails Community Actually Does:

**Always Use:**
1. Service objects for complex operations
2. Authorization policies (Pundit is standard)
3. Query objects for N+1 fixes
4. Serializers for APIs

**Sometimes Use:**
- State machines (AASM) for complex workflows
- Form objects for complex forms
- Decorators for view logic

**Rarely Use:**
- Interactor gem (POROs are simpler)
- Dry-rb (overkill for most apps)
- Complex abstractions (YAGNI)

**Never Use:**
- Business logic in controllers
- Business logic in views
- Complex callbacks (implicit behavior)
- Class variables in controllers (thread-unsafe)

---

## Key Takeaways

1. **Adopt proven gems:** Pundit (8,454 stars), Blueprinter (1,100 stars)
2. **Use POROs for patterns:** Services, Queries (no gem needed)
3. **Follow conventions:** `.call` method, standard directory structure
4. **Test thoroughly:** 100% coverage for services/policies/queries
5. **Keep it simple:** Don't over-abstract, YAGNI principle

---

## References

### Documentation
- Pundit: https://github.com/varvet/pundit
- Blueprinter: https://github.com/procore/blueprinter
- AASM: https://github.com/aasm/aasm
- rswag: https://github.com/rswag/rswag

### Articles
- Toptal: Rails Service Objects Tutorial
- Selleo: Essential Rails Patterns (Service/Query Objects)
- Thoughtbot: A Case for Query Objects
- Honeybadger: Refactoring with Service Objects

### Production Examples
- Loomio (query objects): https://github.com/loomio/loomio
- Forem (query objects): https://github.com/forem/forem
- UK Gov (query objects): https://github.com/alphagov/whitehall
- Recurse Center (query objects): https://github.com/recursecenter/community

---

**Research complete. Ready to implement.**
