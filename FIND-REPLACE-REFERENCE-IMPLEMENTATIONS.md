# Find & Replace Reference Implementations

**IMPORTANT**: This document must be kept updated with reference implementations and architecture patterns for Find & Replace functionality.

---

## Primary Reference: VS Code / Monaco Editor

The Monaco Editor (used by VS Code) is the gold standard for Find & Replace UX.

### Repository
- **GitHub**: https://github.com/microsoft/vscode
- **Monaco**: https://github.com/microsoft/monaco-editor

### Key Source Files

Located in `src/vs/editor/contrib/find/browser/`:

| File | Purpose |
|------|---------|
| `findController.ts` | Main controller, orchestrates actions |
| `findState.ts` | State management (current match, count, options) |
| `findModel.ts` | Core logic: match tracking, replace, navigation |
| `findWidget.ts` | UI widget |
| `findDecorations.ts` | Visual highlights for matches |
| `replacePattern.ts` | Replace pattern logic |
| `replaceAllCommand.ts` | Command for replace-all |
| `findWidgetSearchHistory.ts` | Search history |

### Direct Links to Source
- findState.ts: https://github.com/microsoft/vscode/blob/main/src/vs/editor/contrib/find/browser/findState.ts
- findController.ts: https://github.com/microsoft/vscode/blob/main/src/vs/editor/contrib/find/browser/findController.ts
- findModel.ts: https://github.com/microsoft/vscode/blob/main/src/vs/editor/contrib/find/browser/findModel.ts

---

## Architecture Pattern (from VS Code)

### State Management (`findState.ts`)

**Tracked State:**
- `searchString` / `replaceString`
- `matchesPosition` - Current match index (1-based)
- `matchesCount` - Total matches found
- `currentMatch` - Current match range
- `isSearching` - Loading state
- Options: `matchCase`, `wholeWord`, `regex`, `preserveCase`
- `loop` - Whether navigation wraps around
- `searchScope` - Range constraints

**Navigation Logic:**
```typescript
canNavigateBack(): boolean {
  return this.loop || this.matchesPosition > 1;
}

canNavigateForward(): boolean {
  return this.loop || this.matchesPosition < this.matchesCount;
}
```

**Event System:**
- Uses `Emitter<FindReplaceStateChangedEvent>`
- Event flags which properties changed (granular)
- Includes `moveCursor` and `updateHistory` flags

### Controller Flow (`findController.ts`)

**User Action → State → Model → Editor:**

1. User Action (keyboard/button)
2. EditorAction/EditorCommand triggered
3. Controller method called
4. `this._state.change()` updates state
5. Model performs matching/replacement
6. Editor reflects changes

**Single Replace:**
```typescript
replace(): boolean {
  if (this._model) {
    this._model.replace();
    return true;
  }
  return false;
}
```

**Replace All:**
- Validates file size first (`isTooLargeForHeapOperation`)
- Calls `this._model.replaceAll()`

**Undo Integration:**
```typescript
// After navigation
controller.editor.pushUndoStop();
```

### Model Logic (`findModel.ts`)

**Match Tracking:**
- Matches stored in `FindDecorations` class
- Forward/backward navigation with wrap-around
- Empty matches handled by advancing position

**Single Replace Flow:**
```
1. Locate next match
2. Verify selection overlaps match range
3. Build replacement string via pattern
4. Execute ReplaceCommand
5. Update decorations start position
6. Re-scan document (research)
```

**Replace All Strategies:**
- **Large files**: Global regex on entire text
- **Regular**: Collect all ranges, build replacements, execute `ReplaceAllCommand`

**Post-Replacement Sync:**
```typescript
this.research(false); // Re-scan to update:
// - Current match position
// - Total match count
// - Decoration positions
```

**Undo Wrapping:**
```typescript
ignoreModelContentChanged = true;
pushUndoStop();
executeCommand();
pushUndoStop();
ignoreModelContentChanged = false;
```

---

## UX Patterns Summary

### Step-by-Step Navigation
1. Find returns all matches with positions
2. User navigates: Next (n/Enter/F3) / Previous (p/Shift+F3)
3. Current match highlighted, can scroll to view
4. At each match: Replace / Skip / Replace with Custom

### Per-Instance Decisions
- **Replace**: Apply replacement to current match, advance to next
- **Skip**: Move to next match without replacing
- **Replace with Custom**: User can modify replacement text for this instance only
- **Replace All**: Bulk operation with confirmation

### Undo Capability
- Each replace pushes undo stop
- User can Ctrl+Z to undo last replacement
- Replace All is atomic (single undo)

### State Persistence
- Search term persists in widget
- Options (case, regex, whole word) persist
- History of recent searches available

---

## Vulcan Implementation Plan

---

## ARCHITECTURE DECISION: Client-Side Navigation

**Decision Date:** 2025-11-30

**Decision:** Navigation state (current match index, loop behavior) lives in the **frontend (Pinia store)**, NOT the Rails backend.

**Rationale:**
1. Matches VS Code's proven pattern - state in editor, not server
2. Keeps Rails API stateless and simpler
3. Faster UX - no round-trip for Next/Previous
4. Easier to swap UI frameworks (Bootstrap → NuxtUI) - logic stays in store

**Implication:** Backend provides atomic operations (find, replace_instance, replace_all). Frontend orchestrates the workflow.

---

## Backend (Rails) - STATELESS API

### Already Implemented
| Endpoint | Purpose |
|----------|---------|
| `POST find` | Returns all matches with positions and context |
| `POST replace_instance` | Replace single match by rule_id + field + index |
| `POST replace_field` | Replace all matches in one field of one rule |
| `POST replace_all` | Replace all matches across component |

### Needed Additions

**1. Undo Last Replace Endpoint**
```ruby
# POST /api/components/:component_id/find_replace/undo
# Uses audited gem to revert last change
def undo
  # Find most recent find/replace audit
  # Revert the change
  # Return updated rule
end
```

**2. Preview Replacement Endpoint (Optional)**
```ruby
# POST /api/components/:component_id/find_replace/preview
# Returns what text would look like after replacement WITHOUT saving
def preview
  # Build replacement but don't persist
  # Return preview of before/after
end
```

**3. Batch Replace Endpoint (Optional)**
```ruby
# POST /api/components/:component_id/find_replace/batch
# Replace multiple specific instances in one transaction
# Useful for "Replace Selected" feature
def batch
  # Accept array of {rule_id, field, index, replacement}
  # Replace all in single transaction
  # Return updated rules
end
```

---

## Frontend Architecture - UI FRAMEWORK AGNOSTIC

The frontend is split into layers to make UI framework swaps easy:

```
┌─────────────────────────────────────────────────────────────────────┐
│  LAYER 1: API Client (apis/findReplace.api.ts)                      │
│  - Pure HTTP calls, no state                                        │
│  - Framework agnostic (works with any UI)                           │
└─────────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────────┐
│  LAYER 2: Pinia Store (stores/findReplace.store.ts)                 │
│  - ALL state lives here                                             │
│  - ALL business logic lives here                                    │
│  - Navigation, undo stack, match tracking                           │
│  - Framework agnostic (Pinia works with Vue, Nuxt, etc)             │
└─────────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────────┐
│  LAYER 3: Composable (composables/useFindReplace.ts)                │
│  - THIN wrapper around store                                        │
│  - Convenience methods, computed properties                         │
│  - NO business logic - just re-exports store                        │
└─────────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────────┐
│  LAYER 4: UI Component (Bootstrap, NuxtUI, etc)                     │
│  - ONLY rendering and user input                                    │
│  - Calls composable methods                                         │
│  - Easy to swap: just rebuild this layer                            │
└─────────────────────────────────────────────────────────────────────┘
```

**When switching from Bootstrap to NuxtUI:**
- Layers 1-3 stay EXACTLY the same
- Only Layer 4 (UI component) needs to be rebuilt
- All logic, state, and API calls are preserved

---

## Pinia Store - Full Implementation

```typescript
// stores/findReplace.store.ts

interface Match {
  ruleId: number;
  ruleIdentifier: string;
  field: string;
  index: number;          // Position in text
  length: number;
  text: string;           // The matched text
  context: string;        // Surrounding text for display
  instanceIndex: number;  // Which occurrence in this field (0-based)
}

interface FindReplaceState {
  // Search parameters
  searchText: string;
  replaceText: string;
  caseSensitive: boolean;
  fields: string[];       // Which fields to search

  // Results
  matches: Match[];
  totalMatches: number;
  totalRules: number;

  // Navigation
  currentIndex: number;   // Current position in matches array
  loop: boolean;          // Wrap around at ends

  // Loading states
  isSearching: boolean;
  isReplacing: boolean;

  // Undo stack (client-side for immediate undo)
  undoStack: UndoEntry[];

  // Per-instance custom replacements
  customReplacements: Map<string, string>; // matchKey -> custom text
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

// Navigation (no API call - just index change)
function nextMatch(): void
function prevMatch(): void
function goToMatch(index: number): void

// Current match helpers
const currentMatch: ComputedRef<Match | null>
const hasNext: ComputedRef<boolean>
const hasPrev: ComputedRef<boolean>
const progress: ComputedRef<string>  // "3 of 47"

// Replace operations
async function replaceOne(componentId: number): Promise<void>
async function replaceOneWithCustom(componentId: number, customText: string): Promise<void>
function skip(): void  // Same as nextMatch, semantic alias

async function replaceAll(componentId: number, auditComment?: string): Promise<void>

// Undo
async function undoLast(componentId: number): Promise<void>
function canUndo: ComputedRef<boolean>

// Custom replacement per match
function setCustomReplacement(matchKey: string, text: string): void
function getCustomReplacement(matchKey: string): string | null
function clearCustomReplacements(): void

// Reset
function reset(): void
```

### Key Behaviors

**After replaceOne():**
1. Push to undoStack (client-side)
2. Call API to replace
3. Re-run search() to get updated positions
4. Adjust currentIndex if needed (matches may have shifted)

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
// User wants different text for this specific match
function replaceOneWithCustom(componentId: number, customText: string) {
  const match = currentMatch.value;
  await api.replaceInstance(componentId, {
    search: searchText,
    ruleId: match.ruleId,
    field: match.field,
    instanceIndex: match.instanceIndex,
    replacement: customText,  // Custom text instead of global replaceText
  });
  await search(componentId);  // Refresh
}
```

---

## User Workflow

1. **Open Find/Replace modal**
2. **Enter search text** → Results load, showing "47 matches in 12 rules"
3. **Enter replace text** (optional)
4. **Navigate matches:**
   - `n` or `↓` or "Next" button → Go to next match
   - `p` or `↑` or "Previous" button → Go to previous match
   - Click on result card → Jump to that match
5. **At each match, user can:**
   - **Replace** (`r` or button) → Replace with global replaceText, advance
   - **Skip** (`s` or button) → Just advance, no change
   - **Replace with Custom** (pencil icon) → Edit replacement for this one only
   - **Undo** (`Ctrl+Z` or button) → Revert last replacement
6. **Or bulk operations:**
   - **Replace All** → Replace everything (with confirmation)
   - **Replace Selected** (future) → Replace checked items only

---

## API Contract

### Request/Response Examples

**Find:**
```json
// POST /api/components/123/find_replace/find
// Request:
{ "search": "sshd", "case_sensitive": false, "fields": ["fixtext", "check"] }

// Response:
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
            { "index": 45, "length": 4, "text": "sshd", "context": "...configure sshd to...", "instance_index": 0 },
            { "index": 120, "length": 4, "text": "sshd", "context": "...restart sshd service...", "instance_index": 1 }
          ]
        }
      ]
    }
  ]
}
```

**Replace Instance:**
```json
// POST /api/components/123/find_replace/replace_instance
// Request:
{
  "search": "sshd",
  "rule_id": 456,
  "field": "fixtext",
  "instance_index": 0,
  "replacement": "openssh-daemon",
  "audit_comment": "Standardize terminology"
}

// Response:
{ "success": true, "rule": { ... } }
```

**Undo:**
```json
// POST /api/components/123/find_replace/undo
// Request:
{ "rule_id": 456 }

// Response:
{ "success": true, "rule": { ... }, "reverted_field": "fixtext" }
```

---

## Key Lessons

1. **State is central** - Everything flows through state object
2. **Navigation is client-side** - Just index through matches array
3. **Replace triggers re-scan** - After any replace, refresh matches
4. **Undo stops are explicit** - Each replace is undoable
5. **Granular events** - Only emit what changed

---

## Created: 2025-11-30
## Last Updated: 2025-11-30
