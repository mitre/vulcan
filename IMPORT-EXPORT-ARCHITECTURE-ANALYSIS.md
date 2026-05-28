# Import/Export Architecture Analysis

**Created:** 2025-11-26
**Purpose:** Analyze current architecture issues and propose clean solution

---

## Current Architecture Problems

### Problem 1: Duplicate Check/Description Creation

**Issue:** When importing XCCDF after SRG import:
- `from_mapping(srg)` creates empty checks/descriptions
- XCCDF import creates NEW checks/descriptions
- Result: 2 checks per rule (one empty, one with content)

**Current hack:** Update first check instead of creating new

**Root cause:** No clear separation between "template" and "authored" content

---

### Problem 2: Satisfaction Data Scattered Across Multiple Places

**Current state:**
- Database: `satisfied_by` / `satisfies` join tables ✅ (correct)
- XLSX import: Parses from `vendor_comments` column
- XCCDF import: Parses from `VulnDiscussion` text
- XCCDF export: Appends to `VulnDiscussion` text
- Spreadsheet export: ?

**Issues:**
- Text embedding is fragile (regex parsing)
- Multiple sources of truth
- Import must parse text, create relationships, then clean up text

---

### Problem 3: Two Different Import Workflows

**SRG-based import** (from_mapping):
- Import ALL SRG requirements as templates (263 rules)
- Each has empty descriptions/checks
- User authors on top

**File-based import** (from_spreadsheet / from_xccdf):
- Import ONLY authored controls (13 rules)
- Import ONLY satisfied requirements mentioned (251 rules)
- Total: 264 rules (not 263+13=276)

**Confusion:** Different workflows, different results, hard to reason about

---

### Problem 4: No Clear "Update" vs "Create" Distinction

**User wants:**
- Export component
- Edit offline
- Re-import to UPDATE same component

**Current behavior:**
- Import ALWAYS creates new component
- No "update from file" functionality
- Causes duplicate components

---

## Clean Architecture Proposal

### Core Concept: Separate Template from Content

```ruby
# SRG Requirement (Template)
class SrgRule
  # The requirement definition from DISA
  - version (SRG-OS-000023)
  - title (requirement text)
  - cci_id
end

# Component Rule (Authored Content)
class Rule
  belongs_to :srg_rule  # Which requirement this addresses
  has_many :satisfies   # Other requirements this also satisfies

  # Authored content
  - status
  - title (component-specific)
  - vuln_discussion
  - check_content
  - fixtext
end
```

**Key insight:** SRG requirements and authored controls are DIFFERENT THINGS

---

### Proposed Changes

#### Change 1: Import Strategy

**Instead of:**
```ruby
# Import ALL 263 SRG templates
# Then add 13 authored controls
# Result: 276 rules
```

**Do:**
```ruby
# Import ONLY the 13 authored controls
# Each links to its SRG requirement via srg_rule_id
# Satisfaction relationships point to OTHER rules
# UI shows: 13 authored + 251 satisfied (via relationships)
```

**Benefit:** No duplicate template rules, cleaner data model

---

#### Change 2: Satisfaction Import/Export

**Instead of:**
- Embed "Satisfies:" in text fields
- Parse text on import
- Clean up text after parsing

**Do:**
```ruby
# EXPORT
def export_with_satisfactions(rule)
  vuln_text = rule.vuln_discussion
  if rule.satisfies.any?
    vuln_text += "\n\nSatisfies: #{rule.satisfies.map(&:version).join(', ')}"
  end
  vuln_text  # Return modified text, don't save to DB
end

# IMPORT
def import_with_satisfactions(vuln_text)
  # Parse satisfactions
  satisfies_list = extract_satisfactions(vuln_text)

  # Clean text BEFORE saving
  clean_text = vuln_text.gsub(/\n\nSatisfies:.*$/m, '')

  # Return both
  {
    vuln_discussion: clean_text,
    satisfactions: satisfies_list
  }
end
```

**Benefit:** Clear separation, no database pollution

---

#### Change 3: Unified Import Interface

```ruby
class Component
  # Single entry point for all imports
  def import_from_file(file)
    case detect_format(file)
    when :xccdf
      import_from_xccdf(file)
    when :xlsx
      import_from_spreadsheet(file)
    when :csv
      import_from_spreadsheet(file)
    end
  end

  private

  def import_from_xccdf(file)
    parsed = parse_xccdf(file)

    # Extract metadata
    self.name = parsed.title
    self.prefix = extract_prefix(parsed)

    # Import rules
    parsed.groups.each do |group|
      create_rule_from_xccdf_group(group)
    end

    # Create satisfactions
    create_satisfactions_from_parsed_data(parsed)
  end

  def create_rule_from_xccdf_group(group)
    # Single method to create complete rule
    # No separate template creation
  end
end
```

**Benefit:** DRY, testable, clear flow

---

#### Change 4: Update vs Create

```ruby
class Component
  # New method for updates
  def update_from_file(file)
    parsed = parse_file(file)

    parsed.rules.each do |rule_data|
      existing_rule = rules.find_by(version: rule_data.version)

      if existing_rule
        # UPDATE existing
        existing_rule.update!(rule_data)
      else
        # CREATE new
        rules.create!(rule_data)
      end
    end

    # Update satisfactions
    sync_satisfactions(parsed)
  end
end
```

**Benefit:** Supports edit → export → import workflow

---

## Implementation Strategy

### Option A: Refactor Now (2-3 hours)
- Rewrite `from_xccdf` and `from_spreadsheet` cleanly
- Fix duplication issues
- Add update_from_file
- Risk: Might break existing imports

### Option B: Incremental Cleanup (4-6 hours)
- Keep current code working
- Add new clean methods alongside
- Migrate gradually
- Deprecate old methods
- Risk: Code duplication during transition

### Option C: Ship Current, Refactor in v2.3.1 (safest)
- Current XCCDF import works (tested!)
- Commit as-is
- Plan refactor for next release
- Benefit: Get feature out, refactor carefully

---

## Recommendation

**I recommend Option C:**

1. **Today:** Commit working XCCDF import (it works!)
2. **v2.3.1:** Clean refactor of import/export architecture
3. **v2.3.1:** Add update_from_file functionality
4. **v2.3.1:** Add UX improvements (bulk SRG IDs, shift-click)

**Why:**
- Current code works (verified!)
- Refactoring while tired = bugs
- Better to ship working feature, refactor fresh
- We have 11 commits already on v2.3.0 - time to push

---

## Questions

1. **Ship current XCCDF import now?** It works correctly, even if code is messy
2. **Refactor in v2.3.1?** Clean architecture, add update_from_file
3. **Priority:** Import/export refactor vs markdown editor vs layout improvements?

---

**Status:** Ready for decision
