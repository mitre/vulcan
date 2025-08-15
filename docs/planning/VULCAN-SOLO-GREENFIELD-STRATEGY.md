# Vulcan Greenfield Migration Strategy
## Solo Developer Approach - Rails 8 Fresh Start

### Context Change: Solo Development Model
- **Single developer**: No coordination overhead
- **No deployment pressure**: Can work until complete
- **Clean cutover**: Deploy when ready
- **Full control**: No backwards compatibility needed

## Revised Recommendation: **Pure Greenfield with Selective Migration**

### Why Greenfield Makes Sense Now

1. **No Team Coordination**
   - Change anything without consensus
   - No need to maintain docs during transition
   - Experiment freely with approaches

2. **Technical Debt Freedom**
   - Skip intermediate Rails versions entirely
   - Go straight to Rails 8 + Ruby 3.3
   - Use latest Vue 3.5 from day one
   - Modern patterns throughout

3. **Faster Development**
   - No compatibility layers
   - No deprecation warnings to fix
   - Copy/paste/refactor workflow
   - AI assistants work better with modern code

4. **Better Architecture**
   - Fix design mistakes
   - Implement proper service objects
   - Use ViewComponents or Phlex
   - Modern authentication (maybe skip Devise)

## Optimized Solo Developer Plan

### Phase 1: Rapid Prototype (Week 1-2)
```bash
# Create cutting-edge Rails 8 app
rails new vulcan2 -d postgresql -j esbuild -c tailwind --skip-test

# Add essential gems only
bundle add rodauth-rails audited good_job noticed \
  view_component prosopite ahoy blazer mission_control-jobs

# Set up modern Vue 3
npm install vue@latest @vitejs/plugin-vue bootstrap@5
```

**Goal**: Working auth + basic CRUD in 2 weeks

### Phase 2: Data Layer Speed Run (Week 3-4)
Instead of recreating all 24 models perfectly:

1. **Generate models from schema**
   ```ruby
   # Copy schema.rb from old app
   # Run: rails db:schema:load
   # Generate models with: rails g model_from_schema
   ```

2. **Copy critical business logic**
   - STI rules hierarchy
   - Validation logic
   - Scopes and associations

3. **Skip non-essential features initially**
   - Audit logging (add later)
   - Complex permissions (simplify first)
   - Slack integration (postpone)

### Phase 3: Core Feature Sprint (Week 5-8)
**Prioritize by user value:**

1. **Week 5**: Projects + Components (core containers)
2. **Week 6**: Rules + STIG import (main functionality)
3. **Week 7**: Review workflow (critical feature)
4. **Week 8**: Exports/Reports (user need)

**Skip initially:**
- Admin interfaces
- Complex settings
- Edge cases
- Nice-to-have features

### Phase 4: Smart UI Migration (Week 9-11)

**Don't recreate all 72 Vue components!**

Instead:
1. **Use Hotwire for simple interactions**
   - Forms, filters, toggles
   - Reduces JS complexity by 50%

2. **Vue 3 only for complex components**
   - Rule editor
   - Component navigator
   - Review interface

3. **Modern UI approach**
   ```vue
   <!-- Use script setup (cleaner) -->
   <script setup>
   import { ref, computed } from 'vue'
   const rules = ref([])
   const filtered = computed(() => rules.value.filter(...))
   </script>
   ```

### Phase 5: Data Migration Strategy (Week 12)

**Simplified approach for solo dev:**

```ruby
# Create rake task for one-time migration
namespace :migrate do
  task from_legacy: :environment do
    # Connect to old database
    Legacy = Class.new(ActiveRecord::Base)
    Legacy.establish_connection(
      adapter: 'postgresql',
      database: 'vulcan_production_backup'
    )

    # Define legacy models inline
    class LegacyUser < Legacy
      self.table_name = 'users'
    end

    # Simple copy with progress bar
    LegacyUser.find_each do |old_user|
      User.create!(
        email: old_user.email,
        # map attributes
      )
      print '.'
    end
  end
end
```

## Solo Developer Optimizations

### 1. Use AI Assistance Effectively
```ruby
# Old Webpacker Vue component (hard for AI)
export default {
  mixins: [ResourceMixin],
  data() { return { loading: false } }
}

# New Vue 3 setup (AI understands better)
<script setup lang="ts">
import { ref } from 'vue'
const loading = ref(false)
</script>
```

### 2. Leverage Rails 8 Defaults
- **Kamal**: Skip complex deployment
- **Solid Queue**: No Redis needed
- **Solid Cache**: SQLite caching
- **Propshaft**: No Sprockets complexity
- **Import maps**: Or stay with esbuild

### 3. Modern Gems Over Custom Code
Instead of porting custom code:
- `noticed` for notifications
- `good_job` for background jobs
- `ahoy` for analytics
- `blazer` for reports
- `mission_control-jobs` for monitoring

### 4. Development Workflow

**Daily routine:**
1. Pick one feature/model
2. Create fresh implementation
3. Copy tests, update for new structure
4. Verify with sample data
5. Document differences
6. Commit and move on

**Use parallel databases:**
```yaml
# config/database.yml
development:
  primary:
    database: vulcan2_dev
  legacy:
    database: vulcan_dev
    migrations_paths: db/legacy_migrations
```

## Realistic Timeline for Solo Developer

### Aggressive (3 months)
- Month 1: Core models + auth
- Month 2: Essential features only
- Month 3: Minimal UI + migration
- **Result**: MVP with 60% features

### Balanced (5 months)
- Month 1-2: Full data layer
- Month 3-4: All backend features
- Month 5: Modern UI + polish
- **Result**: 85% feature parity, better UX

### Complete (6-8 months)
- Month 1-2: Foundation
- Month 3-5: Full features
- Month 6-7: UI excellence
- Month 8: Testing + optimization
- **Result**: Superior to original

## Critical Success Factors

### Do This:
✅ Start with Rails 8 + Ruby 3.3
✅ Use Vue 3 Composition API from day 1
✅ Copy database schema, refactor models
✅ Simplify everything possible
✅ Use modern gems over custom code
✅ Test critical paths only

### Don't Do This:
❌ Try to maintain compatibility
❌ Port all features immediately
❌ Recreate complex workflows as-is
❌ Write comprehensive tests initially
❌ Preserve bad design decisions
❌ Support multiple auth providers initially

## The Nuclear Option: Maximum Velocity

If you want absolute maximum speed:

```ruby
# 1. Dump production data
pg_dump vulcan_production > backup.sql

# 2. Create new Rails 8 app
rails new vulcan2 -d postgresql

# 3. Load the schema
psql vulcan2_development < backup.sql

# 4. Generate models from DB
rails generate schema_to_models

# 5. Copy business logic file by file
cp ../vulcan/app/models/*.rb app/models/
# Fix each file until it works

# 6. Use Hotwire instead of Vue for 80% of UI
# Only use Vue 3 for complex components

# 7. Ship when core features work
```

**Timeline: 6-8 weeks to MVP**

## Decision Matrix

### Choose Greenfield If You:
- [x] Single developer
- [x] No deployment pressure
- [x] Want modern architecture
- [x] Can accept 3-6 month timeline
- [x] Comfortable with Rails 8

### Stick with Incremental If You:
- [ ] Need to deploy updates
- [ ] Have limited time (< 2 months)
- [ ] Want to preserve everything
- [ ] Risk-averse
- [ ] Unfamiliar with Rails 8

## My Recommendation for You

**Go Greenfield!** As a solo developer who can release when ready:

1. **Start fresh with Rails 8** this week
2. **Copy database schema**, generate models
3. **Port business logic** selectively
4. **Use Hotwire** for most UI (faster than Vue)
5. **Vue 3 only** for complex components
6. **Target 3-month MVP**, 5-month full release

The freedom of solo development + no deployment pressure makes this the optimal time for a clean rewrite. You'll end up with a modern, maintainable codebase that's a joy to work with.

## Quick Start This Week

```bash
# Monday: Create new app
rails new vulcan2 -d postgresql -j esbuild -c bootstrap
cd vulcan2

# Tuesday: Copy schema and generate models
cp ../vulcan/db/schema.rb db/
rails db:create db:schema:load
# Generate model files

# Wednesday: Port User + auth
bundle add rodauth-rails
rails generate rodauth:install
# Copy user logic

# Thursday: Port Project/Component models
cp ../vulcan/app/models/project.rb app/models/
cp ../vulcan/app/models/component.rb app/models/
# Fix and test

# Friday: First working feature
rails g scaffold projects
# You now have a working Rails 8 app!
```

---

*The solo developer advantage: Move fast and break things until it's perfect.*