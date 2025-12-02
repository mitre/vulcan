# Find & Replace Architecture

**Created:** 2025-11-30
**Status:** Implementation In Progress
**Reference:** VS Code / Monaco Editor patterns

---

## Overview

Find & Replace allows users to search for text across all requirements in a component and replace matches individually or in bulk. The implementation follows VS Code's proven patterns with a clear separation between stateless backend API and stateful frontend.

---

## Architecture Decision

### Client-Side Navigation

**Decision:** Navigation state (current match index, loop behavior) lives in the **frontend (Pinia store)**, NOT the Rails backend.

**Rationale:**
1. Matches VS Code's proven pattern - state in editor, not server
2. Keeps Rails API stateless and simpler
3. Faster UX - no round-trip for Next/Previous
4. Easier to swap UI frameworks (Bootstrap → NuxtUI) - logic stays in store

**Implication:** Backend provides atomic operations. Frontend orchestrates the workflow.

---

## Layer Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│  LAYER 0: Rails Service (app/services/find_replace_service.rb)     │
│  - ALL business logic (text manipulation, matching)                 │
│  - Stateless - each call is independent                            │
└─────────────────────────────────────────────────────────────────────┘
                              ↓ JSON
┌─────────────────────────────────────────────────────────────────────┐
│  LAYER 1: Rails Controller (app/controllers/api/find_replace_*)    │
│  - HTTP endpoints, authentication, authorization                    │
│  - Delegates to service                                             │
└─────────────────────────────────────────────────────────────────────┘
                              ↓ HTTP
┌─────────────────────────────────────────────────────────────────────┐
│  LAYER 2: API Client (apis/findReplace.api.ts)                      │
│  - Pure HTTP calls, no state                                        │
│  - Framework agnostic                                               │
└─────────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────────┐
│  LAYER 3: Pinia Store (stores/findReplace.store.ts)                 │
│  - ALL frontend state lives here                                    │
│  - Navigation, undo stack, match tracking                           │
│  - Framework agnostic (works with Vue, Nuxt)                        │
└─────────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────────┐
│  LAYER 4: Composable (composables/useFindReplace.ts)                │
│  - THIN wrapper around store                                        │
│  - NO business logic                                                │
└─────────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────────┐
│  LAYER 5: UI Component (components/requirements/FindReplaceModal)   │
│  - ONLY rendering and user input                                    │
│  - Easy to swap: Bootstrap → NuxtUI                                 │
└─────────────────────────────────────────────────────────────────────┘
```

**UI Framework Swaps:** When switching from Bootstrap to NuxtUI, only Layer 5 changes. Layers 0-4 stay exactly the same.

---

## Backend Implementation

### Files

| File | Purpose | Status |
|------|---------|--------|
| `app/services/find_replace_service.rb` | Business logic | ✅ Done |
| `app/controllers/api/find_replace_controller.rb` | API endpoints | ✅ Done |
| `spec/services/find_replace_service_spec.rb` | Service tests | ✅ 21 tests |
| `spec/requests/api/find_replace_spec.rb` | Controller tests | ✅ 20 tests |

### API Endpoints

| Method | Path | Purpose |
|--------|------|---------|
| POST | `/api/components/:id/find_replace/find` | Find all matches |
| POST | `/api/components/:id/find_replace/replace_instance` | Replace single match |
| POST | `/api/components/:id/find_replace/replace_field` | Replace all in one field |
| POST | `/api/components/:id/find_replace/replace_all` | Replace all matches |
| POST | `/api/components/:id/find_replace/undo` | Undo last replace | ✅ Done |

### Searchable Fields

```ruby
SEARCHABLE_FIELDS = {
  'title' => { path: :title, nested: false },
  'fixtext' => { path: :fixtext, nested: false },
  'vendor_comments' => { path: :vendor_comments, nested: false },
  'status_justification' => { path: :status_justification, nested: false },
  'artifact_description' => { path: :artifact_description, nested: false },
  'check' => { path: :content, nested: :checks },
  'vuln_discussion' => { path: :vuln_discussion, nested: :disa_rule_descriptions },
  'mitigations' => { path: :mitigations, nested: :disa_rule_descriptions }
}
```

### API Response Format

**Find Response:**
```json
{
  "total_matches": 47,
  "total_rules": 12,
  "matches": [
    {
      "rule_id": 456,
      "rule_identifier": "SV-001",
      "match_count": 3,
      "instances": [
        {
          "field": "fixtext",
          "instances": [
            {
              "index": 45,
              "length": 4,
              "text": "sshd",
              "context": "...configure sshd to...",
              "instance_index": 0
            }
          ]
        }
      ]
    }
  ]
}
```

**Replace Response:**
```json
{
  "success": true,
  "rule": { /* updated rule via Blueprinter */ }
}
```

---

## Frontend Implementation

### Files

| File | Purpose | Status |
|------|---------|--------|
| `apis/findReplace.api.ts` | HTTP client | ✅ Done |
| `stores/findReplace.store.ts` | State management | ✅ Done |
| `composables/useFindReplace.ts` | Composable wrapper | ✅ Done |
| `components/requirements/FindReplaceModal.vue` | UI | Refactor needed |

### State Interface

```typescript
interface Match {
  ruleId: number;
  ruleIdentifier: string;
  field: string;
  index: number;          // Position in text
  length: number;
  text: string;           // The matched text
  context: string;        // Surrounding text
  instanceIndex: number;  // Which occurrence (0-based)
}

interface FindReplaceState {
  // Search parameters
  searchText: string;
  replaceText: string;
  caseSensitive: boolean;
  fields: string[];

  // Results
  matches: Match[];       // Flattened list of all matches
  totalMatches: number;
  totalRules: number;

  // Navigation (client-side)
  currentIndex: number;
  loop: boolean;

  // Loading states
  isSearching: boolean;
  isReplacing: boolean;

  // Undo stack
  undoStack: UndoEntry[];

  // Per-instance custom replacements
  customReplacements: Map<string, string>;
}

interface UndoEntry {
  ruleId: number;
  field: string;
  previousValue: string;
  timestamp: Date;
}
```

### Store Actions

```typescript
// Search
async function search(componentId: number): Promise<void>

// Navigation (no API call - instant)
function nextMatch(): void
function prevMatch(): void
function goToMatch(index: number): void

// Computed helpers
const currentMatch: ComputedRef<Match | null>
const hasNext: ComputedRef<boolean>
const hasPrev: ComputedRef<boolean>
const progress: ComputedRef<string>  // "3 of 47"

// Replace operations
async function replaceOne(componentId: number): Promise<void>
async function replaceOneWithCustom(componentId: number, customText: string): Promise<void>
function skip(): void

async function replaceAll(componentId: number, auditComment?: string): Promise<void>

// Undo
async function undoLast(componentId: number): Promise<void>
const canUndo: ComputedRef<boolean>

// Custom replacement per match
function setCustomReplacement(matchKey: string, text: string): void
function getCustomReplacement(matchKey: string): string | null

// Reset
function reset(): void
```

### Key Behaviors

**After replaceOne():**
1. Push current state to undoStack (client-side)
2. Call API to replace instance
3. Re-run search() to get updated positions
4. Adjust currentIndex (matches may have shifted)

**Navigation:**
```typescript
function nextMatch() {
  if (currentIndex < matches.length - 1) {
    currentIndex++;
  } else if (loop) {
    currentIndex = 0;
  }
  // No API call - instant
}
```

**Custom Replacement:**
```typescript
async function replaceOneWithCustom(componentId: number, customText: string) {
  const match = currentMatch.value;
  await api.replaceInstance(componentId, {
    search: searchText,
    ruleId: match.ruleId,
    field: match.field,
    instanceIndex: match.instanceIndex,
    replacement: customText,  // Custom instead of global replaceText
  });
  await search(componentId);  // Refresh matches
}
```

---

## User Workflow

### Step-by-Step Usage

1. **Open Find/Replace** - Via toolbar button or Ctrl+H
2. **Enter search text** → Results load ("47 matches in 12 rules")
3. **Enter replace text** (optional)
4. **Navigate matches:**
   - `n` / `↓` / Next button → Go to next match
   - `p` / `↑` / Previous button → Go to previous match
   - Click result card → Jump to that match
5. **At each match:**
   - **Replace** (`r`) → Replace with replaceText, advance
   - **Skip** (`s`) → Advance without replacing
   - **Replace with Custom** (pencil) → Use different text for this one
   - **Undo** (`Ctrl+Z`) → Revert last replacement
6. **Bulk operations:**
   - **Replace All** → Replace everything (with confirmation)

### Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `Ctrl+H` | Open Find/Replace |
| `Enter` | Execute search |
| `Esc` | Close modal |
| `n` / `↓` | Next match |
| `p` / `↑` | Previous match |
| `r` | Replace current |
| `s` | Skip current |
| `Ctrl+Z` | Undo last |

---

## Undo Implementation

### Client-Side Stack

The frontend maintains an undo stack for immediate undo:

```typescript
interface UndoEntry {
  ruleId: number;
  field: string;
  previousValue: string;
  timestamp: Date;
}

// Before each replace
undoStack.push({
  ruleId: match.ruleId,
  field: match.field,
  previousValue: currentFieldValue,
  timestamp: new Date()
});
```

### Server-Side (via Audited gem)

Rules are already audited. The undo endpoint uses audit history:

```ruby
def undo
  rule = @component.rules.find(params[:rule_id])
  last_audit = rule.audits.where(comment: /Find & Replace/).last

  if last_audit
    rule.update!(last_audit.audited_changes.transform_values(&:first))
    render json: { success: true, rule: RuleBlueprint.render_as_hash(rule) }
  else
    render json: { success: false, error: 'Nothing to undo' }
  end
end
```

---

## Reference Implementation

Based on VS Code / Monaco Editor:

| VS Code File | Purpose | Vulcan Equivalent |
|--------------|---------|-------------------|
| `findState.ts` | State management | `stores/findReplace.store.ts` |
| `findController.ts` | Orchestration | `composables/useFindReplace.ts` |
| `findModel.ts` | Business logic | `services/find_replace_service.rb` |
| `findWidget.ts` | UI | `FindReplaceModal.vue` |

### Key Patterns Borrowed

1. **State is central** - Everything flows through state object
2. **Navigation is client-side** - Just index through matches array
3. **Replace triggers re-scan** - After any replace, refresh matches
4. **Undo stops are explicit** - Each replace is undoable
5. **Granular events** - Only emit what changed

---

## Testing

### Backend Tests

```bash
# Service tests (21 tests)
bundle exec rspec spec/services/find_replace_service_spec.rb

# Controller tests (20 tests)
bundle exec rspec spec/requests/api/find_replace_spec.rb
```

### Frontend Tests (TODO)

```bash
# Store tests
pnpm vitest run stores/findReplace.store.spec.ts

# Composable tests
pnpm vitest run composables/useFindReplace.spec.ts
```

---

## Future Enhancements

1. **Monaco Editor Integration** - Replace textarea with Monaco for syntax highlighting and built-in find/replace
2. **Regex Support** - Add regex option to search
3. **Preview Mode** - Show before/after diff before confirming
4. **Batch Replace** - Select multiple matches, replace selected only
5. **Search History** - Remember recent searches

---

## Files Reference

### Backend
- `app/services/find_replace_service.rb`
- `app/controllers/api/find_replace_controller.rb`
- `config/routes.rb` (API routes)
- `spec/services/find_replace_service_spec.rb`
- `spec/requests/api/find_replace_spec.rb`

### Frontend
- `app/javascript/apis/findReplace.api.ts`
- `app/javascript/stores/findReplace.store.ts`
- `app/javascript/composables/useFindReplace.ts`
- `app/javascript/components/requirements/FindReplaceModal.vue`
- `app/javascript/components/requirements/FindReplaceResultCard.vue`

### Documentation
- `docs-spa/FIND-REPLACE-ARCHITECTURE.md` (this file)
- `FIND-REPLACE-REFERENCE-IMPLEMENTATIONS.md` (detailed VS Code analysis)
