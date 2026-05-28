# Vulcan Unified Refactor Plan

**Created:** 2025-11-30
**Version:** v3.0.0 Target
**Approach:** Phased, each phase shippable, test as we go

---

## Executive Summary

This plan merges:
- Database 3NF redesign (eliminate duplication, fix relationships)
- Service layer architecture (clean business logic extraction)
- Import/Export refactoring (designed for new schema)
- API layer (external integrations)
- New features (Diff/Changelog, SRG Upgrade, Backup/Restore)

**Total Effort:** ~80-100 hours across 12 phases
**Each phase is independently shippable**

---

## Phase Overview

| Phase | Name | Effort | Risk | Ship As |
|-------|------|--------|------|---------|
| 1 | Display Fallback Methods | 3-4h | Low | v2.3.1 |
| 2 | Service Infrastructure | 3-4h | Low | v2.3.2 |
| 3 | Split STI Tables | 8-10h | Medium | v2.4.0 |
| 4 | Import/Export Services | 8-10h | Medium | v2.4.1 |
| 5 | Override Tables | 6-8h | Medium | v2.5.0 |
| 6 | Fix Satisfactions | 4-6h | Medium | v2.5.1 |
| 7 | Pundit Authorization | 6-8h | Low | v2.6.0 |
| 8 | Query Objects + Blueprinter | 6-8h | Low | v2.6.1 |
| 9 | Full REST API | 12-16h | Medium | v2.7.0 |
| 10 | Update from File + Backup/Restore | 6-8h | Low | v2.7.1 |
| 11 | Diff/Changelog Features | 8-10h | Low | v2.8.0 |
| 12 | SRG Upgrade Workflow | 8-10h | Medium | v3.0.0 |

---

## Phase Dependencies

```
Phase 1: Display Fallback Methods (foundation pattern)
    ↓
Phase 2: Service Infrastructure (app/services/ structure)
    ↓
Phase 3: Split STI Tables (separate srg_rules, stig_rules, rules)
    ↓
Phase 4: Import/Export Services (designed for new schema)
    ↓
Phase 5: Override Tables (rule_check_overrides, rule_description_overrides)
    ↓
Phase 6: Fix Satisfactions (Rule→SrgRule instead of Rule→Rule)
    ↓
Phase 7: Pundit Authorization (centralized permissions)
    ↓
Phase 8: Query Objects + Blueprinter (performance + serialization)
    ↓
Phase 9: Full REST API (/api/v1/)
    ↓
Phase 10: Update from File + Backup/Restore (uses services from Phase 4)
    ↓
Phase 11: Diff/Changelog Features (uses new schema)
    ↓
Phase 12: SRG Upgrade Workflow (uses all previous phases)
```

---

## PHASE 1: Display Fallback Methods (3-4 hours)

**Goal:** Establish override pattern without database changes
**Risk:** Low - additive only, no breaking changes
**Ship As:** v2.3.1

### What We're Building

Rules can fall back to SRG template content when their fields are NULL.

```ruby
# app/models/concerns/display_fallback.rb
module DisplayFallback
  extend ActiveSupport::Concern

  # Title: use override if present, otherwise SRG template
  def display_title
    self[:title].presence || srg_rule&.title
  end

  # Fixtext: use override if present, otherwise SRG template
  def display_fixtext
    self[:fixtext].presence || srg_rule&.fixtext
  end

  # Check content with fallback
  def display_check_content
    checks.first&.content.presence || srg_rule&.checks&.first&.content
  end

  # Vuln discussion with fallback
  def display_vuln_discussion
    disa_rule_descriptions.first&.vuln_discussion.presence ||
      srg_rule&.disa_rule_descriptions&.first&.vuln_discussion
  end

  # Generic accessor
  def display_field(field_name)
    value = send(field_name) rescue nil
    return value if value.present?
    srg_rule&.send(field_name) rescue nil
  end

  # Check if rule has ANY overrides
  def has_overrides?
    self[:title].present? ||
      self[:fixtext].present? ||
      checks.any? { |c| c.content.present? } ||
      disa_rule_descriptions.any? { |d| d.vuln_discussion.present? }
  end
end
```

### Tasks

1. **Create concern** (1h)
   - `app/models/concerns/display_fallback.rb`
   - Include in Rule model
   - Add tests

2. **Update RuleBlueprint** (1h)
   - Use `display_*` methods
   - Ensure API returns correct content

3. **Update views/frontend** (1h)
   - Ensure UI uses blueprint data
   - No direct field access

4. **Tests** (1h)
   - Unit tests for fallback logic
   - Integration tests for API
   - Verify no behavior change

### Deliverables
```
app/models/concerns/display_fallback.rb (NEW)
app/models/rule.rb (include DisplayFallback)
app/blueprints/rule_blueprint.rb (use display_* methods)
spec/models/concerns/display_fallback_spec.rb (NEW)
```

### Completion Criteria
- [ ] All existing tests pass
- [ ] New fallback tests pass
- [ ] API returns same data as before
- [ ] UI unchanged
- [ ] Pattern documented

---

## PHASE 2: Service Infrastructure (3-4 hours)

**Goal:** Establish service object pattern
**Risk:** Low - infrastructure only
**Ship As:** v2.3.2

### What We're Building

```
app/services/
├── application_service.rb
├── imports/
│   └── base_import_service.rb
├── exports/
│   └── base_export_service.rb
├── components/
│   └── base_component_service.rb
└── projects/
    └── base_project_service.rb
```

### Tasks

1. **Create directory structure** (30min)
   ```bash
   mkdir -p app/services/{imports,exports,components,projects}
   ```

2. **Create ApplicationService base** (1h)
   ```ruby
   # app/services/application_service.rb
   class ApplicationService
     def self.call(*args, **kwargs, &block)
       new(*args, **kwargs, &block).call
     end

     def call
       raise NotImplementedError
     end

     private

     def success(data = nil)
       ServiceResult.new(success: true, data: data)
     end

     def failure(error)
       ServiceResult.new(success: false, error: error)
     end
   end

   # Result object for consistent returns
   class ServiceResult
     attr_reader :data, :error

     def initialize(success:, data: nil, error: nil)
       @success = success
       @data = data
       @error = error
     end

     def success?
       @success
     end

     def failure?
       !@success
     end
   end
   ```

3. **Create base services** (1h)
   - `Imports::BaseImportService`
   - `Exports::BaseExportService`
   - Document patterns

4. **Add to autoload** (30min)
   - Ensure Rails autoloads `app/services/`
   - Test in console

5. **Documentation** (1h)
   - Create `docs/SERVICE_PATTERN.md`
   - Examples and conventions

### Deliverables
```
app/services/application_service.rb
app/services/imports/base_import_service.rb
app/services/exports/base_export_service.rb
app/services/components/base_component_service.rb
app/services/projects/base_project_service.rb
docs/SERVICE_PATTERN.md
```

### Completion Criteria
- [ ] Service classes load correctly
- [ ] Pattern documented
- [ ] Example service works
- [ ] Tests pass

---

## PHASE 3: Split STI Tables (8-10 hours)

**Goal:** Separate SrgRule, StigRule, Rule into distinct tables
**Risk:** Medium - schema change, requires careful migration
**Ship As:** v2.4.0

### What We're Building

Instead of one `base_rules` table with STI:
```
base_rules (type: 'SrgRule' | 'StigRule' | 'Rule')
```

We'll have three separate tables:
```
srg_rules      → SRG template requirements
stig_rules     → Published STIG controls
rules          → User-authored implementations
```

### Migration Strategy

1. **Create new tables** (keep old table)
2. **Copy data** to new tables
3. **Update models** to use new tables
4. **Verify** everything works
5. **Drop old table** (later, separate migration)

### Tasks

1. **Create srg_rules table** (2h)
   ```ruby
   # db/migrate/YYYYMMDD_create_srg_rules_table.rb
   class CreateSrgRulesTable < ActiveRecord::Migration[8.0]
     def change
       create_table :srg_rules do |t|
         t.references :security_requirements_guide, foreign_key: true, null: false
         t.string :rule_identifier, null: false  # SRG-OS-000023
         t.string :version
         t.string :title
         t.text :fixtext
         t.string :ident
         t.string :ident_system
         t.string :rule_severity
         t.string :rule_weight
         t.string :fix_id
         t.string :fixtext_fixref
         t.text :legacy_ids
         t.timestamps

         t.index [:security_requirements_guide_id, :rule_identifier], unique: true
       end
     end
   end
   ```

2. **Create stig_rules table** (1h)
   ```ruby
   # Similar structure for STIG rules
   ```

3. **Create new rules table** (1h)
   ```ruby
   # db/migrate/YYYYMMDD_create_rules_table.rb
   class CreateRulesTable < ActiveRecord::Migration[8.0]
     def change
       create_table :rules do |t|
         t.references :component, foreign_key: true, null: false
         t.references :srg_rule, foreign_key: true, null: false
         t.string :display_number, null: false  # 000001

         # User-specific fields (always on Rule)
         t.string :status, default: 'Not Yet Determined'
         t.text :status_justification
         t.text :artifact_description
         t.text :vendor_comments
         t.text :inspec_control_body
         t.text :inspec_control_file
         t.boolean :locked, default: false
         t.references :review_requestor, foreign_key: { to_table: :users }
         t.boolean :changes_requested, default: false
         t.datetime :deleted_at

         # Override fields (NULL = use SRG template)
         t.string :title_override
         t.text :fixtext_override
         t.string :ident_override
         t.string :severity_override

         t.timestamps

         t.index [:component_id, :display_number], unique: true
         t.index :deleted_at
       end
     end
   end
   ```

4. **Create srg_checks and srg_descriptions** (1h)
   ```ruby
   # Checks for SRG templates
   create_table :srg_checks do |t|
     t.references :srg_rule, foreign_key: true, null: false
     t.string :system
     t.string :content_ref_name
     t.string :content_ref_href
     t.text :content
     t.timestamps
   end

   # Descriptions for SRG templates
   create_table :srg_descriptions do |t|
     t.references :srg_rule, foreign_key: true, null: false
     t.text :vuln_discussion
     t.text :false_positives
     t.text :false_negatives
     t.string :documentable
     t.text :mitigations
     t.text :severity_override_guidance
     t.text :potential_impacts
     t.text :third_party_tools
     t.text :mitigation_control
     t.text :responsibility
     t.text :ia_controls
     t.timestamps
   end
   ```

5. **Data migration rake task** (2h)
   ```ruby
   # lib/tasks/migrate_to_separate_tables.rake
   namespace :db do
     desc 'Migrate STI base_rules to separate tables'
     task migrate_sti: :environment do
       ActiveRecord::Base.transaction do
         # Migrate SrgRules
         execute <<~SQL
           INSERT INTO srg_rules (id, security_requirements_guide_id, rule_identifier, ...)
           SELECT id, security_requirements_guide_id, rule_id, ...
           FROM base_rules WHERE type = 'SrgRule'
         SQL

         # Migrate StigRules
         # ...

         # Migrate Rules (with srg_rule_id reference)
         # ...

         # Migrate checks
         # ...

         # Migrate descriptions
         # ...
       end
     end
   end
   ```

6. **Update models** (2h)
   ```ruby
   # app/models/srg_rule.rb
   class SrgRule < ApplicationRecord
     belongs_to :security_requirements_guide
     has_one :srg_check, dependent: :destroy
     has_one :srg_description, dependent: :destroy
     has_many :rules  # Rules that implement this requirement
   end

   # app/models/rule.rb
   class Rule < ApplicationRecord
     include DisplayFallback

     belongs_to :component
     belongs_to :srg_rule
     has_one :check_override, class_name: 'RuleCheckOverride'
     has_one :description_override, class_name: 'RuleDescriptionOverride'
   end
   ```

7. **Update all queries and associations** (1h)

8. **Test everything** (1h)

### Deliverables
```
db/migrate/YYYYMMDD_create_srg_rules_table.rb
db/migrate/YYYYMMDD_create_stig_rules_table.rb
db/migrate/YYYYMMDD_create_rules_table.rb
db/migrate/YYYYMMDD_create_srg_checks_table.rb
db/migrate/YYYYMMDD_create_srg_descriptions_table.rb
lib/tasks/migrate_to_separate_tables.rake
app/models/srg_rule.rb (updated)
app/models/stig_rule.rb (updated)
app/models/rule.rb (updated)
```

### Completion Criteria
- [ ] New tables created
- [ ] Data migrated correctly
- [ ] All tests pass
- [ ] No STI references remain in new code
- [ ] Old base_rules table still exists (for rollback)

---

## PHASE 4: Import/Export Services (8-10 hours)

**Goal:** Extract import/export logic to services designed for new schema
**Risk:** Medium - touches critical functionality
**Ship As:** v2.4.1

### What We're Building

Services that understand the override pattern:

```ruby
# app/services/imports/xccdf_import_service.rb
class Imports::XccdfImportService < ApplicationService
  def initialize(component:, file:, mode: :create)
    @component = component
    @file = file
    @mode = mode  # :create or :update
  end

  def call
    parsed = parse_xccdf(@file)

    ActiveRecord::Base.transaction do
      parsed.groups.each do |group|
        import_rule(group)
      end

      import_satisfactions(parsed)
    end

    success(@component.reload)
  rescue => e
    failure(e.message)
  end

  private

  def import_rule(group)
    srg_rule = find_srg_rule(group)

    rule = @component.rules.find_or_initialize_by(srg_rule: srg_rule)

    # Only store OVERRIDES - if content matches SRG, leave NULL
    rule.title_override = extract_title(group) unless matches_srg?(group, :title, srg_rule)
    rule.fixtext_override = extract_fixtext(group) unless matches_srg?(group, :fixtext, srg_rule)

    # Always store user-specific fields
    rule.status = extract_status(group)
    rule.vendor_comments = extract_vendor_comments(group)

    rule.save!

    # Only create check override if different from SRG
    import_check_override(rule, group) unless check_matches_srg?(group, srg_rule)
  end

  def matches_srg?(group, field, srg_rule)
    extract_field(group, field) == srg_rule.send(field)
  end
end
```

### Tasks

1. **Extract XCCDF import** (3-4h)
   - `Imports::XccdfImportService`
   - Support `:create` and `:update` modes
   - Only store overrides

2. **Extract spreadsheet import** (2-3h)
   - `Imports::SpreadsheetImportService`
   - Same override pattern

3. **Extract XCCDF export** (2h)
   - `Exports::XccdfExportService`
   - Use `display_*` methods for output

4. **Extract CSV export** (1h)
   - `Exports::CsvExportService`

5. **Update controllers** (1h)
   - Delegate to services
   - Remove business logic from controllers

### Deliverables
```
app/services/imports/xccdf_import_service.rb
app/services/imports/spreadsheet_import_service.rb
app/services/exports/xccdf_export_service.rb
app/services/exports/csv_export_service.rb
spec/services/imports/xccdf_import_service_spec.rb
spec/services/exports/xccdf_export_service_spec.rb
```

### Completion Criteria
- [ ] All import/export via services
- [ ] Override pattern implemented
- [ ] No duplicate content stored
- [ ] Roundtrip tests pass (export → import → same data)
- [ ] Component model significantly reduced

---

## PHASE 5: Override Tables (6-8 hours)

**Goal:** Separate tables for check and description overrides
**Risk:** Medium - schema change
**Ship As:** v2.5.0

### What We're Building

Instead of duplicating all checks/descriptions for every rule:

```
rule_check_overrides (only if user customizes)
rule_description_overrides (only if user customizes)
```

### Tasks

1. **Create override tables** (1h)
2. **Migrate existing overrides** (2h)
3. **Update Rule model** (1h)
4. **Update import services** (2h)
5. **Test** (2h)

### Deliverables
```
db/migrate/YYYYMMDD_create_rule_check_overrides.rb
db/migrate/YYYYMMDD_create_rule_description_overrides.rb
app/models/rule_check_override.rb
app/models/rule_description_override.rb
```

---

## PHASE 6: Fix Satisfactions (4-6 hours)

**Goal:** Rule→SrgRule instead of Rule→Rule
**Risk:** Medium - changes core relationship
**Ship As:** v2.5.1

### What We're Building

```ruby
# Current (wrong)
rule.satisfied_by  # → other Rules

# New (correct)
rule.satisfies_srg_rules  # → SrgRules this rule satisfies
```

### Tasks

1. **Update rule_satisfactions table** (1h)
2. **Migrate data** (2h)
3. **Update model associations** (1h)
4. **Update UI** (1h)
5. **Test** (1h)

---

## PHASE 7: Pundit Authorization (6-8 hours)

**Goal:** Centralized permission policies
**Risk:** Low - additive
**Ship As:** v2.6.0

### What We're Building

```ruby
# app/policies/component_policy.rb
class ComponentPolicy < ApplicationPolicy
  def show?
    user.admin? || member?
  end

  def edit?
    user.admin? || author?
  end

  def destroy?
    user.admin? || admin?
  end
end
```

---

## PHASE 8: Query Objects + Blueprinter (6-8 hours)

**Goal:** Optimized queries, consistent serialization
**Risk:** Low
**Ship As:** v2.6.1

---

## PHASE 9: Full REST API (12-16 hours)

**Goal:** `/api/v1/` with token auth
**Risk:** Medium
**Ship As:** v2.7.0

---

## PHASE 10: Update from File + Backup/Restore (6-8 hours)

**Goal:** External editing workflow, disaster recovery
**Risk:** Low
**Ship As:** v2.7.1

### What We're Building

```ruby
# Update from modified XCCDF
Imports::XccdfImportService.call(
  component: @component,
  file: uploaded_file,
  mode: :update  # Match and update existing rules
)

# Full project backup
Projects::BackupService.call(@project)
# → Returns ZIP with project.json + components/*.xml

# Restore from backup
Projects::RestoreService.call(zip_file)
# → Creates project with all components
```

---

## PHASE 11: Diff/Changelog Features (8-10 hours)

**Goal:** Track and display changes
**Risk:** Low
**Ship As:** v2.8.0

### What We're Building

```ruby
# SRG version diff
SrgDiffService.call(srg_v1, srg_v2)
# → { added: [...], removed: [...], modified: [...] }

# Component changelog
component.changelog(since: 1.week.ago)
# → Grouped audit history

# Component override summary
component.override_summary
# → Which rules have customizations
```

---

## PHASE 12: SRG Upgrade Workflow (8-10 hours)

**Goal:** Upgrade component's SRG while preserving work
**Risk:** Medium
**Ship As:** v3.0.0

### What We're Building

```ruby
# Preview what would change
ComponentSrgUpgradeService.new(@component, new_srg).preview
# → { rules_to_update: [...], rules_to_add: [...], rules_to_remove: [...] }

# Execute upgrade
ComponentSrgUpgradeService.new(@component, new_srg).upgrade!(
  preserve_overrides: true,
  handle_removed: :mark_not_applicable
)
```

### UI

```
┌─────────────────────────────────────────────────────────────────┐
│ Upgrade Component: OS SRG V2R1 → V2R2                           │
├─────────────────────────────────────────────────────────────────┤
│ 247 requirements will be updated                                │
│ 3 new requirements will be added                                │
│ 1 requirement was removed (has customizations)                  │
│                                                                 │
│ ☑️ Preserve my customizations                                   │
│                                                                 │
│ [Cancel]                                          [Upgrade Now] │
└─────────────────────────────────────────────────────────────────┘
```

---

## Success Metrics

After all phases complete:

| Metric | Before | After |
|--------|--------|-------|
| Component storage | ~2MB | ~0.3MB |
| Duplicate content | ~70% | 0% |
| Component model LOC | 785 | ~200 |
| Controller LOC | 430 | ~150 |
| Test count | 345 | ~500+ |
| N+1 queries | Many | Zero |

---

## Getting Started

**Start with Phase 1 today:**

```
Add display_* fallback methods to Rule model
- Zero database changes
- Zero risk
- Establishes foundation for everything else
- Can ship immediately as v2.3.1
```

Ready?
