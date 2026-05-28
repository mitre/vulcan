# Database 3NF Refactor - Implementation Plan

**Created:** 2025-11-30
**Branch:** v2.3.0 (will become v3.0.0)
**Goal:** Eliminate content duplication, fix Rule→SrgRule satisfactions

---

## Executive Summary

The refactor has **4 phases**, each independently deployable:

| Phase | Scope | Effort | Risk | Can Ship After? |
|-------|-------|--------|------|-----------------|
| 1 | Add `display_*` fallback methods | 2-3 hrs | Low | ✅ Yes |
| 2 | Change satisfactions to Rule→SrgRule | 4-6 hrs | Medium | ✅ Yes |
| 3 | Clean up duplicate content | 3-4 hrs | Medium | ✅ Yes |
| 4 | Update import to use NULL defaults | 2-3 hrs | Low | ✅ Yes |

**Total estimated effort:** 11-16 hours across multiple sessions

---

## Current State

### Tables Involved

```
base_rules (STI: Rule, SrgRule, StigRule)
├── 64 columns including: title, fixtext, status, vendor_comments, etc.
├── srg_rule_id → self-reference to SrgRule
├── component_id → components
└── security_requirements_guide_id → srgs

checks
├── base_rule_id → base_rules
└── content (check text)

disa_rule_descriptions
├── base_rule_id → base_rules
└── 11 fields (vuln_discussion, mitigations, etc.)

rule_satisfactions (join table, no id)
├── rule_id → base_rules (Rule type)
└── satisfied_by_rule_id → base_rules (Rule type)
```

### The Problems

1. **Content duplication**: When Component created, ALL SRG content copied to Rules
2. **Satisfactions wrong direction**: Rule→Rule instead of Rule→SrgRule
3. **Placeholder Rules**: Created just to have something to link to

---

## Phase 1: Add Fallback Display Methods (Non-Breaking)

**Goal:** Establish pattern where Rule can fall back to SrgRule content

### Tasks

#### 1.1 Add display_* methods to Rule model

```ruby
# app/models/rule.rb

# Title with fallback to SRG template
def display_title
  title.presence || srg_rule&.title
end

# Fixtext with fallback
def display_fixtext
  fixtext.presence || srg_rule&.fixtext
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

# Generic fallback for any field
def display_field(field_name)
  value = send(field_name)
  return value if value.present?
  srg_rule&.send(field_name)
end
```

#### 1.2 Add tests for fallback behavior

```ruby
# spec/models/rule_spec.rb

describe 'display_* methods' do
  let(:srg_rule) { create(:srg_rule, title: 'SRG Title', fixtext: 'SRG Fix') }
  let(:rule) { create(:rule, srg_rule: srg_rule, title: nil, fixtext: nil) }

  it 'falls back to SRG title when rule title is nil' do
    expect(rule.display_title).to eq('SRG Title')
  end

  it 'uses rule title when present' do
    rule.update(title: 'Custom Title')
    expect(rule.display_title).to eq('Custom Title')
  end
end
```

#### 1.3 Update RuleBlueprint to use display_* methods

```ruby
# app/blueprints/rule_blueprint.rb

field :title do |rule|
  rule.display_title
end

field :fixtext do |rule|
  rule.display_fixtext
end
```

#### 1.4 Update frontend types (optional but helpful)

```typescript
// Already have these, just document the pattern
interface IRule {
  title: string          // Now always populated via display_*
  fixtext?: string       // etc.
}
```

### Phase 1 Verification

- [ ] All existing tests pass
- [ ] New fallback tests pass
- [ ] API returns same data (using display_* methods)
- [ ] UI looks identical

### Phase 1 Commit

```
feat: Add display_* fallback methods to Rule model

- Rules now fall back to SrgRule content when their fields are NULL
- Prepares for 3NF refactor where content won't be duplicated
- No database changes, fully backwards compatible

Authored by: Aaron Lippold<lippold@gmail.com>
```

---

## Phase 2: Change Satisfactions to Rule→SrgRule

**Goal:** Link Rules directly to SrgRules they satisfy, not other Rules

### Tasks

#### 2.1 Create migration to add srg_rule_id column

```ruby
# db/migrate/YYYYMMDD_add_srg_rule_to_satisfactions.rb

class AddSrgRuleToSatisfactions < ActiveRecord::Migration[8.0]
  def change
    # Add new column (keep old for migration)
    add_column :rule_satisfactions, :srg_rule_id, :bigint
    add_index :rule_satisfactions, [:rule_id, :srg_rule_id], unique: true
    add_foreign_key :rule_satisfactions, :base_rules, column: :srg_rule_id
  end
end
```

#### 2.2 Create data migration rake task

```ruby
# lib/tasks/migrate_satisfactions.rake

namespace :db do
  desc 'Migrate rule_satisfactions from Rule→Rule to Rule→SrgRule'
  task migrate_satisfactions: :environment do
    RuleSatisfaction = Struct.new(:rule_id, :satisfied_by_rule_id)

    # For each existing satisfaction
    ActiveRecord::Base.connection.execute(<<~SQL).each do |row|
      SELECT rule_id, satisfied_by_rule_id FROM rule_satisfactions
    SQL
      # Find the satisfied_by_rule and get its srg_rule_id
      satisfied_by_rule = Rule.find(row['satisfied_by_rule_id'])
      srg_rule_id = satisfied_by_rule.srg_rule_id

      if srg_rule_id.present?
        # Update to point to SrgRule instead
        ActiveRecord::Base.connection.execute(<<~SQL)
          UPDATE rule_satisfactions
          SET srg_rule_id = #{srg_rule_id}
          WHERE rule_id = #{row['rule_id']}
            AND satisfied_by_rule_id = #{row['satisfied_by_rule_id']}
        SQL
        puts "Migrated: Rule##{row['rule_id']} → SrgRule##{srg_rule_id}"
      else
        puts "WARNING: Rule##{row['satisfied_by_rule_id']} has no srg_rule_id"
      end
    end
  end
end
```

#### 2.3 Run migration and verify

```bash
rails db:migrate
rails db:migrate_satisfactions
```

#### 2.4 Update model associations

```ruby
# app/models/rule.rb

# OLD (keep temporarily for backwards compat)
has_and_belongs_to_many :satisfied_by,
                        class_name: 'Rule',
                        join_table: :rule_satisfactions,
                        association_foreign_key: :satisfied_by_rule_id

# NEW
has_many :srg_satisfactions,
         class_name: 'RuleSrgSatisfaction',
         foreign_key: :rule_id

has_many :satisfies_srg_rules,
         through: :srg_satisfactions,
         source: :srg_rule
```

#### 2.5 Create RuleSrgSatisfaction model

```ruby
# app/models/rule_srg_satisfaction.rb

class RuleSrgSatisfaction < ApplicationRecord
  self.table_name = 'rule_satisfactions'

  belongs_to :rule
  belongs_to :srg_rule, class_name: 'SrgRule'
end
```

#### 2.6 Update controller and API

```ruby
# app/controllers/rule_satisfactions_controller.rb

def create
  # Now accepts srg_rule_id instead of satisfied_by_rule_id
  @srg_rule = SrgRule.find(params[:srg_rule_id])

  if @rule.satisfies_srg_rules << @srg_rule
    render json: { toast: "Marked as satisfying #{@srg_rule.version}" }
  else
    # error handling
  end
end
```

#### 2.7 Update frontend

```typescript
// Updated IRuleSatisfaction
interface IRuleSatisfaction {
  id: number
  srg_rule_id: number  // Changed from rule_id
  srg_rule_version: string
  srg_rule_title: string
}
```

#### 2.8 Remove old column migration

```ruby
# db/migrate/YYYYMMDD_remove_satisfied_by_rule_id.rb

class RemoveSatisfiedByRuleId < ActiveRecord::Migration[8.0]
  def change
    remove_column :rule_satisfactions, :satisfied_by_rule_id, :bigint
  end
end
```

### Phase 2 Verification

- [ ] Existing satisfactions migrated correctly
- [ ] New satisfaction creation works
- [ ] UI shows correct relationships
- [ ] Import/export still works

### Phase 2 Commit

```
feat: Change satisfactions from Rule→Rule to Rule→SrgRule

BREAKING CHANGE: rule_satisfactions now links to SrgRule directly

- Removed placeholder Rules needed just for satisfaction links
- Direct link to SRG requirements is cleaner and more accurate
- Data migration included for existing satisfactions

Authored by: Aaron Lippold<lippold@gmail.com>
```

---

## Phase 3: Clean Up Duplicate Content

**Goal:** Set NULL on Rule fields that match SrgRule templates

### Tasks

#### 3.1 Create cleanup rake task

```ruby
# lib/tasks/deduplicate_content.rake

namespace :db do
  desc 'Set NULL on Rule fields that match SrgRule template'
  task deduplicate_rule_content: :environment do
    Rule.includes(:srg_rule).find_each do |rule|
      next unless rule.srg_rule

      updates = {}

      # Check each field
      if rule.title == rule.srg_rule.title
        updates[:title] = nil
      end

      if rule.fixtext == rule.srg_rule.fixtext
        updates[:fixtext] = nil
      end

      # Update if any matches found
      if updates.any?
        rule.update_columns(updates)
        puts "Deduplicated Rule##{rule.id}: #{updates.keys.join(', ')}"
      end
    end
  end

  desc 'Deduplicate checks that match SrgRule template'
  task deduplicate_checks: :environment do
    Rule.includes(:srg_rule, :checks).find_each do |rule|
      next unless rule.srg_rule

      rule.checks.each_with_index do |check, index|
        srg_check = rule.srg_rule.checks[index]
        next unless srg_check

        if check.content == srg_check.content
          check.destroy
          puts "Removed duplicate check for Rule##{rule.id}"
        end
      end
    end
  end
end
```

#### 3.2 Run and verify

```bash
rails db:deduplicate_rule_content
rails db:deduplicate_checks
```

#### 3.3 Add validation for new Rules

```ruby
# app/models/rule.rb

before_save :nullify_template_content

private

def nullify_template_content
  return unless srg_rule

  self.title = nil if title == srg_rule.title
  self.fixtext = nil if fixtext == srg_rule.fixtext
  # etc.
end
```

### Phase 3 Verification

- [ ] display_* methods still return correct content
- [ ] Storage reduced (check database size)
- [ ] UI unchanged

### Phase 3 Commit

```
refactor: Deduplicate Rule content that matches SRG templates

- Rules now store NULL when content matches SRG template
- display_* methods provide fallback to SRG content
- Significant storage reduction (~70% for typical components)

Authored by: Aaron Lippold<lippold@gmail.com>
```

---

## Phase 4: Update Import to Use NULL Defaults

**Goal:** New Rules created with NULL fields, relying on SrgRule fallback

### Tasks

#### 4.1 Update Component creation to not copy content

```ruby
# app/models/component.rb (or wherever Rules are created)

def create_rules_from_srg
  security_requirements_guide.srg_rules.each do |srg_rule|
    rules.create!(
      srg_rule: srg_rule,
      rule_id: srg_rule.rule_id,
      # Don't copy content - let display_* fall back
      title: nil,
      fixtext: nil,
      status: 'Not Yet Determined'
      # Only set user-specific fields
    )
  end
end
```

#### 4.2 Update XCCDF import to not duplicate

Similar changes to import logic.

#### 4.3 Update tests

Ensure tests expect NULL fields with fallback behavior.

### Phase 4 Verification

- [ ] New Components created with minimal data
- [ ] UI shows SRG content via fallback
- [ ] Export still produces complete XCCDF

### Phase 4 Commit

```
feat: Import creates Rules with NULL defaults, uses SRG fallback

- New Rules don't duplicate SRG template content
- display_* methods provide all content via fallback
- Existing Rules unaffected (can be cleaned up separately)

Authored by: Aaron Lippold<lippold@gmail.com>
```

---

## Rollback Plan

Each phase is independently reversible:

### Phase 1 Rollback
- Remove display_* methods
- Revert blueprint changes
- No database changes to undo

### Phase 2 Rollback
- Re-add satisfied_by_rule_id column
- Run reverse migration to populate from srg_rule_id
- Revert model associations

### Phase 3 Rollback
- Run task to copy SRG content back to Rules with NULL fields
- Remove nullify_template_content validation

### Phase 4 Rollback
- Update import to copy content again
- New Rules will have duplicated content (like before)

---

## Testing Strategy

### Before Each Phase
1. Full RSpec suite passes
2. Database backup taken
3. Frontend tests pass

### After Each Phase
1. Full RSpec suite passes
2. Manual smoke test of key flows:
   - Create new Component
   - Edit Rule content
   - Add/remove satisfaction
   - Export to XCCDF
   - Import from XCCDF

---

## Session Breakdown

Assuming 2-3 hour sessions:

| Session | Phase | Tasks |
|---------|-------|-------|
| 1 | Phase 1 | Add display_* methods, tests, blueprint updates |
| 2 | Phase 2a | Migration, data migration task, run migration |
| 3 | Phase 2b | Update model, controller, frontend, tests |
| 4 | Phase 3 | Deduplication tasks, run, verify |
| 5 | Phase 4 | Update import, tests, final verification |

---

## Decision: Start Now?

**Pros:**
- Each phase is independently shippable
- Phase 1 is truly non-breaking
- Establishes clean patterns for future features
- Satisfies refactor becomes natural in Phase 2

**Cons:**
- 5 sessions of focused work
- Need to be careful with data migrations
- Some risk in Phases 2-3

**Recommendation:** Start Phase 1 now. It's low-risk and sets up everything else.

---

## Start Command

```
Let's do Phase 1 of the 3NF refactor:
- Add display_* fallback methods to Rule model
- Update RuleBlueprint to use them
- Add tests
```
