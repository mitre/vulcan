# Vulcan v2.4.0 Comprehensive Refactor Plan

**Created:** 2025-11-27
**Goal:** Establish best-practice foundation for future development
**Approach:** Adopt proven Rails patterns, don't reinvent the wheel
**Timeline:** 106-145 hours over 4-5 weeks
**Quality Focus:** Thorough testing, efficient execution, well-documented

---

## Overview

This refactor establishes the foundational patterns that will make all future work easier:
- Clean data model (no duplicates)
- Service objects (business logic extraction)
- Pundit policies (authorization centralization)
- Query objects (performance optimization)
- Blueprinter serialization (clean APIs)
- Full REST API (external integrations)
- Update from file (external editing workflow)
- Project backup/restore (disaster recovery)
- **mavonEditor integration (markdown editing)**
- **Vue 3 + Bootstrap 5 migration (modern frontend)**

---

## Phase Dependencies (FRONTEND FIRST)

```
Phase 1: Vue 3 + Bootstrap 5 Migration (MODERN STACK FIRST)
    ↓ (all work happens on modern frontend)
Phase 2: Database Redesign (data model foundation)
    ↓
Phase 3: Service Objects (business logic extraction)
    ↓
Phase 4: Pundit Authorization (security centralization)
    ↓
Phase 5: Query Objects (performance optimization)
    ↓
Phase 6: Blueprinter Serialization (API preparation)
    ↓
Phase 7: Full API Layer (external integrations)
    ↓
Phase 8: Update from File (uses services from Phase 3)
    ↓
Phase 9: Project Backup/Restore (uses services from Phase 3)
    ↓
Phase 10: md-editor-v3 Integration (Vue 3 markdown editor)
```

**CRITICAL: Phase 1 must be first. Do Vue 3 migration before all backend refactoring.**

---

## PHASE 1: Vue 3 + Bootstrap 5 Migration (30-40 hours) ⚡ FRONTEND FOUNDATION

### Problem
- Vue 2 is end-of-life (EOL December 2023)
- Bootstrap 4 is outdated
- Bootstrap-Vue 2 is unmaintained
- Refactoring on deprecated stack doesn't make sense
- Will need to migrate eventually anyway

### Solution
- **Do Vue 3 migration FIRST** - Modern stack from day 1
- All subsequent refactoring happens on stable Vue 3
- Use Bootstrap 5 native (no Bootstrap-Vue dependency)
- Keep 14 separate Vue instances (don't consolidate)
- Remove Turbolinks
- Keep esbuild (fast, works great) - Skip Vite for now

### Tasks

#### 1. **Preparation and Research** (4-6h)
- Read Vue 3 migration guide
- Read Bootstrap 5 migration guide
- Identify all Bootstrap-Vue components used
- Create component migration checklist
- Test critical components in isolation

#### 2. **Dependencies Update** (1h)
```bash
# Remove Vue 2 stack
yarn remove vue@2 bootstrap-vue bootstrap@4 vue-turbolinks

# Add Vue 3 stack
yarn add vue@3
yarn add bootstrap@5
yarn add @popperjs/core

# Update esbuild config for Vue 3
```

#### 3. **Turbolinks Removal** (2-3h)
- Remove turbolinks gem from Gemfile
- Update all `turbolinks:load` listeners → `DOMContentLoaded`
- Remove vue-turbolinks adapter
- Test page navigation

#### 4. **esbuild Configuration** (1-2h)
```javascript
// esbuild.config.js
// Update for Vue 3
define: {
  __VUE_OPTIONS_API__: 'true',
  __VUE_PROD_DEVTOOLS__: 'false',
  __VUE_PROD_HYDRATION_MISMATCH_DETAILS__: 'false'
}
```

#### 5. **Page-by-Page Migration** (20-30h)

**Migration order (simple → complex):**
1. toaster.js (1-2h)
2. navbar.js (1-2h)
3. projects.js (2h)
4. security_requirements_guides.js (2h)
5. stigs.js (2h)
6. components.js (2h)
7. project.js (2h)
8. component.js (2-3h)
9. project_components.js (2h)
10. project_component.js (2-3h)
11. basic_rule.js (2h)
12. advanced_rule.js (2h)
13. rule.js (3-4h) - Most complex
14. application.js (2h)

**For each page:**

```javascript
// BEFORE (Vue 2)
import Vue from 'vue'
import VueTurbolinks from 'vue-turbolinks'
import { BootstrapVue } from 'bootstrap-vue'

Vue.use(VueTurbolinks)
Vue.use(BootstrapVue)

document.addEventListener('turbolinks:load', () => {
  new Vue({
    el: '#app',
    data() {
      return { items: [] }
    },
    methods: {
      loadItems() { }
    }
  })
})

// AFTER (Vue 3)
import { createApp } from 'vue'

document.addEventListener('DOMContentLoaded', () => {
  const app = createApp({
    data() {
      return { items: [] }
    },
    methods: {
      loadItems() { }
    }
  })
  app.mount('#app')
})
```

**Bootstrap-Vue → Bootstrap 5 mapping:**
```vue
<!-- BEFORE (Bootstrap-Vue) -->
<b-button variant="primary" @click="save">Save</b-button>
<b-modal v-model="showModal" title="Edit">...</b-modal>
<b-table :items="items" :fields="fields"></b-table>
<b-form-input v-model="name"></b-form-input>
<b-form-checkbox v-model="checked">Check</b-form-checkbox>
<b-dropdown text="Menu">
  <b-dropdown-item>Action</b-dropdown-item>
</b-dropdown>
<b-icon icon="check"></b-icon>

<!-- AFTER (Bootstrap 5 native) -->
<button class="btn btn-primary" @click="save">Save</button>
<div class="modal fade" tabindex="-1">...</div>
<table class="table">
  <thead><tr><th v-for="field in fields">{{ field.label }}</th></tr></thead>
  <tbody><tr v-for="item in items"><td>{{ item.name }}</td></tr></tbody>
</table>
<input class="form-control" v-model="name">
<div class="form-check">
  <input class="form-check-input" type="checkbox" v-model="checked">
  <label class="form-check-label">Check</label>
</div>
<div class="dropdown">
  <button class="btn dropdown-toggle" data-bs-toggle="dropdown">Menu</button>
  <ul class="dropdown-menu">
    <li><a class="dropdown-item">Action</a></li>
  </ul>
</div>
<i class="bi bi-check"></i> <!-- Bootstrap Icons already in use -->
```

#### 6. **Component Updates** (3-4h)
- Update all shared Vue components for Vue 3
- Fix $listeners (merged into $attrs in Vue 3)
- Fix v-model (breaking changes)
- Remove filters (use methods)
- Test all components

**Vue 3 breaking changes:**
```javascript
// $listeners removed
// BEFORE: v-on="$listeners"
// AFTER: v-bind="$attrs" (listeners merged)

// Filters removed
// BEFORE: {{ date | formatDate }}
// AFTER: {{ formatDate(date) }}

// v-model on components
// BEFORE: this.$emit('input', value)
// AFTER: this.$emit('update:modelValue', value)

// Global API
// BEFORE: Vue.use(plugin)
// AFTER: app.use(plugin)
```

#### 7. **CSS/SCSS Updates** (2-3h)
- Update Bootstrap 4 → 5 class names (left→start, right→end)
- Update custom SCSS for Bootstrap 5 variables
- Fix layout issues
- Test responsive breakpoints

#### 8. **Testing** (4-6h)
- Test every page loads
- Test all forms
- Test all modals
- Test all dropdowns
- Test import/export
- Test rule editing
- Visual regression testing
- Fix any bugs

### Deliverables
```
package.json (updated):
  - vue: ^3.5.0
  - bootstrap: ^5.3.3
  - @popperjs/core: ^2.11.8
  (removed: vue@2, bootstrap-vue, bootstrap@4, vue-turbolinks)

app/javascript/packs/ (all 14 files migrated to Vue 3)
app/javascript/components/ (all components Vue 3 compatible)

Gemfile (updated):
  (removed: turbolinks)
```

### Testing Checklist
- [ ] Vue 3 migration guide reviewed
- [ ] Bootstrap 5 migration guide reviewed
- [ ] All 14 pages render correctly
- [ ] All Vue components work
- [ ] All forms submit
- [ ] All modals open/close
- [ ] All dropdowns work
- [ ] All tooltips display
- [ ] Import/export workflows work
- [ ] Rule editing works
- [ ] No console errors
- [ ] No Vue warnings
- [ ] All Vitest tests pass
- [ ] Visual QA complete

### Completion Criteria
✅ Vue 3 migration complete
✅ Bootstrap 5 migration complete
✅ Turbolinks removed
✅ All 14 pages working
✅ All functionality preserved
✅ No dependencies on deprecated packages
✅ Modern frontend foundation established

---

## PHASE 2: Database Redesign (8-12 hours) 🔴 DATA FOUNDATION

**NOW PHASE 2** - Was Phase 1

### Problem
- Components import 264 duplicate SRG rules (13 authored + 251 duplicates)
- Satisfaction relationships point Rule → Rule (should be Rule → SrgRule)
- Confusing counts, wasted storage, performance issues

### Solution
- New join table: `component_srg_satisfactions`
- Link Rules → SrgRules directly
- Remove 251 duplicate rules per component
- Components have 13 rules (authored only)

### Tasks
1. **Create migration** (1h)
   - New `component_srg_satisfactions` table
   - Foreign keys to base_rules (rules and srg_rules)
   - Unique index on [rule_id, srg_rule_id]

2. **Data migration script** (2-3h)
   - Migrate existing satisfactions to new table
   - Link to SrgRules instead of duplicate Rules
   - Remove duplicate SRG rules
   - Verify no data loss

3. **Update Component model** (2-3h)
   - New associations for `satisfied_srg_requirements`
   - Update `rules_summary` to use new relationships
   - Update count methods (`authored_controls_count`, etc.)
   - Keep backward compatibility during transition

4. **Update import methods** (2-3h)
   - `from_xccdf` uses new relationships
   - `from_spreadsheet` uses new relationships
   - `from_mapping` only imports what's needed
   - Don't create duplicates

5. **Testing** (2-3h)
   - Migration tests
   - Relationship tests
   - Import tests with new schema
   - UI verification

### Deliverables
```ruby
# app/models/component.rb
has_many :component_srg_satisfactions, through: :rules
has_many :satisfied_srg_requirements,
         through: :component_srg_satisfactions,
         source: :srg_rule

def authored_controls
  rules.where.not(type: 'SrgRule')
end

def authored_controls_count
  authored_controls.count  # Simple!
end
```

### Testing Checklist
- [ ] Migration runs without errors
- [ ] Data migration preserves all relationships
- [ ] Component.rules.count == 13 (not 264)
- [ ] UI shows 13 primary, 251 inherited, 263 total
- [ ] Import XCCDF creates correct relationships
- [ ] Import spreadsheet creates correct relationships
- [ ] Export → Import roundtrip works
- [ ] All 309+ tests pass
- [ ] RuboCop clean
- [ ] No N+1 queries

### Completion Criteria
✅ Database schema updated
✅ Data migrated successfully
✅ No duplicate SRG rules
✅ All tests pass
✅ Performance maintained or improved

---

## PHASE 2: Service Objects (15-20 hours)

### Problem
- Component model: 785 LOC (400+ LOC is import/export logic)
- ComponentsController: 430 LOC (business logic in controller)
- Business logic not reusable or testable in isolation

### Solution
- Extract to `app/services/` directory
- Establish service object pattern for all future features
- Component model → ~400 LOC
- ComponentsController → ~300 LOC

### Tasks
1. **Service infrastructure** (2-3h)
   - Create `app/services/` directory
   - Create `ApplicationService` base class
   - Create namespace structure (imports/, exports/, components/, projects/)
   - Document service pattern

2. **Extract import services** (5-7h)
   - `Imports::XccdfImportService` (135 LOC from Component)
   - `Imports::SpreadsheetImportService` (85 LOC from Component)
   - `Imports::SrgMappingService` (32 LOC from Component)
   - `Imports::BaseImportService` (shared logic)

3. **Extract export services** (3-4h)
   - `Exports::XccdfExportService`
   - `Exports::CsvExportService`
   - `Exports::BaseExportService` (shared logic)

4. **Extract component services** (3-4h)
   - `Components::DuplicationService` (76 LOC from Component)
   - `Components::SatisfactionParserService` (88 LOC from Component)

5. **Update controllers** (2-3h)
   - ComponentsController delegates to services
   - Remove business logic from controllers
   - Clean error handling

### Deliverables
```
app/services/
├── application_service.rb
├── imports/
│   ├── base_import_service.rb
│   ├── xccdf_import_service.rb
│   ├── spreadsheet_import_service.rb
│   └── srg_mapping_service.rb
├── exports/
│   ├── base_export_service.rb
│   ├── xccdf_export_service.rb
│   └── csv_export_service.rb
└── components/
    ├── duplication_service.rb
    └── satisfaction_parser_service.rb
```

### Testing Checklist
- [ ] Each service has comprehensive isolated tests
- [ ] Services return consistent results
- [ ] Import via service == import via old code
- [ ] Export via service == export via old code
- [ ] Component model reduced to ~400 LOC
- [ ] Controllers delegate cleanly to services
- [ ] All 320+ tests pass
- [ ] Service pattern documented

### Completion Criteria
✅ 8+ services created and tested
✅ Component model: 785 → ~400 LOC
✅ ComponentsController: 430 → ~300 LOC
✅ All functionality identical
✅ Service tests: 100% coverage

---

## PHASE 3: Pundit Authorization (8-12 hours)

### Problem
- 16 permission methods scattered across User model + ApplicationController
- Authorization logic duplicated
- Hard to test, hard to maintain
- ApplicationController: 245 LOC (god object)

### Solution
- Adopt Pundit gem (8,454 stars, Rails standard)
- Consolidate to 2 policy classes
- ApplicationController → ~100 LOC
- Single source of truth for permissions

### Tasks
1. **Pundit installation** (1h)
   - Add gem
   - Generate application_policy.rb
   - Configure ApplicationController
   - Add error handling

2. **Create policies** (4-6h)
   - ComponentPolicy (8 permission methods)
   - ProjectPolicy (8 permission methods)
   - Extract logic from User model
   - Extract logic from ApplicationController

3. **Update controllers** (2-3h)
   - Replace `authorize_admin_component` with `authorize @component`
   - Replace all custom authorization with `authorize`
   - Remove authorization methods from ApplicationController

4. **Clean up models** (1-2h)
   - Remove permission methods from User
   - Keep only data/relationship methods

### Deliverables
```ruby
# app/policies/application_policy.rb
class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index?
    false
  end

  def show?
    false
  end

  # ... base methods
end

# app/policies/component_policy.rb
class ComponentPolicy < ApplicationPolicy
  def show?
    user.admin? ||
    record.project.memberships.exists?(user: user)
  end

  def edit?
    author? || admin?
  end

  def update?
    edit?
  end

  def destroy?
    admin?
  end

  private

  def admin?
    user.admin? ||
    record.project.memberships.exists?(
      user: user,
      role: ['owner', 'admin']
    )
  end

  def author?
    record.project.memberships.exists?(
      user: user,
      role: ['owner', 'admin', 'author']
    )
  end
end

# app/policies/project_policy.rb
class ProjectPolicy < ApplicationPolicy
  # Similar structure
end
```

### Testing Checklist
- [ ] Pundit installed and configured
- [ ] ComponentPolicy has specs for all roles
- [ ] ProjectPolicy has specs for all roles
- [ ] All controllers use `authorize`
- [ ] Unauthorized access blocked correctly
- [ ] ApplicationController: 245 → ~100 LOC
- [ ] User model: permission methods removed
- [ ] All 330+ tests pass

### Completion Criteria
✅ Pundit gem integrated
✅ 2 policy classes created
✅ All controllers use policies
✅ 16 permission methods consolidated
✅ Policy tests: 100% coverage
✅ Authorization centralized

---

## PHASE 4: Query Objects (4-6 hours)

### Problem
- `Component#rules_summary` makes 10+ separate queries (N+1 risk)
- Complex queries scattered in models
- Performance issues at scale

### Solution
- Extract to `app/queries/` directory
- Optimize with single SQL queries
- Establish pattern for future complex queries

### Tasks
1. **Query infrastructure** (1h)
   - Create `app/queries/` directory
   - Create `ApplicationQuery` base class
   - Document query pattern

2. **Extract query objects** (2-3h)
   - `ComponentRulesSummaryQuery` (10+ queries → 1-2)
   - `ProjectDetailsQuery`
   - `RelatedRulesQuery`

3. **Update models** (1-2h)
   - Replace complex query methods with query objects
   - Keep simple scopes in models

### Deliverables
```ruby
# app/queries/application_query.rb
class ApplicationQuery
  def self.call(*args, **kwargs)
    new(*args, **kwargs).call
  end

  def call
    raise NotImplementedError
  end
end

# app/queries/component_rules_summary_query.rb
class ComponentRulesSummaryQuery < ApplicationQuery
  def initialize(component)
    @component = component
  end

  def call
    {
      total: @component.security_requirements_guide.srg_rules.count,
      primary: @component.authored_controls.count,
      inherited: @component.satisfied_srg_requirements.distinct.count,
      by_status: by_status_counts,
      by_severity: by_severity_counts,
      by_rule_weight: by_rule_weight_counts
    }
  end

  private

  def by_status_counts
    @component.rules
      .group(:status)
      .count
  end

  def by_severity_counts
    @component.rules
      .joins(:srg_rule)
      .group('base_rules.severity')
      .count
  end

  def by_rule_weight_counts
    @component.rules
      .group(:rule_weight)
      .count
  end
end
```

### Testing Checklist
- [ ] Query objects return correct results
- [ ] Query count reduced (10+ → 2-3)
- [ ] No N+1 queries (Bullet gem verification)
- [ ] Performance improved (benchmark tests)
- [ ] All 330+ tests pass

### Completion Criteria
✅ 3-4 query objects created
✅ N+1 queries eliminated
✅ Performance measurably improved
✅ Query tests: 100% coverage

---

## PHASE 5: Blueprinter Serialization (6-8 hours)

### Problem
- 5 models with `as_json` methods (50+ LOC)
- Inconsistent JSON responses
- Hard to maintain, hard to version

### Solution
- Adopt Blueprinter gem
- Consistent serialization pattern
- Different views for list/detail contexts
- Foundation for API layer

### Tasks
1. **Blueprinter installation** (1h)
   - Add gem
   - Create `app/blueprints/` directory
   - Create `ApplicationBlueprint` base class

2. **Create blueprints** (3-4h)
   - ComponentBlueprint (list/detail views)
   - RuleBlueprint
   - ProjectBlueprint
   - ReviewBlueprint
   - MembershipBlueprint

3. **Update controllers** (1-2h)
   - Replace `to_json` with `Blueprint.render`
   - Remove `as_json` methods from models

4. **Testing** (1-2h)
   - Blueprint specs
   - JSON structure validation

### Deliverables
```
app/blueprints/
├── application_blueprint.rb
├── component_blueprint.rb
├── rule_blueprint.rb
├── project_blueprint.rb
├── review_blueprint.rb
└── membership_blueprint.rb
```

### Testing Checklist
- [ ] All blueprints have specs
- [ ] JSON output matches previous format
- [ ] List views exclude associations
- [ ] Detail views include associations
- [ ] All API endpoints work
- [ ] All 340+ tests pass

### Completion Criteria
✅ Blueprinter gem installed
✅ 5+ blueprints created
✅ All `as_json` methods removed
✅ Consistent JSON responses
✅ Blueprint tests: 95% coverage

---

## PHASE 6: Full API Layer (20-30 hours)

### Problem
- No versioned API
- No token authentication for external clients
- No rate limiting
- No API documentation

### Solution
- `/api/v1/` namespace
- Token-based authentication
- Rate limiting with Rack::Attack
- CORS configuration
- Swagger documentation

### Tasks
1. **API namespace setup** (3-4h)
   - Create `/api/v1/` routes
   - Base API controller
   - Error handling standardization

2. **Authentication** (4-5h)
   - Add `api_token` to users
   - Token generation/regeneration
   - Bearer token authentication
   - Token UI management

3. **API controllers** (6-8h)
   - ComponentsController
   - ProjectsController
   - RulesController
   - SecurityRequirementsGuidesController
   - StigsController

4. **Rate limiting** (2-3h)
   - Configure Rack::Attack
   - Token-based throttling (100/min)
   - IP-based throttling (20/min)
   - Test rate limits

5. **CORS configuration** (1-2h)
   - Allow external domains
   - Configure allowed methods
   - Credentials handling

6. **API documentation** (4-6h)
   - Install rswag
   - Swagger specs for all endpoints
   - Generate documentation
   - UI at `/api-docs`

### Deliverables
```
app/controllers/api/v1/
├── base_controller.rb
├── components_controller.rb
├── projects_controller.rb
├── rules_controller.rb
├── security_requirements_guides_controller.rb
└── stigs_controller.rb

config/initializers/
├── cors.rb
└── rack_attack_api.rb

spec/swagger/
└── api/v1/
    ├── components_spec.rb
    ├── projects_spec.rb
    └── ...
```

### Testing Checklist
- [ ] All API endpoints tested
- [ ] Authentication works
- [ ] Unauthorized requests blocked
- [ ] Rate limiting enforced
- [ ] CORS headers correct
- [ ] Swagger docs validate
- [ ] API versioning works
- [ ] All 360+ tests pass

### Completion Criteria
✅ Full REST API at `/api/v1/`
✅ Token authentication working
✅ Rate limiting configured
✅ CORS enabled
✅ Swagger documentation complete
✅ API tests: 95% coverage

---

## PHASE 7: Update from File (2-3 hours)

### Problem
- Users can export but can't re-import to update
- Must create new component for every edit
- No workflow for external editing (Excel, scripts, etc.)

### Solution
- Add "update" mode to import services
- Match existing rules by version/ID
- Update existing, add new, preserve unchanged
- UI button "Update from File"

### Tasks
1. **Update import services** (1-2h)
   - Add `update` method to XccdfImportService
   - Add `update` method to SpreadsheetImportService
   - Match rules by version
   - Update existing, create missing

2. **Controller action** (30min)
   - `update_from_file` action
   - File upload handling
   - Service delegation

3. **UI component** (30min)
   - "Update from File" button
   - File upload modal
   - Success/error handling

### Deliverables
```ruby
# app/services/imports/xccdf_import_service.rb
def update(component, file)
  parsed = parse_xccdf(file)

  parsed.groups.each do |group|
    version = extract_version(group)
    existing_rule = component.rules.find_by(version: version)

    if existing_rule
      update_rule(existing_rule, group)
    else
      create_rule(component, group)
    end
  end

  sync_satisfactions(component, parsed)
end
```

### Testing Checklist
- [ ] Update from modified XCCDF works
- [ ] Update from modified spreadsheet works
- [ ] Existing rules updated
- [ ] New rules added
- [ ] Removed rules handled correctly
- [ ] Satisfactions updated
- [ ] All 365+ tests pass

### Completion Criteria
✅ Update from file working
✅ Roundtrip tested (export → edit → update)
✅ Data preserved correctly
✅ UI button functional

---

## PHASE 8: Project Backup/Restore (3-4 hours)

### Problem
- No way to backup entire project
- Can't migrate projects between Vulcan instances
- No disaster recovery

### Solution
- Export project to ZIP (metadata + all components)
- Import ZIP to restore project
- Works across Vulcan instances

### Tasks
1. **Backup service** (1-2h)
   - `Projects::BackupService`
   - ZIP with project.json + components/*.xml + memberships.json
   - Use existing export services

2. **Restore service** (1-2h)
   - `Projects::RestoreService`
   - Parse ZIP, create project, import components
   - Restore memberships
   - Use existing import services

3. **UI buttons** (30min)
   - "Export Full Backup" dropdown item
   - "Restore from Backup" button
   - File upload handling

### Deliverables
```ruby
# app/services/projects/backup_service.rb
def call
  Zip::OutputStream.write_buffer do |zip|
    zip.put_next_entry('project.json')
    zip.write(project_metadata.to_json)

    @project.components.each do |component|
      zip.put_next_entry("components/#{component.prefix}.xml")
      zip.write(Exports::XccdfExportService.call(component))
    end

    zip.put_next_entry('memberships.json')
    zip.write(memberships_data.to_json)
  end.string
end

# app/services/projects/restore_service.rb
def call
  Zip::File.open(@zip_file.path) do |zip|
    metadata = JSON.parse(zip.read('project.json'))
    @project = Project.create!(metadata)

    zip.glob('components/*.xml').each do |entry|
      component = @project.components.new
      Imports::XccdfImportService.call(component, entry)
    end

    restore_memberships(zip)
  end
end
```

### Testing Checklist
- [ ] Backup creates valid ZIP
- [ ] Restore creates identical project
- [ ] All components imported
- [ ] All rules preserved
- [ ] Memberships restored
- [ ] Works across instances
- [ ] All 370+ tests pass

### Completion Criteria
✅ Backup service working
✅ Restore service working
✅ Roundtrip tested
✅ Cross-instance verified

---

## PHASE 9: mavonEditor Integration (4-6 hours)

### Problem
- Large text fields are plain textareas
- No markdown support
- No formatting, no preview
- Poor UX for writing vuln_discussion, fixtext, etc.

### Solution
- Add mavonEditor (Vue 2 markdown editor)
- Replace 4 key textareas with rich markdown editor
- Toolbar with formatting options
- Live preview
- Works with Vue 2 (before Vue 3 migration)

### Tasks
1. **Install mavonEditor** (15min)
   ```bash
   yarn add mavon-editor
   ```

2. **Create RichMarkdownEditor component** (1h)
   ```vue
   <!-- app/javascript/components/shared/RichMarkdownEditor.vue -->
   <template>
     <mavon-editor
       :value="value"
       :editable="!disabled"
       :toolbars="toolbarConfig"
       :subfield="false"
       language="en"
       @change="$emit('input', $event)"
     />
   </template>

   <script>
   import { mavonEditor } from 'mavon-editor'
   import 'mavon-editor/dist/css/index.css'

   export default {
     components: { mavonEditor },
     props: {
       value: String,
       disabled: Boolean
     },
     data() {
       return {
         toolbarConfig: {
           bold: true, italic: true, header: true,
           ol: true, ul: true, code: true, table: true,
           link: true, imagelink: true,
           fullscreen: true, preview: true,
           undo: true, redo: true
         }
       }
     }
   }
   </script>
   ```

3. **Replace 4 key textareas** (2-3h)
   - `vuln_discussion` in DisaRuleDescriptionForm.vue
   - `mitigations` in DisaRuleDescriptionForm.vue
   - `fixtext` in RuleForm.vue
   - `potential_impacts` in DisaRuleDescriptionForm.vue

   ```vue
   <!-- BEFORE -->
   <b-form-textarea
     :value="description.vuln_discussion"
     rows="10"
     @input="$root.$emit('update:disaDescription', ...)"
   />

   <!-- AFTER -->
   <RichMarkdownEditor
     :value="description.vuln_discussion"
     :disabled="disabled"
     @input="$root.$emit('update:disaDescription', ...)"
   />
   ```

4. **Test save/load/export** (1h)
   - Create rule with markdown formatting
   - Save and reload - verify markdown preserved
   - Export to XCCDF - verify markdown in XML
   - Export to CSV - verify markdown in cells
   - Import back - verify markdown intact

5. **Write Vitest tests** (1h)
   ```javascript
   // spec/javascript/components/RichMarkdownEditor.spec.js
   import { mount } from '@vue/test-utils'
   import RichMarkdownEditor from '@/components/shared/RichMarkdownEditor.vue'

   describe('RichMarkdownEditor', () => {
     it('renders mavonEditor', () => {
       const wrapper = mount(RichMarkdownEditor, {
         propsData: { value: '# Test' }
       })
       expect(wrapper.find('.v-note-wrapper').exists()).toBe(true)
     })

     it('emits input on change', () => {
       const wrapper = mount(RichMarkdownEditor)
       wrapper.vm.$emit('input', 'new value')
       expect(wrapper.emitted('input')[0][0]).toBe('new value')
     })
   })
   ```

### Deliverables
```
app/javascript/components/shared/
└── RichMarkdownEditor.vue

Updated components:
- DisaRuleDescriptionForm.vue (3 fields)
- RuleForm.vue (1 field)

package.json:
+ mavon-editor: ^2.10.4
```

### Testing Checklist
- [ ] mavonEditor displays correctly
- [ ] Toolbar buttons work
- [ ] Preview pane works
- [ ] Markdown formatting saves correctly
- [ ] Export preserves markdown
- [ ] Import preserves markdown
- [ ] Works in all 4 fields
- [ ] Disabled state works
- [ ] No console errors
- [ ] Vitest tests pass

### Completion Criteria
✅ mavonEditor installed
✅ RichMarkdownEditor component created
✅ 4 textareas replaced
✅ Markdown editing works
✅ Save/load/export preserves markdown
✅ Tests pass

---

## PHASE 10: Vue 3 + Bootstrap 5 Migration (30-40 hours)

### Problem
- Vue 2 is end-of-life (EOL December 2023)
- Bootstrap 4 is outdated
- Bootstrap-Vue 2 is unmaintained
- Missing modern Vue features (Composition API, etc.)
- Security vulnerabilities accumulating

### Solution
- Migrate to Vue 3.5+
- Migrate to Bootstrap 5.3+
- Use native Bootstrap 5 (NOT Bootstrap-Vue-Next)
- Keep 14 separate Vue instances (don't consolidate to SPA)
- Migrate page-by-page for stability

### Tasks

#### 1. **Preparation and Research** (4-6h)
- Review all 14 Vue instances
- Identify Bootstrap-Vue components used
- Research Bootstrap 5 native equivalents
- Create component migration map
- Test critical components in isolation

#### 2. **Dependencies Update** (1h)
```bash
# Remove Vue 2 and Bootstrap 4
yarn remove vue@2 bootstrap-vue bootstrap@4 vue-turbolinks

# Add Vue 3 and Bootstrap 5
yarn add vue@3 bootstrap@5
yarn add @popperjs/core # Required by Bootstrap 5

# Update build config
# Update esbuild.config.js for Vue 3
```

#### 3. **Turbolinks Removal** (2-3h)
- Remove turbolinks gem
- Remove vue-turbolinks
- Update all `turbolinks:load` event listeners
- Use native `DOMContentLoaded` or Vue 3 mounting
- Test page transitions

#### 4. **Page-by-Page Migration** (2-3h × 14 pages = 28-42h)

**Migration order (by complexity):**
1. `toaster.js` (simplest)
2. `navbar.js` (simple)
3. `projects.js` (list page)
4. `project.js` (detail page)
5. `security_requirements_guides.js`
6. `stigs.js`
7. `components.js` (list page)
8. `component.js` (detail page)
9. `project_components.js`
10. `project_component.js`
11. `rule.js` (most complex - rule editing)
12. `advanced_rule.js`
13. `basic_rule.js`
14. `application.js` (base setup)

**For each page:**
- Update to Vue 3 createApp syntax
- Replace Bootstrap-Vue components with Bootstrap 5 native
- Update Bootstrap 4 classes → Bootstrap 5 (left→start, right→end)
- Replace `v-b-tooltip` with native Bootstrap tooltips
- Replace `v-b-modal` with native Bootstrap modals
- Test all functionality
- Fix breaking changes
- Commit when working

**Example migration:**
```javascript
// BEFORE (Vue 2)
import Vue from 'vue'
import VueTurbolinks from 'vue-turbolinks'
import { BootstrapVue } from 'bootstrap-vue'

Vue.use(VueTurbolinks)
Vue.use(BootstrapVue)

document.addEventListener('turbolinks:load', () => {
  new Vue({
    el: '#projects-app',
    data: { ... },
    methods: { ... }
  })
})

// AFTER (Vue 3)
import { createApp } from 'vue'
import ProjectsApp from './ProjectsApp.vue'

document.addEventListener('DOMContentLoaded', () => {
  const app = createApp(ProjectsApp)
  app.mount('#projects-app')
})
```

**Bootstrap-Vue to Bootstrap 5 mapping:**
```vue
<!-- BEFORE (Bootstrap-Vue) -->
<b-button variant="primary" @click="handleClick">Click</b-button>
<b-modal v-model="showModal" title="Edit">...</b-modal>
<b-table :items="items" :fields="fields"></b-table>
<b-form-input v-model="name"></b-form-input>

<!-- AFTER (Bootstrap 5 native) -->
<button class="btn btn-primary" @click="handleClick">Click</button>
<div class="modal" :class="{ show: showModal }">...</div>
<table class="table">...</table>
<input class="form-control" v-model="name">
```

#### 5. **Component Updates** (4-6h)
- Update all Vue components for Vue 3 compatibility
- Remove Bootstrap-Vue component imports
- Use Bootstrap 5 native markup
- Update event handling ($emit changes)
- Update v-model syntax (breaking change in Vue 3)

**Vue 3 breaking changes to handle:**
```javascript
// v-model
// Vue 2: v-model
// Vue 3: v-model (works differently)

// $listeners removed
// Vue 2: v-on="$listeners"
// Vue 3: Merged with $attrs

// Filters removed
// Vue 2: {{ date | formatDate }}
// Vue 3: {{ formatDate(date) }} (use methods)
```

#### 6. **Icons Migration** (2-3h)
- Bootstrap icons already in use ✅
- Verify all icons work with Bootstrap 5
- Update any icon markup if needed

#### 7. **Testing** (6-8h)
- Test every page thoroughly
- Test all workflows (import, export, edit, review)
- Test all forms (create, update, delete)
- Test modals, dropdowns, tooltips
- Test responsive layouts
- Fix any breaking changes
- Visual regression testing

#### 8. **CSS/SCSS Updates** (2-3h)
- Update Bootstrap 4 → 5 class names
- Fix any layout issues
- Update custom SCSS for Bootstrap 5 variables
- Test responsive breakpoints

### Deliverables
```
package.json:
- vue: ^3.5.0
- bootstrap: ^5.3.0
- @popperjs/core: ^2.11.0
(removed: vue@2, bootstrap-vue, bootstrap@4, vue-turbolinks)

app/javascript/packs/ (all 14 updated to Vue 3)
app/javascript/components/ (all updated to Vue 3)

Gemfile:
(removed: turbolinks)
```

### Testing Checklist
- [ ] All 14 pages render correctly
- [ ] All Vue components work
- [ ] All forms submit correctly
- [ ] All modals open/close
- [ ] All dropdowns work
- [ ] All tooltips display
- [ ] Responsive layouts work
- [ ] No console errors
- [ ] No Vue warnings
- [ ] All Vitest tests pass
- [ ] All workflows tested (import, export, edit)

### Completion Criteria
✅ Vue 3 migration complete
✅ Bootstrap 5 migration complete
✅ Turbolinks removed
✅ All 14 pages working
✅ All components migrated
✅ No Bootstrap-Vue dependencies
✅ Tests comprehensive
✅ Visual QA passed

---

## Overall Completion Metrics (ALL 10 PHASES)

### Code Quality
- Component model: 785 LOC → ~400 LOC (49% reduction)
- ApplicationController: 245 LOC → ~100 LOC (59% reduction)
- ComponentsController: 430 LOC → ~200 LOC (53% reduction)
- Total LOC reduced: ~760 LOC
- Frontend: Vue 2 → Vue 3, Bootstrap 4 → Bootstrap 5

### Test Coverage
- Starting: 309 tests
- After Phase 8: ~370+ tests
- After Phase 9: ~375+ tests (Vitest for mavonEditor)
- After Phase 10: ~400+ tests (Vue 3 component tests)
- Coverage: >90% overall
- Service tests: 100% coverage
- Policy tests: 100% coverage
- Query tests: 100% coverage
- Blueprint tests: 95% coverage
- API tests: 95% coverage
- Vue component tests: 85% coverage

### Patterns Established
- ✅ Service objects (`app/services/`)
- ✅ Policy objects (`app/policies/`)
- ✅ Query objects (`app/queries/`)
- ✅ Blueprints (`app/blueprints/`)
- ✅ API controllers (`app/controllers/api/v1/`)
- ✅ Vue 3 Composition API
- ✅ Bootstrap 5 native components

### Features Delivered
- ✅ Clean database (no duplicates)
- ✅ Import/export refactored
- ✅ Authorization centralized
- ✅ Performance optimized
- ✅ Full REST API
- ✅ Update from file
- ✅ Project backup/restore
- ✅ Markdown editing (mavonEditor)
- ✅ Modern frontend (Vue 3 + Bootstrap 5)

---

## Complete Timeline Summary (FRONTEND FIRST)

| Week | Days | Phases | Hours | Cumulative |
|------|------|--------|-------|------------|
| 1 | Mon-Fri | Phase 1: Vue 3 + BS5 | 30-40h | 30-40h |
| 2 | Mon-Tue | Phase 2: Database | 8-12h | 38-52h |
| 2 | Wed-Fri | Phase 3: Services | 15-20h | 53-72h |
| 3 | Mon-Tue | Phase 4: Pundit | 8-12h | 61-84h |
| 3 | Wed | Phase 5: Queries | 4-6h | 65-90h |
| 3 | Thu | Phase 6: Blueprinter | 6-8h | 71-98h |
| 4 | Mon-Thu | Phase 7: API | 20-30h | 91-128h |
| 4 | Fri AM | Phase 8: Update | 2-3h | 93-131h |
| 4 | Fri PM | Phase 9: Backup | 3-4h | 96-135h |
| 5 | Mon | Phase 10: md-editor-v3 | 4-6h | 100-141h |

**Total: 4-5 weeks of focused, quality work on MODERN stack**

---

## Success Criteria

When all 8 phases are complete:

### Technical Excellence
- [ ] All tests pass (370+ examples)
- [ ] RuboCop clean (0 offenses)
- [ ] Brakeman clean (0 security issues)
- [ ] No N+1 queries (Bullet verification)
- [ ] Test coverage >90%

### Code Quality
- [ ] Component model <400 LOC
- [ ] ApplicationController <100 LOC
- [ ] ComponentsController <200 LOC
- [ ] All patterns documented

### Functionality
- [ ] All existing features work
- [ ] Import/export work
- [ ] Update from file works
- [ ] Backup/restore works
- [ ] Full API functional

### Foundation Established
- [ ] Service pattern documented and used
- [ ] Policy pattern documented and used
- [ ] Query pattern documented and used
- [ ] Blueprint pattern documented and used
- [ ] API pattern documented and used

---

## After Completion

### You Can Build Features 3x Faster:
- "Add PDF export" → Create service (pattern exists)
- "Add new permission" → Add to policy (pattern exists)
- "Optimize slow query" → Create query object (pattern exists)
- "Add API endpoint" → Add to /api/v1/ (pattern exists)

### You Can Fix Bugs 2x Faster:
- Business logic isolated in services (easy to test)
- Permissions centralized (easy to debug)
- Queries optimized (easy to troubleshoot)

### You Have Best-Practice Foundation:
- Following Rails community standards
- Using proven gems (Pundit, Blueprinter)
- Patterns established for all future work
- Code is maintainable, testable, scalable

---

**This is the complete plan for the best possible foundation.**
