# Recovery Context - January 15, 2025 - Vulcan Final Session

## 🔴 CRITICAL - READ FIRST
**ALWAYS READ**: `/Users/alippold/.claude/CLAUDE.md` and `/Users/alippold/github/mitre/vulcan/CLAUDE.md`
- **NEVER use `git add -A` or `git add .`** - ALWAYS add files individually
- **WE DO NOT COMMIT BROKEN CODE EVER** - all tests and linting must pass
- **Use YARN for JavaScript, NOT npm**
- **Git commits use**: `Authored by: Aaron Lippold<lippold@gmail.com>` - NO Claude signatures

## 📍 CURRENT STATE (End of January 15, 2025)
- **Location**: `/Users/alippold/github/mitre/vulcan`
- **Branch**: `master` (PR #683 merged with all updates)
- **Rails**: 8.0.2.1 ✅
- **Ruby**: 3.3.9 ✅
- **Node**: 22 LTS ✅
- **Tests**: 190 passing ✅
- **Vue**: 2.6.11 (14 separate instances)
- **Bootstrap**: 4.4.1 with Bootstrap-Vue 2.13.0
- **Turbolinks**: Still in use (not migrated to Turbo)

## ✅ COMPLETED TODAY (January 15, 2025)

### Morning Session (PR #683 - 7 commits)
1. **Security Updates**: axios 1.11.0, factory_bot 6.5.4, ESLint 8.57.1, Prettier 3.6.2
2. **Test Modernization**:
   - Migrated ALL controller specs → request specs
   - Migrated ALL feature specs → system specs
   - Removed `any_instance_of` anti-pattern
3. **Rails 8 Compatibility**:
   - Removed Spring gem
   - Fixed fixture_paths deprecation
   - Added bundler-audit
4. **Icon Migration**: Complete MDI → Bootstrap icons
5. **PR #683 merged to master** ✅

### Afternoon Session
1. **Research completed**:
   - Reviewed `vue-architecture-centralization` branch - NOT useful (abandon it)
   - Researched Bootstrap-Vue-Next - still beta, many bugs, not recommended
   - Researched Inertia.js - limited Rails adoption, not recommended
   - Researched Turbo + Vue - complex, conflicting state management

## 🎯 KEY DECISIONS MADE

### Vue 3 Migration Strategy
**DECISION: Don't consolidate Vue 2 first**
- Keep 14 separate Vue instances during migration
- Migrate Vue 2 → Vue 3 page by page
- Skip Bootstrap-Vue-Next, use native Bootstrap 5
- Total effort: 30-40 hours (vs 80-100+ for consolidation first)

### Turbolinks/Turbo Decision
**DECISION: Postpone Turbo migration**
- Turbolinks still works with Rails 8
- Focus on Vue 3 + Bootstrap 5 first
- Consider removing Turbolinks entirely (simpler than Turbo migration)
- Branch created but work not started: `feature/turbolinks-to-turbo-migration`

## 📂 PROJECT STRUCTURE
```
app/javascript/packs/    # 14 Vue entry points
  ├── project.js        # Each creates separate Vue instance
  ├── users.js          # All use vue-turbolinks adapter
  ├── stigs.js          # All use Bootstrap-Vue 2.x
  └── ... (11 more)

spec/
  ├── system/           # Migrated from features/
  ├── requests/         # Migrated from controllers/
  ├── models/
  └── support/
```

## 🔄 MIGRATION PATH FORWARD

### Recommended Order:
1. **Vue 3 + Bootstrap 5** (30-40 hours)
   - Page-by-page migration
   - Keep multiple instances
   - Use native Bootstrap 5 (no Bootstrap-Vue-Next)

2. **Remove Turbolinks** (4-8 hours)
   - Simpler than Turbo migration
   - Just use standard page loads

3. **Evaluate Architecture** (after Vue 3)
   - Decide if single SPA needed
   - Consider Inertia.js if SPA desired
   - Or keep multiple instances (valid pattern!)

## 🚫 WHAT NOT TO DO
- ❌ Don't consolidate Vue 2 to single app first
- ❌ Don't use Bootstrap-Vue-Next (too buggy)
- ❌ Don't migrate to Turbo before Vue 3
- ❌ Don't use Inertia.js (limited Rails community)

## 📝 FILES CREATED (Not committed)
- `TURBO-MIGRATION-PLAN.md` - Detailed Turbo migration plan (postponed)
- Recovery files moved to `docs/archive/recovery/`

## 🔧 TECHNICAL CONTEXT

### Vue Components Pattern
```javascript
// Current pattern in all 14 packs
import TurbolinksAdapter from "vue-turbolinks";
import Vue from "vue";
import { BootstrapVue, IconsPlugin } from "bootstrap-vue";

Vue.use(TurbolinksAdapter);
Vue.use(BootstrapVue);
Vue.use(IconsPlugin);

document.addEventListener("turbolinks:load", () => {
  new Vue({ el: '#ComponentName' });
});
```

### Request Specs Pattern (Rails 8)
```ruby
RSpec.describe 'Resource', type: :request do
  before do
    Rails.application.reload_routes!  # Required for Rails 8
  end

  # Use paths not symbols
  post '/stigs', params: { file: file }
end
```

## MCP Memory Keys
```
mcp__server-memory__open_nodes with names:
["Vulcan Technical Learnings", "Dependency Updates January 2025",
 "Rails 8 Migration TODO", "Vue 3 Migration Research", "Next Steps Vulcan"]
```

## 💭 User's Thinking
- Wants to modernize to Vue 3 + Bootstrap 5
- Originally thought consolidation to single app was needed first
- Now understands multiple instances is fine
- Pragmatic: wants working solution, not perfect architecture
- Frustrated with complex Turbo/Hotwire ecosystem
- Prefers incremental migration over big rewrites

## 🎯 Next Session Should:
1. Start Vue 3 migration planning
2. Create detailed migration guide for first component
3. Set up Vue 3 alongside Vue 2 for gradual migration
4. Plan Bootstrap 5 integration approach

## Context at Compact: 0%