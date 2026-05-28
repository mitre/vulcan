# Import/Export Architecture Refactor Plan

**Created:** 2025-11-26
**Goal:** Clean up satisfaction relationship architecture without breaking existing functionality
**Estimated Time:** 8-12 hours over 2-3 days

---

## Current Problems

1. **Duplicate Data:** Components import 251 SRG requirements as Rules (should link to SrgRules)
2. **Confusing Counts:** 264 total rules (13 authored + 251 duplicates) instead of 13
3. **Mixed Concepts:** base_rules table holds SrgRule, Rule, StigRule (STI confusion)
4. **Import Complexity:** Different logic for XLSX vs XCCDF with subtle bugs

---

## Target Architecture

```
Component (13 authored controls)
  ├── Rule (authored control)
  │   ├── belongs_to :primary_srg_requirement (SrgRule)
  │   └── satisfies → SrgRule (not Rule!)
  │
  └── Shows in UI:
      - 13 Primary Controls (authored)
      - 251 Satisfied Requirements (via satisfies relationships)
      - 263 Total Requirements (from linked SRG)
```

**Key Change:** Satisfactions point to SrgRules (templates), not imported Rule duplicates

---

## PHASE 1: Foundation (No Breaking Changes)

**Goal:** Add new helpers alongside existing code
**Duration:** 1-2 hours
**Risk:** Low (only additions)

### 1.1 Add Query Helpers (30 min)

**File:** `app/models/rule.rb`

```ruby
# New helper methods (don't change existing)
def satisfied_srg_requirements
  # Get SRG requirements this control satisfies
  satisfies.includes(:srg_rule).map(&:srg_rule).compact
end

def satisfied_srg_versions
  # Get SRG versions (SRG-OS-000023, etc.)
  satisfied_srg_requirements.map(&:version)
end
```

**File:** `app/models/component.rb`

```ruby
# New helper methods (don't change existing)
def total_srg_requirements_count
  # Total requirements in the linked SRG
  security_requirements_guide.srg_rules.count
end

def satisfied_srg_requirements_count
  # How many SRG requirements are satisfied by authored controls
  SrgRule.joins("INNER JOIN rule_satisfactions ON base_rules.id = rule_satisfactions.rule_id")
         .joins("INNER JOIN base_rules AS rules ON rules.id = rule_satisfactions.satisfied_by_rule_id")
         .where("rules.component_id = ?", id)
         .where("base_rules.type = 'SrgRule'")
         .distinct
         .count
end

def unsatisfied_srg_requirements_count
  total_srg_requirements_count - satisfied_srg_requirements_count
end

def authored_controls
  # Only the controls we actually wrote (not imported SRG templates)
  rules.where(status: 'Applicable - Configurable')
end

def authored_controls_count
  authored_controls.count
end
```

**Tests:** `spec/models/component_refactor_spec.rb`
```ruby
RSpec.describe 'Component Refactor Helpers' do
  it 'calculates total SRG requirements' do
    # Create component based on OS Core SRG (263 requirements)
    # Verify total_srg_requirements_count == 263
  end

  it 'counts satisfied SRG requirements' do
    # Import Container SRG (13 controls satisfy 251 requirements)
    # Verify satisfied_srg_requirements_count == 251
  end

  it 'counts authored controls only' do
    # Verify authored_controls_count == 13 (not 264)
  end
end
```

**Validation:**
- Run new tests: `bundle exec rspec spec/models/component_refactor_spec.rb`
- Verify counts match current UI
- All existing tests still pass

---

### 1.2 Create Import Adapters (1-2 hours)

**Directory:** `app/services/importers/`

**File:** `app/services/importers/base_importer.rb`
```ruby
module Importers
  class BaseImporter
    attr_reader :component, :errors

    def initialize(component)
      @component = component
      @errors = []
    end

    def import(file)
      raise NotImplementedError
    end

    protected

    def parse_satisfactions_from_text(text)
      # Extract "Satisfies: SRG-1, SRG-2" or "Satisfied By: CTRL-1"
      # Return { clean_text:, satisfies:, satisfied_by: }
    end

    def create_satisfaction_relationships(rule, srg_ids)
      # Find SRG requirements and link them
    end
  end
end
```

**File:** `app/services/importers/xccdf_importer.rb`
```ruby
module Importers
  class XCCDFImporter < BaseImporter
    def import(file)
      parsed = Xccdf::Benchmark.parse(file.read)

      # Extract all SRG IDs from "Satisfies:" lists
      all_srg_ids = extract_all_satisfies(parsed)

      # Import ONLY the SRG requirements mentioned (not all 263!)
      import_satisfied_srg_requirements(all_srg_ids)

      # Import authored controls
      import_authored_controls(parsed)

      # Create satisfaction relationships
      create_all_satisfactions(parsed)

      true
    rescue StandardError => e
      @errors << e.message
      false
    end

    private

    def extract_all_satisfies(parsed)
      # Parse all "Satisfies:" from all groups
    end

    def import_satisfied_srg_requirements(srg_ids)
      # Import ONLY the SRG requirements mentioned
      # Use from_mapping with filtered list
    end

    def import_authored_controls(parsed)
      # Create the 13 authored controls
    end

    def create_all_satisfactions(parsed)
      # Link authored controls to SRG requirements
    end
  end
end
```

**File:** `app/services/importers/spreadsheet_importer.rb`
```ruby
module Importers
  class SpreadsheetImporter < BaseImporter
    def import(file)
      # Similar pattern to XCCDFImporter
      # Parse spreadsheet
      # Import satisfied SRG requirements
      # Import authored controls
      # Create satisfactions from vendor_comments
    end
  end
end
```

**Tests:** `spec/services/importers/xccdf_importer_spec.rb`
```ruby
RSpec.describe Importers::XCCDFImporter do
  it 'imports XCCDF file' do
    component = create_component
    importer = Importers::XCCDFImporter.new(component)

    file = load_xccdf_file
    result = importer.import(file)

    expect(result).to be true
    expect(component.rules.count).to eq(264)
    expect(component.authored_controls_count).to eq(13)
  end
end
```

**Validation:**
- Run adapter tests
- Compare adapter import to current import (should be identical)
- All existing tests still pass

---

## PHASE 2: Database Migration (Controlled Change)

**Goal:** Clean up duplicate SRG requirement imports
**Duration:** 2-4 hours
**Risk:** Medium (data migration)

### 2.1 Create Migration (30 min)

**File:** `db/migrate/YYYYMMDD_add_control_satisfies_srg_requirements.rb`
```ruby
class AddControlSatisfiesSrgRequirements < ActiveRecord::Migration[8.0]
  def up
    # Create new join table linking Rules to SrgRules directly
    create_table :control_satisfies_srg_requirements, id: false do |t|
      t.bigint :rule_id, null: false
      t.bigint :srg_rule_id, null: false
      t.timestamps
    end

    add_index :control_satisfies_srg_requirements, [:rule_id, :srg_rule_id],
              unique: true,
              name: 'index_control_satisfies_on_rule_and_srg'
  end

  def down
    drop_table :control_satisfies_srg_requirements
  end
end
```

**Run:** `bundle exec rails db:migrate`
**Validation:** Migration runs without errors

---

### 2.2 Data Migration Script (1-2 hours)

**File:** `lib/tasks/migrate_satisfactions.rake`
```ruby
namespace :data do
  desc "Migrate satisfaction relationships to point to SrgRules"
  task migrate_satisfactions: :environment do
    Component.find_each do |component|
      puts "Processing component: #{component.name}"

      # Find authored controls (status = AC)
      authored = component.rules.where(status: 'Applicable - Configurable')

      authored.each do |control|
        # Current: control.satisfies points to imported Rule duplicates
        # New: Should point to SrgRules directly

        control.satisfies.each do |satisfied_rule|
          # Get the SRG rule this points to
          srg_rule = satisfied_rule.srg_rule

          if srg_rule
            # Create new relationship directly to SrgRule
            ControlSatisfiesSrgRequirement.create!(
              rule_id: control.id,
              srg_rule_id: srg_rule.id
            )
          end
        end
      end

      puts "  Migrated #{authored.count} controls"
    end

    puts "Migration complete!"
  end
end
```

**Run:** `bundle exec rails data:migrate_satisfactions`
**Validation:**
- Check row counts before/after
- Verify relationships preserved
- No data loss

---

### 2.3 Add Model Support for New Table (30 min)

**File:** `app/models/rule.rb`
```ruby
# Add new association (keep old one for now)
has_and_belongs_to_many :satisfies_srg_requirements,
                        class_name: 'SrgRule',
                        join_table: :control_satisfies_srg_requirements,
                        foreign_key: :rule_id,
                        association_foreign_key: :srg_rule_id

# Alias for backwards compatibility
alias_method :satisfies_old, :satisfies
def satisfies
  # During transition, return combined results
  satisfies_old + satisfies_srg_requirements.map { |srg|
    # Wrap SrgRule to look like Rule for compatibility
    OpenStruct.new(version: srg.version, srg_rule: srg)
  }
end
```

**Tests:**
```ruby
it 'satisfies returns both old and new relationships' do
  # Test that existing code still works during transition
end
```

**Validation:**
- UI still shows correct counts
- No breaking changes visible to users
- All tests pass

---

### 2.4 Remove Duplicate SRG Import Rules (1 hour)

**File:** `lib/tasks/cleanup_duplicate_srgs.rake`
```ruby
namespace :data do
  desc "Remove duplicate imported SRG requirements"
  task cleanup_duplicate_srgs: :environment do
    Component.find_each do |component|
      # Find imported SRG template rules (NYD status, empty content)
      duplicates = component.rules.where(
        status: 'Not Yet Determined',
        component_id: component.id
      ).where("fixtext IS NULL OR fixtext = ''")

      count = duplicates.count
      duplicates.destroy_all

      puts "Component #{component.name}: removed #{count} duplicate SRG rules"
    end
  end
end
```

**Run:** `bundle exec rails data:cleanup_duplicate_srgs`
**Validation:**
- Component rule counts drop from 264 → 13
- UI still shows 263 total (from SRG helper)
- Satisfactions still work

---

## PHASE 3: Update Imports to Use New Architecture

**Goal:** Switch imports to new adapter pattern
**Duration:** 2-3 hours
**Risk:** Medium (changing import logic)

### 3.1 Update from_xccdf to Use Adapter (1 hour)

**File:** `app/models/component.rb`
```ruby
def from_xccdf(file)
  # OLD CODE (commented out, kept for reference):
  # from_mapping(srg, satisfied_srg_ids, 0)
  # Import 251 duplicate SRG rules...

  # NEW CODE:
  importer = Importers::XCCDFImporter.new(self)
  result = importer.import(file)

  if !result
    importer.errors.each { |err| errors.add(:base, err) }
  end

  result
end
```

**Tests:**
```ruby
it 'XCCDF import matches old behavior' do
  # Import same file with new code
  # Verify counts: 13 authored + 251 satisfied via relationships
  # Verify all data present
end
```

**Validation:**
- Import Container XCCDF
- Verify: 13 rules (not 264!)
- Verify: UI still shows 263 total (from helper)
- All tests pass

---

### 3.2 Update from_spreadsheet to Use Adapter (1 hour)

**File:** `app/models/component.rb`
```ruby
def from_spreadsheet(file)
  # Same pattern - switch to adapter
  importer = Importers::SpreadsheetImporter.new(self)
  importer.import(file)
end
```

**Tests:** Same validation as XCCDF

---

### 3.3 Update UI Count Methods (30 min)

**File:** `app/models/component.rb`
```ruby
# REPLACE old primary_controls_count
def primary_controls_count
  # OLD: total - nested (counts duplicates!)
  # active_rules = rules.where(deleted_at: nil)
  # total = active_rules.count
  # nested = active_rules.joins(:satisfied_by).distinct.count
  # total - nested

  # NEW: Just count authored controls
  authored_controls_count
end

# REPLACE rules_summary
def rules_summary
  {
    total: total_srg_requirements_count,  # From SRG, not rule count!
    primary_count: authored_controls_count,  # Authored only
    nested_count: satisfied_srg_requirements_count,  # Via relationships
    # ... rest stays same
  }
end
```

**Tests:**
```ruby
it 'shows correct counts after refactor' do
  # Import Container SRG
  # Verify primary_count == 13
  # Verify total == 263
  # Verify nested == 251
end
```

**Validation:**
- Component cards show same numbers as before
- Metrics dashboard unchanged from user perspective

---

## PHASE 4: Cleanup Old Code

**Goal:** Remove deprecated code
**Duration:** 1-2 hours
**Risk:** Low (everything tested)

### 4.1 Remove Old Satisfaction Table (30 min)

**Migration:**
```ruby
class RemoveOldRuleSatisfactions < ActiveRecord::Migration[8.0]
  def up
    drop_table :rule_satisfactions
  end
end
```

**Before running:**
- Verify new table has all data
- Backup database
- Test rollback procedure

---

### 4.2 Remove Old Import Code (30 min)

**File:** `app/models/component.rb`
```ruby
# DELETE:
# - Old from_xccdf implementation
# - Old from_spreadsheet implementation
# - Compatibility shims

# KEEP:
# - New adapter-based imports
```

---

### 4.3 Final Tests (1 hour)

**Create:** `spec/integration/import_export_roundtrip_spec.rb`
```ruby
RSpec.describe 'Import/Export Round Trip' do
  it 'XLSX → XCCDF → XLSX preserves data' do
    # Import XLSX
    # Export to XCCDF
    # Import XCCDF
    # Export to XLSX
    # Compare: all data matches
  end

  it 'XCCDF → XLSX → XCCDF preserves data' do
    # Same but reverse order
  end
end
```

---

## Validation Checklist

**After Each Phase:**
- [ ] All existing tests pass (309 examples)
- [ ] Manual test: Import Container XLSX
- [ ] Manual test: Import Container XCCDF
- [ ] Manual test: Export to both formats
- [ ] UI shows correct counts
- [ ] No data loss
- [ ] No duplicate rules created

---

## Rollback Plan

**If Phase 2 fails:**
```bash
# Restore from migration
bundle exec rails db:rollback STEP=1

# Restore data
bundle exec rails db:restore_from_backup
```

**If Phase 3 fails:**
```bash
# Revert commits
git revert <commit-hash>

# Re-run old import logic
```

---

## Success Criteria

**Before refactor:**
- Component has 264 rules (13 authored + 251 imported duplicates)
- primary_controls_count = 13 (calculated via joins)
- Satisfactions: Rule → Rule

**After refactor:**
- Component has 13 rules (authored only)
- authored_controls_count = 13 (simple count)
- total shown in UI = 263 (from SRG helper)
- Satisfactions: Rule → SrgRule (no duplicates)

**User sees NO DIFFERENCE in UI - same counts, same functionality**

---

## Timeline

**Day 1 (2-3 hours):**
- Phase 1: Add helpers and adapters
- Test adapters match current behavior
- Commit: "Add satisfaction query helpers and import adapters"

**Day 2 (3-4 hours):**
- Phase 2: Database migration
- Migrate data to new table
- Remove duplicate SRG imports
- Commit: "Migrate satisfactions to point to SrgRules directly"

**Day 3 (2-3 hours):**
- Phase 3: Switch to adapter pattern
- Update UI helpers
- Commit: "Use import adapters and clean satisfaction architecture"

**Day 4 (1-2 hours):**
- Phase 4: Cleanup and final tests
- Remove old code
- Comprehensive testing
- Commit: "Remove deprecated import code"

**Total: 8-12 hours over 4 days**

---

## PHASE 5: mavonEditor Integration (4-6 hours) **HIGH PRIORITY**

**Goal:** Add markdown editing to large text fields
**Duration:** 4-6 hours
**Risk:** Low (UI enhancement, no data model changes)
**Priority:** MUST HAVE for interim release

### 5.1 Install mavonEditor (15 min)

```bash
yarn add mavon-editor
```

### 5.2 Create RichMarkdownEditor Component (1 hour)

**File:** `app/javascript/components/shared/RichMarkdownEditor.vue`
```vue
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
        ol: true, ul: true, code: true,
        fullscreen: true, preview: true,
        undo: true, redo: true
      }
    }
  }
}
</script>
```

### 5.3 Replace Textareas with mavonEditor (2-3 hours)

**Fields to convert (4 primary fields):**
1. `vuln_discussion` (DisaRuleDescriptionForm.vue)
2. `mitigations` (DisaRuleDescriptionForm.vue)
3. `fixtext` (RuleForm.vue)
4. `potential_impacts` (DisaRuleDescriptionForm.vue)

**Example replacement:**
```vue
<!-- OLD -->
<b-form-textarea
  :value="description.vuln_discussion"
  @input="$root.$emit('update:disaDescription', ...)"
/>

<!-- NEW -->
<RichMarkdownEditor
  :value="description.vuln_discussion"
  :disabled="disabled"
  @input="$root.$emit('update:disaDescription', ...)"
/>
```

### 5.4 Test and Validate (1 hour)

**Tests:**
- Create control, add markdown formatting
- Save and reload - verify markdown preserved
- Export to XLSX/XCCDF - verify markdown exports correctly
- Test with plain text (no markdown) - should still work

**Validation:**
- All 4 fields show mavonEditor
- Toolbar works
- Preview works
- Save/load preserves formatting

---

## PHASE 6: Update from File (2-3 hours)

**Goal:** Support export → edit → re-import workflow
**Duration:** 2-3 hours
**Risk:** Low (new feature, doesn't change existing)

### 5.1 Add Update Controller Action (1 hour)

**File:** `app/controllers/components_controller.rb`
```ruby
def update_from_file
  file = params[:file]

  importer = detect_importer(file)
  result = importer.update(@component, file)

  if result
    render json: { toast: 'Successfully updated component from file.' }
  else
    render json: {
      toast: {
        title: 'Update failed',
        message: importer.errors,
        variant: 'danger'
      }
    }, status: :unprocessable_entity
  end
end
```

### 5.2 Add Update Logic to Adapters (1 hour)

```ruby
class XCCDFImporter
  def update(component, file)
    parsed = parse_xccdf(file)

    parsed.groups.each do |group|
      # Find existing rule by version or create new
      existing = component.rules.find_by(version: group.srg_version)

      if existing
        update_rule_from_xccdf(existing, group)
      else
        create_rule_from_xccdf(component, group)
      end
    end

    # Update satisfactions
    sync_satisfactions(component, parsed)
  end
end
```

### 5.3 Add UI Button (30 min)

**File:** Component detail page
```vue
<b-button @click="showUpdateModal">
  Update from File
</b-button>
```

**Validation:**
- Export component to XCCDF
- Edit in external tool
- Re-import updates existing component (doesn't create new)
- All changes preserved

---

## PHASE 6: UX Improvements (1-2 hours)

**Goal:** Bulk SRG ID input and shift-click multi-select
**Duration:** 1-2 hours
**Risk:** Low (UI only)

### 6.1 Bulk SRG ID Text Input (30 min)

**File:** `RuleEditorHeader.vue` - Also Satisfies modal

```vue
<b-form-group label="Bulk Add SRG IDs">
  <b-form-textarea
    v-model="bulkSrgIds"
    placeholder="Paste SRG IDs: SRG-OS-000024, SRG-OS-000027, ..."
    rows="3"
  />
  <b-button @click="addBulkSrgIds">
    Add SRG IDs
  </b-button>
</b-form-group>
```

### 6.2 Shift-Click Multi-Select (30 min)

```vue
<b-form-checkbox
  v-for="(option, index) in filteredOptions"
  :key="option.value"
  :value="option.value"
  @click.native="handleCheckboxClick($event, index)"
>
  {{ option.text }}
</b-form-checkbox>
```

```javascript
methods: {
  handleCheckboxClick(event, index) {
    if (event.shiftKey && this.lastSelectedIndex !== null) {
      // Select range between lastSelectedIndex and index
      const start = Math.min(this.lastSelectedIndex, index)
      const end = Math.max(this.lastSelectedIndex, index)

      for (let i = start; i <= end; i++) {
        const value = this.filteredOptions[i].value
        if (!this.selectedSatisfiesRuleIds.includes(value)) {
          this.selectedSatisfiesRuleIds.push(value)
        }
      }
    }
    this.lastSelectedIndex = index
  }
}
```

---

## PHASE 7: Project Backup/Restore (3-4 hours)

**Goal:** Backup entire project with all data
**Duration:** 3-4 hours
**Risk:** Low (read-only export + new import)

### 7.1 Project Export (2 hours)

```ruby
class ProjectExporter
  def export(project)
    zip = Zip::OutputStream.write_buffer do |zio|
      # Metadata
      zio.put_next_entry('project.json')
      zio.write(project_metadata_json(project))

      # All components as XCCDF
      project.components.each do |component|
        zio.put_next_entry("components/#{component.prefix}.xml")
        zio.write(export_xccdf(component))
      end

      # Members
      zio.put_next_entry('members.json')
      zio.write(members_json(project))
    end

    zip.string
  end
end
```

### 7.2 Project Import (1-2 hours)

```ruby
class ProjectImporter
  def import(zip_file)
    # Extract and read project.json
    # Create project with metadata
    # Import each XCCDF component
    # Restore members
  end
end
```

---

## PHASE 8: Vue 3 + Bootstrap-Vue-Next Migration (30-40 hours)

**Goal:** Migrate from Vue 2 + Bootstrap-Vue to Vue 3 + Bootstrap-Vue-Next
**Duration:** 30-40 hours over 2-3 weeks
**Risk:** HIGH (complete frontend rewrite)

### 8.1 Preparation (4-6 hours)

**Research:**
- Review all 107 open issues on Bootstrap-Vue-Next
- Test critical components (modal, table, form) in isolation
- Identify breaking changes for Vulcan

**Dependencies:**
```bash
yarn add vue@3 bootstrap-vue-next@0.40.8 bootstrap@5
yarn remove vue@2 bootstrap-vue@2 bootstrap@4
```

### 8.2 Migration Strategy

**Option A: Page-by-Page (Recommended)**
- Convert one pack file at a time (14 separate Vue instances)
- Test each page thoroughly before moving to next
- Allows gradual migration over weeks

**Option B: All-at-Once**
- Convert everything simultaneously
- Higher risk, faster completion
- Requires extensive testing phase

### 8.3 Per-Page Migration (2-3 hours each × 14 pages)

**For each pack file:**
1. Update to Vue 3 Composition API or Options API
2. Replace Bootstrap-Vue components with Bootstrap-Vue-Next
3. Update Bootstrap 4 classes to Bootstrap 5 (left→start, right→end)
4. Test all functionality
5. Fix any breaking changes

**Component-specific changes:**
- `b-icon` → May need different icon library
- `v-b-tooltip` → Syntax changes
- `b-modal` → API differences
- `b-table` → Prop name changes

### 8.4 Critical Testing (4-6 hours)

**Test every workflow:**
- Login/authentication
- Project creation
- Component creation/editing
- Rule editing with all form fields
- Import/export (XLSX, XCCDF)
- Member management
- Review workflow
- Satisfaction relationships (Also Satisfies modal)

### 8.5 Turbolinks Removal (2-3 hours)

**Current:** Vue 2 with vue-turbolinks adapter
**Target:** Vue 3 without Turbolinks

**Changes:**
- Remove turbolinks gem
- Remove vue-turbolinks
- Update all `turbolinks:load` event listeners
- Test page transitions

---

**Phases renumbered - mavonEditor moved up:**

## COMPLETE PHASE TIMELINE

**Phase 1:** Foundation (1-2 hours) - DAY 1
**Phase 2:** Database Migration (3-4 hours) - DAY 2-3
**Phase 3:** Switch to Adapters (2-3 hours) - DAY 3-4
**Phase 4:** Cleanup (1-2 hours) - DAY 4
**Phase 5:** mavonEditor Integration (4-6 hours) - DAY 5-6 **INTERIM RELEASE**
**Phase 6:** Update from File (2-3 hours) - DAY 7
**Phase 7:** UX Improvements (1-2 hours) - DAY 7
**Phase 8:** Project Backup (3-4 hours) - DAY 8
**Phase 9:** Vue 3 Migration (30-40 hours) - WEEKS 2-4

**Total: 47-64 hours over 3-4 weeks**

---

## Recommended Versioning

**v2.3.0 (SHIP NOW):**
- Current XCCDF import working
- 16 commits, all tests passing
- Push and release TODAY

**v2.3.1 (Phase 5 - INTERIM RELEASE):**
- mavonEditor for markdown editing
- 4-6 hours over 1-2 days
- **User-facing improvement - ship ASAP**

**v2.4.0 (Phases 1-4):**
- Import/export architecture refactor
- 8-12 hours over 1 week
- Cleaner codebase, foundation for future work

**v2.5.0 (Phases 6-8):**
- Update from file, UX improvements, Project backup
- 6-9 hours over 1 week
- User-facing features

**v3.0.0 (Phase 9):**
- Vue 3 + Bootstrap-Vue-Next migration
- 30-40 hours over 3-4 weeks
- Major upgrade, extensive testing required

---

## Emergency Stop Points

**Can stop after Phase 1:**
- New helpers tested
- Adapters proven equivalent
- No data changed
- Can ship and continue later

**Can stop after Phase 2:**
- Data migrated
- Both systems working side-by-side
- Can finish Phase 3 later

**Must complete Phase 3 once Phase 2 done:**
- Don't leave in half-migrated state
- Either finish or rollback Phase 2

---

## Current Status

**Completed:**
- [x] XCCDF import working (messy but functional)
- [x] All tests passing (309 examples)
- [x] 16 commits on v2.3.0

**Next:**
- [ ] Start Phase 1 (or push v2.3.0 and do refactor in v2.4.0)

---

**Decision Point:** Start Phase 1 now, or push v2.3.0 and refactor in v2.4.0?

**Status:** Awaiting decision
