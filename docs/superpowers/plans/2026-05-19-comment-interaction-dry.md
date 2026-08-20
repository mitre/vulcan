# Centralize Comment Interaction System — DRY Plan

**Goal:** Unify the two divergent composer patterns (row-based vs id-based) into a single `composerState` object managed by `ReplyComposerMixin`, then migrate all 4 consumers and update CommentComposerModal to read from the unified state.

**Why:** 4 screens mount CommentComposerModal with 2 different state shapes (Pattern A: `composerReplyRow` row object; Pattern B: `composerReplyToId` + `composerSection` + `componentComposerActive` scattered data). Any bug fix or feature change must be applied 4 times. The event chain has an inconsistency: RuleReviews emits a bare reviewId while other sources emit full row objects.

**Audit date:** 2026-05-19 (updated). Full inventory of 4 consumers, 3 event passthrough layers, 7 test files.

---

## Architecture

### Current (two incompatible patterns)

```
Pattern A (row-based):
  ComponentComments:  composerReplyRow (Object) + composerNewComponent (Boolean)
  UserComments:       composerReplyRow (Object)

Pattern B (id-based):
  ProjectComponent:   composerReplyToId (Number) + composerSection (String) + componentComposerActive (Boolean)
  RulesCodeEditorView: composerReplyToId (Number) + composerSection (String) + componentComposerActive (Boolean)
```

### Target (unified composerState)

```
ReplyComposerMixin:
  data:
    composerState: {
      mode: null,         // 'reply' | 'new-comment' | 'component' | null
      reviewId: null,     // parent review ID (reply mode)
      ruleId: null,       // target rule
      componentId: null,  // target component
      section: null,      // section (new-comment mode)
      ruleName: null,     // display string for modal header
    }

  methods:
    openReplyComposer({ reviewId, ruleId, componentId, ruleName })
    openSectionComposer({ ruleId, componentId, section, ruleName })
    openComponentComposer(componentId)
    closeComposer()
    onComposerPosted()   — calls afterComposerPosted() hook
    onComposerHidden()   — alias for closeComposer()

  computed:
    composerActive       — Boolean, true when mode !== null
    composerProps        — Object, maps composerState to CommentComposerModal props

CommentComposerModal:
  Accepts composerState directly (or individual props mapped by composerProps computed)
  No change to its internal logic — just standardize what flows in

Consumers:
  ComponentComments:     mixin + afterComposerPosted() override (fetch + split-mode)
  ProjectComponent:      mixin + afterComposerPosted() override (axios rule refresh)
  RulesCodeEditorView:   mixin + afterComposerPosted() override ($root.$emit rule refresh)
  UserComments:          mixin + afterComposerPosted() override (fetch)
```

### Event chain standardization

```
CommentThread emits @reply(parentReviewId)
    ↓
RuleReviews / TriageSplitView receives — builds {reviewId, ruleId, componentId, ruleName}
    ↓
$emit('open-reply-composer', composerPayload)   ← ALWAYS an object, never a bare ID
    ↓
Consumer calls this.openReplyComposer(payload)
```

---

## Full File Inventory

### Files to CREATE
| File | Purpose |
|------|---------|
| `app/javascript/mixins/ReplyComposerMixin.vue` | Unified mixin |
| `spec/javascript/mixins/ReplyComposerMixin.spec.js` | Mixin tests |

### Files to MODIFY (consumers — Task 2)
| File | Current pattern | Changes |
|------|----------------|---------|
| `ComponentComments.vue` | Pattern A: composerReplyRow, composerNewComponent | Replace with mixin. Keep afterComposerPosted (fetch + thread refresh + split-mode) |
| `ProjectComponent.vue` | Pattern B: composerReplyToId, composerSection, componentComposerActive | Replace with mixin. Keep afterComposerPosted (axios rule refresh) |
| `RulesCodeEditorView.vue` | Pattern B: composerReplyToId, composerSection, componentComposerActive | Replace with mixin. Keep afterComposerPosted ($root.$emit refresh) |
| `UserComments.vue` | Pattern A: composerReplyRow | Replace with mixin. Keep afterComposerPosted (fetch + thread refresh) |

### Files to MODIFY (event emitters — Task 2)
| File | Current emission | Changes |
|------|-----------------|---------|
| `RuleReviews.vue` | `$emit('open-reply-composer', parentId)` bare Number | Change to emit `{ reviewId: parentId, ruleId, componentId, ruleName }` object |
| `ControlsSidepanels.vue` | `$emit('open-reply-composer', $event)` passthrough | No change needed (passes through whatever it receives) |
| `TriageSplitView.vue` | `$emit('open-reply-composer', activeComment)` full row | Change to emit standardized `{ reviewId, ruleId, componentId, ruleName }` |
| `CommentTriageModal.vue` | `$emit('open-reply-composer', review)` full review | Change to emit standardized object |

### Files to MODIFY (CommentComposerModal — Task 1)
| File | Changes |
|------|---------|
| `CommentComposerModal.vue` | No API change needed — props stay the same. The `composerProps` computed in the mixin maps composerState to the existing props. |

### Files to MODIFY (auto-refresh — Task 3)
| File | Changes |
|------|---------|
| `CommentThread.vue` | Add watcher on responsesCount → auto-refetch |
| `ComponentComments.vue` | Remove `$refs.thread.refresh()` |
| `UserComments.vue` | Remove `$refs.thread.refresh()` |

### Test files to UPDATE
| Test file | What changes |
|-----------|-------------|
| `spec/javascript/mixins/ReplyComposerMixin.spec.js` | New — tests unified composerState |
| `spec/javascript/components/triage/TriageSplitView.spec.js` | Update open-reply-composer emission shape |
| `spec/javascript/components/rules/RuleReviews.spec.js` | Update open-reply-composer emission shape |
| `spec/javascript/components/components/CommentTriageModal.spec.js` | Update open-reply-composer emission shape |
| `spec/javascript/components/shared/CommentThread.spec.js` | Add auto-refresh watcher test |
| `spec/javascript/components/components/CommentComposerModal.spec.js` | May need minor prop test updates |

### Test files that should NOT need changes
| Test file | Why |
|-----------|-----|
| `spec/javascript/components/components/CommentDedupBanner.spec.js` | Internal reply click handled within modal |

---

## Task 1: Extract ReplyComposerMixin with unified composerState (sp:3, ~20 min)

Create the mixin with the unified state object and standard methods.

### composerState shape
```javascript
{
  mode: null,         // 'reply' | 'new-comment' | 'component' | null
  reviewId: null,     // parent review ID (reply mode only)
  ruleId: null,       // rule being commented on
  componentId: null,  // component being commented on
  section: null,      // pre-selected section (new-comment mode)
  ruleName: null,     // display name for modal header
}
```

### Methods
```javascript
openReplyComposer({ reviewId, ruleId, componentId, ruleName })
openSectionComposer({ ruleId, componentId, section, ruleName })
openComponentComposer(componentId)
closeComposer()
onComposerPosted()     // clears state, calls afterComposerPosted(reviewId)
onComposerHidden()     // alias for closeComposer
```

### Computed
```javascript
composerActive       // mode !== null
composerProps        // maps composerState → CommentComposerModal prop names
```

### Hook
```javascript
afterComposerPosted(parentReviewId)  // no-op in mixin, consumers override
```

### Files
- Create: `app/javascript/mixins/ReplyComposerMixin.vue`
- Create: `spec/javascript/mixins/ReplyComposerMixin.spec.js`

---

## Task 2: Migrate all consumers + standardize event emissions (sp:5, ~35 min)

### Order of migration (one at a time, test after each)
1. **UserComments.vue** (simplest — reply-only, Pattern A)
2. **ComponentComments.vue** (Pattern A + split-mode + component composer)
3. **ProjectComponent.vue** (Pattern B — biggest shape change)
4. **RulesCodeEditorView.vue** (Pattern B — mirrors ProjectComponent)

### For each consumer
1. Add `ReplyComposerMixin` to mixins
2. Delete local composer data properties
3. Delete local composer methods (openReplyComposer, onComposerPosted, etc.)
4. Keep `afterComposerPosted()` override with screen-specific refresh logic
5. Update template: `<CommentComposerModal>` props bind via `composerProps` computed
6. Update `v-if` mount condition to use `composerActive`

### Event emitters to standardize
- `RuleReviews.vue` — change `$emit('open-reply-composer', parentId)` to emit object
- `TriageSplitView.vue` — change to emit standardized object
- `CommentTriageModal.vue` — change to emit standardized object

### Files
- Modify: ComponentComments.vue, ProjectComponent.vue, RulesCodeEditorView.vue, UserComments.vue
- Modify: RuleReviews.vue, TriageSplitView.vue, CommentTriageModal.vue
- Test: TriageSplitView.spec.js, RuleReviews.spec.js, CommentTriageModal.spec.js (emission shape)

---

## Task 3: Auto-refresh CommentThread on responses_count change (sp:2, ~12 min)

### Current (duplicated)
```javascript
// In ComponentComments + UserComments:
const thread = this.$refs[`thread-${id}`];
thread?.refresh?.();
```

### Target
```javascript
// In CommentThread.vue:
watch: {
  responsesCount(newVal, oldVal) {
    if (newVal > oldVal && this.expanded) this.fetchResponses();
  }
}
```

### Files
- Modify: CommentThread.vue (add watcher)
- Modify: ComponentComments.vue, UserComments.vue (remove $refs.thread.refresh())
- Test: CommentThread.spec.js (new test for auto-refresh)

---

## Dependency Graph
```
Task 1 (extract mixin + composerState)
    ↓
Task 2 (migrate consumers + standardize events)
    ↓
Task 3 (auto-refresh CommentThread)
```

## Estimated Total: sp:10, ~67 min Claude-pace
