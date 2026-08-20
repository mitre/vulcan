# Triage Context Panel — Implementation Plan (v2, post-review)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the triage modal with a split-pane view that shows rule content (left) alongside the comment stream + triage controls (right), so triagers don't need to context-switch to understand what a comment addresses.

**Architecture:** The triage page (`ComponentTriagePage.vue`) gets a two-mode layout: table mode (current — full-width comment queue) and split mode (new — left panel with rule content, right panel with triage form). Clicking "Triage" on any row enters split mode with that comment loaded. The existing `CommentTriageModal` form body is extracted into a reusable `CommentTriageForm.vue` used by both the modal (for backward compat from the rule editor) and the new inline panel. A new `TriageSplitView.vue` owns all split-mode state so `ComponentComments.vue` doesn't become a god component. Rule content is lazy-loaded via a conditional `?include_rule_content=true` param on `paginated_comments` — the table view never pays for rule text. The queue strip is replaced with a compact counter + prev/next navigation + dropdown (the original pill bar doesn't scale to 200 comments). Optimistic locking via `updated_at` prevents silent overwrites when two triagers work the same queue.

**Tech Stack:** Vue 2.7.16, Bootstrap-Vue 2.13.0 (`b-row`/`b-col`, `b-collapse`), existing `ControlsPageLayout.vue` pattern (slot-based flexbox grid). Rails 8, RSpec, Vitest, Playwright.

**UX research applied:** Fisheye view (focused section expanded, others collapsed with chevron affordance), bidirectional highlight (matching accent between section badge and rule content), no auto-advance on save (every major tool avoids this), counter + prev/next in header (GitHub PR / Jira pattern), `col-lg-5`/`col-lg-7` split responsive down to 1280px.

---

## Changes from v1 plan (incorporated from 5-agent review)

| Finding | Change | Task(s) |
|---|---|---|
| B1: Payload bloat (6 text fields x 200 rows) | Conditional preload via `?include_rule_content=true` | 1 |
| B2: Stale `activeComment` reference (Vue 2 reactivity) | Store `activeCommentId`, derive object via `computed` | 5 |
| B3: Queue strip pills don't scale to 200 comments | Replace with counter + prev/next + dropdown | 4 |
| B4: No concurrent-edit protection | Optimistic lock via `updated_at` check, 409 Conflict | 5, 7 |
| B5: WCAG contrast failure (opacity 0.6) | Min opacity 0.85 or muted text color (#6c757d) | 6 |
| B6: CSS custom properties don't exist in Bootstrap 4.6 | Use hardcoded Bootstrap 4 SCSS values | 6 |
| B7-B9: No error-path / regression / validation tests | Error siblings for every save path; explicit modal regression test; non-concur blocked test | 2, 5, 7, 8 |
| B10: TERMINAL_BY_RULE diverges JS↔Ruby | Reconcile and centralize in `triageVocabulary.js` | 2 |
| W1: Draft loss on pill navigation | `dirtyDraft` map + confirm dialog | 5 |
| W2: God component risk in ComponentComments | Extract `TriageSplitView.vue` | 5 |
| W3: Collapsed sections look disabled, not clickable | Chevron-right icon + pointer cursor | 3, 6 |
| W4: col-md-5 tight at 1280px | Switch to `col-lg-5`/`col-lg-7` | 5 |
| W6: CSS-class assertions ≠ behavior tests | Assert `isVisible()` not class names | 3 |
| W9: Section vocabulary in 4 places | Import from `triageVocabulary.js`, don't re-derive | 3 |
| W10: Over-extraction of admin actions | Extract decision core only; leave admin sub-forms in modal | 2 |
| W11: Save & next should be primary button | Primary (filled) = Save & next; secondary = Save | 7 |
| W12: Missing progress counter | "12 of 142 pending" in nav | 4, 7 |
| W13: Radio `.trigger("click")` unreliable | Use `.setChecked()` for Bootstrap-Vue radios | All test tasks |
| Notes: TriageStatusBadge reuse, triage/ directory, composable preference, event kebab-case, empty-state tests, a11y (aria-current, focus management) | Incorporated throughout | All |

---

## File Structure

### New files
| File | Responsibility |
|---|---|
| `app/javascript/components/triage/CommentTriageForm.vue` | Triage decision form — extracted from CommentTriageModal. Decision radios, response textarea, duplicate picker. Reusable in modal AND inline panel. |
| `app/javascript/components/triage/RuleContextPanel.vue` | Read-only rule content — title, severity, status, vuln discussion, check text, fix text. Collapsible sections with fisheye focus + chevron affordance. |
| `app/javascript/components/triage/TriageQueueNav.vue` | Compact queue navigation — counter ("12 of 142 pending"), prev/next buttons, optional dropdown for jump-to. Reuses `TriageStatusBadge`. |
| `app/javascript/components/triage/TriageSplitView.vue` | Split-pane orchestrator — owns `activeCommentId`, `dirtyDraft` map, optimistic lock check, delegates to RuleContextPanel + CommentTriageForm + TriageQueueNav. |
| `spec/javascript/components/triage/CommentTriageForm.spec.js` | Tests: decision radios, non-concur validation, response textarea, save emit, error-path (422, 403), admin actions hidden for non-admin. |
| `spec/javascript/components/triage/RuleContextPanel.spec.js` | Tests: section focusing (visible content, not CSS classes), collapse behavior via chevron click, (general) mode, long-content scroll, null ruleContent banner. |
| `spec/javascript/components/triage/TriageQueueNav.spec.js` | Tests: counter text, prev/next emit, dropdown rendering, a11y (aria-labels, keyboard nav), TriageStatusBadge integration. |
| `spec/javascript/components/triage/TriageSplitView.spec.js` | Tests: enter/exit split, lazy-fetch rule content, dirty-form guard, optimistic lock 409 handling, filter interaction, double-click guard. |

### Modified files
| File | What changes |
|---|---|
| `app/models/component.rb` | Add `include_rule_content` param to `paginated_comments`. When true: extend preload with `:disa_rule_descriptions, :checks`, serialize 6 rule-content fields. When false: skip (existing behavior). Add `updated_at` to row hash for optimistic locking. |
| `app/javascript/components/components/ComponentTriagePage.vue` | Add split-mode state, pass `currentUserId` to ComponentComments. |
| `app/javascript/components/components/ComponentComments.vue` | Add split-mode toggle. Delegate to `TriageSplitView` when active (v-if). Table stays in ComponentComments. |
| `app/javascript/components/components/CommentTriageModal.vue` | Extract form body into CommentTriageForm, keep modal as zero-logic wrapper (props pass through, events relay). |
| `app/javascript/constants/triageVocabulary.js` | Add `TERMINAL_BY_RULE` set (reconciled with Ruby `TERMINAL_AUTO_ADJUDICATE_STATUSES`). |

---

### Task 1: Conditional preload in `paginated_comments`

**Files:**
- Modify: `app/models/component.rb`
- Test: `spec/models/components_spec.rb` (add to existing)

Add an `include_rule_content:` keyword arg. When true, preload `:disa_rule_descriptions, :checks` and serialize 6 rule-content fields + `updated_at` into the row hash. When false (default), skip — table-only view stays lean.

- [ ] **Step 1: Write the failing test**

Add to `spec/models/components_spec.rb` in the `paginated_comments` describe block:

```ruby
context 'with include_rule_content: true (triage context panel)' do
  it 'includes rule title, severity, status, fixtext, vuln_discussion, and check_content' do
    result = component.paginated_comments(include_rule_content: true)
    row = result[:rows].first
    expect(row).to have_key(:rule_title)
    expect(row).to have_key(:rule_severity)
    expect(row).to have_key(:rule_status)
    expect(row).to have_key(:rule_fixtext)
    expect(row).to have_key(:rule_vuln_discussion)
    expect(row).to have_key(:rule_check_content)
    expect(row).to have_key(:updated_at)
  end

  it 'returns nil for rule content fields on component-scoped comments' do
    component_review = Review.create!(
      user: review_user, commentable: component, action: 'comment',
      comment: 'component-scoped', section: nil
    )
    result = component.paginated_comments(include_rule_content: true)
    comp_row = result[:rows].find { |r| r[:id] == component_review.id }
    expect(comp_row[:rule_title]).to be_nil
  end
end

context 'without include_rule_content (default — table mode)' do
  it 'does NOT include rule content fields' do
    result = component.paginated_comments
    row = result[:rows].first
    expect(row).not_to have_key(:rule_title)
    expect(row).not_to have_key(:rule_check_content)
  end

  it 'still includes updated_at for optimistic locking' do
    result = component.paginated_comments
    row = result[:rows].first
    expect(row).to have_key(:updated_at)
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/models/components_spec.rb -e 'rule content fields'`
Expected: FAIL — no `include_rule_content` param accepted

- [ ] **Step 3: Implement conditional preload**

In `app/models/component.rb`, update `paginated_comments` signature and body:

```ruby
def paginated_comments(page: 1, per_page: 25, include_rule_content: false, **filters)
  # ... existing filter/pagination logic ...

  # Conditional preload: table mode skips rule text associations
  base_preloads = [:user, :triage_set_by, :adjudicated_by, :commentable]
  if include_rule_content
    base_preloads[-1] = { commentable: [:disa_rule_descriptions, :checks] }
  end
  scope = scope.preload(*base_preloads)

  # ... existing query + row hash assembly ...

  # Always include updated_at for optimistic locking
  row[:updated_at] = r.updated_at.iso8601

  # Conditionally include rule content
  if include_rule_content
    component_scoped = r.commentable_type != 'Rule'
    row[:rule_title] = component_scoped ? nil : r.commentable&.title
    row[:rule_severity] = component_scoped ? nil : r.commentable&.rule_severity
    row[:rule_status] = component_scoped ? nil : r.commentable&.status
    row[:rule_fixtext] = component_scoped ? nil : r.commentable&.fixtext
    row[:rule_vuln_discussion] = component_scoped ? nil : r.commentable&.disa_rule_descriptions&.first&.vuln_discussion
    row[:rule_check_content] = component_scoped ? nil : r.commentable&.checks&.first&.content
  end
```

- [ ] **Step 4: Run tests, verify pass**

Run: `bundle exec rspec spec/models/components_spec.rb -e 'paginated_comments'`
Expected: All green

- [ ] **Step 5: Commit**

```bash
git add app/models/component.rb spec/models/components_spec.rb
git commit -m "feat: conditional rule content preload in paginated_comments

Adds include_rule_content: param (default false). Table mode skips
rule text associations entirely — no payload bloat. Split-pane mode
passes true to get title/severity/status/fixtext/vuln_discussion/
check_content. Always includes updated_at for optimistic locking.

Authored by: Aaron Lippold<lippold@gmail.com>"
```

---

### Task 2: Extract `CommentTriageForm.vue` + reconcile constants

**Files:**
- Modify: `app/javascript/constants/triageVocabulary.js`
- Create: `app/javascript/components/triage/CommentTriageForm.vue`
- Modify: `app/javascript/components/components/CommentTriageModal.vue`
- Test: `spec/javascript/components/triage/CommentTriageForm.spec.js`

Two sub-goals: (1) reconcile the `TERMINAL_BY_RULE` divergence between JS and Ruby before extraction, (2) extract the decision core (radios + response + duplicate picker + save) into a reusable form. Leave admin actions and section editing in the modal until the panel proves it needs them.

- [ ] **Step 1: Reconcile TERMINAL_BY_RULE**

Read `CommentTriageModal.vue` line ~340 (`TERMINAL_BY_RULE = new Set(...)`) and `app/models/review.rb:56` (`TERMINAL_AUTO_ADJUDICATE_STATUSES`). They disagree on `needs_clarification`. Determine the correct set, move to `triageVocabulary.js` as an exported const, and import in both the modal and the new form.

```javascript
// In triageVocabulary.js — add:
export const TERMINAL_AUTO_ADJUDICATE = new Set([
  'duplicate', 'informational', 'withdrawn'
]);
// needs_clarification is NOT terminal — it round-trips with the commenter
```

Update `CommentTriageModal.vue` to import from `triageVocabulary.js` instead of defining inline.

- [ ] **Step 2: Write the failing test for the extracted form**

Create `spec/javascript/components/triage/CommentTriageForm.spec.js`:

```javascript
import { mount, createLocalVue } from "@vue/test-utils";
import BootstrapVue from "bootstrap-vue";
import CommentTriageForm from "@/components/triage/CommentTriageForm.vue";

const localVue = createLocalVue();
localVue.use(BootstrapVue);

function baseProps(overrides = {}) {
  return {
    review: {
      id: 1, rule_id: 10, comment: "Test comment",
      section: "check_content", triage_status: "pending",
      created_at: "2026-05-01T00:00:00Z",
      commenter_display_name: "Tester",
    },
    componentId: 5,
    effectivePermissions: "admin",
    commentsClosed: false,
    ...overrides,
  };
}

describe("CommentTriageForm", () => {
  it("renders decision radio buttons", () => {
    const w = mount(CommentTriageForm, { localVue, propsData: baseProps() });
    expect(w.findAll('input[type="radio"]').length).toBeGreaterThanOrEqual(4);
  });

  it("renders response textarea", () => {
    const w = mount(CommentTriageForm, { localVue, propsData: baseProps() });
    expect(w.find("textarea").exists()).toBe(true);
  });

  it("emits save event with triage decision on Save click", async () => {
    const w = mount(CommentTriageForm, { localVue, propsData: baseProps() });
    await w.find('input[value="concur"]').setChecked();
    await w.find('[data-testid="save-decision"]').trigger("click");
    expect(w.emitted("save")).toBeTruthy();
  });

  it("blocks Save when non-concur is selected with empty response", async () => {
    const w = mount(CommentTriageForm, { localVue, propsData: baseProps() });
    await w.find('input[value="non_concur"]').setChecked();
    await w.find('[data-testid="save-decision"]').trigger("click");
    expect(w.emitted("save")).toBeFalsy();
    expect(w.text()).toContain("response");
  });

  it("emits save-and-next event", async () => {
    const w = mount(CommentTriageForm, { localVue, propsData: baseProps() });
    await w.find('input[value="concur"]').setChecked();
    await w.find('[data-testid="save-and-next"]').trigger("click");
    expect(w.emitted("save-and-next")).toBeTruthy();
  });

  it("emits cancel event", async () => {
    const w = mount(CommentTriageForm, { localVue, propsData: baseProps() });
    await w.find('[data-testid="cancel"]').trigger("click");
    expect(w.emitted("cancel")).toBeTruthy();
  });

  it("emits dirty event when user changes a field", async () => {
    const w = mount(CommentTriageForm, { localVue, propsData: baseProps() });
    await w.find('input[value="concur"]').setChecked();
    expect(w.emitted("dirty")).toBeTruthy();
  });
});
```

- [ ] **Step 3: Run test to verify it fails**

Run: `yarn vitest run spec/javascript/components/triage/CommentTriageForm.spec.js`
Expected: FAIL — module not found

- [ ] **Step 4: Extract the form component**

Create `app/javascript/components/triage/CommentTriageForm.vue` by extracting from `CommentTriageModal.vue`:
- Decision `b-form-group` with radio buttons (concur, concur_with_comment, non_concur, duplicate, informational, needs_clarification)
- `CanonicalCommentPicker` conditional (for duplicate linking)
- Response textarea `b-form-group` with validation state (non-concur requires response)
- Save / Save & next / Cancel buttons
- Import `TERMINAL_AUTO_ADJUDICATE` from `triageVocabulary.js`

Props: `review`, `componentId`, `effectivePermissions`, `commentsClosed`, `loading` (boolean, for disabling buttons during save).
Emits: `save(decision)`, `save-and-next(decision)`, `cancel`, `dirty(boolean)`.

**Do NOT extract:** admin actions disclosure, section editing sub-form. Those stay in the modal until the panel proves it needs them.

- [ ] **Step 5: Update CommentTriageModal to thin wrapper**

Replace the inline form body in `CommentTriageModal.vue` with:

```vue
<CommentTriageForm
  :review="review"
  :component-id="pickerComponentId"
  :effective-permissions="effectivePermissions"
  :comments-closed="commentsClosed"
  :loading="saving"
  @save="onSave"
  @save-and-next="onSaveAndClose"
  @cancel="$emit('hidden')"
  @dirty="isDirty = $event"
/>
```

The modal remains the owner of the admin actions and section editor — it renders them below or beside the form.

- [ ] **Step 6: Write modal regression test**

Add to existing `spec/javascript/components/components/CommentTriageModal.spec.js`:

```javascript
describe("post-extraction regression", () => {
  it("still mounts and renders the form", () => {
    const w = mount(CommentTriageModal, { localVue, propsData: modalBaseProps() });
    expect(w.findComponent({ name: "CommentTriageForm" }).exists()).toBe(true);
  });

  it("still emits triaged event on form save", async () => {
    const w = mount(CommentTriageModal, { localVue, propsData: modalBaseProps() });
    const form = w.findComponent({ name: "CommentTriageForm" });
    form.vm.$emit("save", { triage_status: "concur", response_comment: "" });
    await w.vm.$nextTick();
    // Assert the modal's onSave handler fired
    expect(w.emitted("triaged") || w.emitted("hidden")).toBeTruthy();
  });
});
```

- [ ] **Step 7: Run all specs**

Run: `yarn vitest run spec/javascript/components/triage/CommentTriageForm.spec.js spec/javascript/components/components/CommentTriageModal.spec.js`
Expected: All pass

- [ ] **Step 8: Commit**

```bash
git add app/javascript/components/triage/CommentTriageForm.vue \
       app/javascript/components/components/CommentTriageModal.vue \
       app/javascript/constants/triageVocabulary.js \
       spec/javascript/components/triage/CommentTriageForm.spec.js \
       spec/javascript/components/components/CommentTriageModal.spec.js
git commit -m "refactor: extract CommentTriageForm + reconcile TERMINAL constants

Moves TERMINAL_BY_RULE to triageVocabulary.js as TERMINAL_AUTO_ADJUDICATE,
reconciling the JS/Ruby divergence (needs_clarification is NOT terminal).
Extracts decision core into CommentTriageForm.vue. Modal becomes a thin
wrapper. Admin actions and section editor stay in the modal.

Adds dirty event emission for the dirty-form guard in TriageSplitView.
Adds non-concur validation test (decline requires response text).
Adds modal post-extraction regression test.

Authored by: Aaron Lippold<lippold@gmail.com>"
```

---

### Task 3: Create `RuleContextPanel.vue` with fisheye section focus

**Files:**
- Create: `app/javascript/components/triage/RuleContextPanel.vue`
- Test: `spec/javascript/components/triage/RuleContextPanel.spec.js`

Read-only panel showing rule content with collapsible sections. Focused section auto-expands with accent border and chevron-down; others collapse to header + one-line preview with chevron-right (clear interactive affordance). Section labels imported from `SECTION_LABELS` in `triageVocabulary.js` — no new mapping. Long content gets `max-height: 400px` + scroll.

- [ ] **Step 1: Write the failing test**

Create `spec/javascript/components/triage/RuleContextPanel.spec.js`:

```javascript
import { mount, createLocalVue } from "@vue/test-utils";
import BootstrapVue from "bootstrap-vue";
import RuleContextPanel from "@/components/triage/RuleContextPanel.vue";

const localVue = createLocalVue();
localVue.use(BootstrapVue);

const ruleContent = {
  rule_displayed_name: "CNTR-01-000001",
  rule_title: "The container platform must limit privileges",
  rule_severity: "CAT II",
  rule_status: "Applicable - Configurable",
  rule_fixtext: "Configure the container platform to restrict...",
  rule_check_content: "Verify that the container runtime enforces...",
  rule_vuln_discussion: "Without proper privilege restriction...",
};

describe("RuleContextPanel", () => {
  it("renders the rule display name as a heading", () => {
    const w = mount(RuleContextPanel, {
      localVue, propsData: { ruleContent, focusedSection: null },
    });
    expect(w.text()).toContain("CNTR-01-000001");
  });

  it("expands the focused section (content visible)", () => {
    const w = mount(RuleContextPanel, {
      localVue, propsData: { ruleContent, focusedSection: "check_content" },
    });
    const checkSection = w.find('[data-section="check_content"]');
    expect(checkSection.find(".section-body").isVisible()).toBe(true);
    expect(checkSection.text()).toContain("Verify that the container");
  });

  it("collapses non-focused sections (content hidden, preview shown)", () => {
    const w = mount(RuleContextPanel, {
      localVue, propsData: { ruleContent, focusedSection: "check_content" },
    });
    const fixSection = w.find('[data-section="fixtext"]');
    expect(fixSection.find(".section-body").isVisible()).toBe(false);
    expect(fixSection.find(".section-preview").exists()).toBe(true);
  });

  it("shows chevron-right on collapsed sections (interactive affordance)", () => {
    const w = mount(RuleContextPanel, {
      localVue, propsData: { ruleContent, focusedSection: "check_content" },
    });
    const fixSection = w.find('[data-section="fixtext"]');
    expect(fixSection.find(".bi-chevron-right").exists()).toBe(true);
  });

  it("expands a collapsed section when its header is clicked", async () => {
    const w = mount(RuleContextPanel, {
      localVue, propsData: { ruleContent, focusedSection: "check_content" },
    });
    const fixHeader = w.find('[data-section="fixtext"] .section-header');
    await fixHeader.trigger("click");
    expect(w.find('[data-section="fixtext"] .section-body').isVisible()).toBe(true);
  });

  it("expands all sections when focusedSection is null (general comment)", () => {
    const w = mount(RuleContextPanel, {
      localVue, propsData: { ruleContent, focusedSection: null },
    });
    const sections = w.findAll("[data-section]");
    sections.wrappers.forEach((s) => {
      expect(s.find(".section-body").isVisible()).toBe(true);
    });
  });

  it("renders a banner for component-scoped comments (null ruleContent)", () => {
    const w = mount(RuleContextPanel, {
      localVue, propsData: { ruleContent: null, focusedSection: null },
    });
    expect(w.text()).toContain("Overall Component");
  });

  it("uses SECTION_LABELS from triageVocabulary for display labels", () => {
    const w = mount(RuleContextPanel, {
      localVue, propsData: { ruleContent, focusedSection: "check_content" },
    });
    expect(w.text()).toContain("Check");
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `yarn vitest run spec/javascript/components/triage/RuleContextPanel.spec.js`
Expected: FAIL — module not found

- [ ] **Step 3: Implement RuleContextPanel**

Create `app/javascript/components/triage/RuleContextPanel.vue`:

- Import `SECTION_LABELS` from `../../constants/triageVocabulary` — do NOT re-derive
- Props: `ruleContent` (Object, nullable), `focusedSection` (String, nullable)
- Sections rendered from a computed array derived from `SECTION_LABELS` + the ruleContent fields
- Each section: `<div data-section="key">` with `.section-header` (clickable, cursor: pointer) and `.section-body` (b-collapse with `:visible`)
- Focused section: `visible=true`, chevron-down icon, accent left border
- Non-focused sections: `visible=false`, chevron-right icon, one-line `.section-preview` (truncated)
- Manual toggle: click header → toggle `expandedSections` set (local data)
- When `focusedSection` is null: all sections expanded
- When `ruleContent` is null: "Overall Component" info banner
- Each `.section-body` gets `max-height: 400px; overflow-y: auto` for long content
- Opacity on collapsed headers: 0.85 minimum (not 0.6 — WCAG 1.4.3 compliance)
- Use Bootstrap Icons (`bi-chevron-right`, `bi-chevron-down`) already in the project

- [ ] **Step 4: Run test to verify it passes**

Run: `yarn vitest run spec/javascript/components/triage/RuleContextPanel.spec.js`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add app/javascript/components/triage/RuleContextPanel.vue \
       spec/javascript/components/triage/RuleContextPanel.spec.js
git commit -m "feat: RuleContextPanel with fisheye focus + chevron affordance

Imports SECTION_LABELS from triageVocabulary.js (single source of truth).
Focused section expanded with accent border; others collapsed with
chevron-right + cursor:pointer for clear interactive affordance. Long
content capped at 400px with scroll. WCAG-safe opacity (0.85 min).

Authored by: Aaron Lippold<lippold@gmail.com>"
```

---

### Task 4: Create `TriageQueueNav.vue` (counter + prev/next + dropdown)

**Files:**
- Create: `app/javascript/components/triage/TriageQueueNav.vue`
- Test: `spec/javascript/components/triage/TriageQueueNav.spec.js`

The original pill bar doesn't scale to 200 comments. Replaced with: a counter showing position and pending count ("12 of 142 pending"), prev/next buttons, and an optional dropdown for jump-to. Reuses existing `TriageStatusBadge.vue` for status rendering.

- [ ] **Step 1: Write the failing test**

Create `spec/javascript/components/triage/TriageQueueNav.spec.js`:

```javascript
import { mount, createLocalVue } from "@vue/test-utils";
import BootstrapVue from "bootstrap-vue";
import TriageQueueNav from "@/components/triage/TriageQueueNav.vue";

const localVue = createLocalVue();
localVue.use(BootstrapVue);

const comments = Array.from({ length: 50 }, (_, i) => ({
  id: 50 - i,
  section: i % 3 === 0 ? "check_content" : i % 3 === 1 ? "fixtext" : null,
  triage_status: i < 30 ? "pending" : "concur",
}));

describe("TriageQueueNav", () => {
  it("renders position counter '1 of 50'", () => {
    const w = mount(TriageQueueNav, {
      localVue, propsData: { comments, currentId: 50 },
    });
    expect(w.text()).toContain("1 of 50");
  });

  it("renders pending count '30 pending'", () => {
    const w = mount(TriageQueueNav, {
      localVue, propsData: { comments, currentId: 50 },
    });
    expect(w.text()).toContain("30 pending");
  });

  it("emits select with next comment ID on Next click", async () => {
    const w = mount(TriageQueueNav, {
      localVue, propsData: { comments, currentId: 50 },
    });
    await w.find('[data-testid="next-btn"]').trigger("click");
    expect(w.emitted("select")[0]).toEqual([49]);
  });

  it("emits select with previous comment ID on Prev click", async () => {
    const w = mount(TriageQueueNav, {
      localVue, propsData: { comments, currentId: 49 },
    });
    await w.find('[data-testid="prev-btn"]').trigger("click");
    expect(w.emitted("select")[0]).toEqual([50]);
  });

  it("disables Prev on the first comment", () => {
    const w = mount(TriageQueueNav, {
      localVue, propsData: { comments, currentId: 50 },
    });
    expect(w.find('[data-testid="prev-btn"]').attributes("disabled")).toBeTruthy();
  });

  it("disables Next on the last comment", () => {
    const w = mount(TriageQueueNav, {
      localVue, propsData: { comments, currentId: 1 },
    });
    expect(w.find('[data-testid="next-btn"]').attributes("disabled")).toBeTruthy();
  });

  it("has aria-labels on prev/next buttons", () => {
    const w = mount(TriageQueueNav, {
      localVue, propsData: { comments, currentId: 49 },
    });
    expect(w.find('[data-testid="prev-btn"]').attributes("aria-label")).toBe("Previous comment");
    expect(w.find('[data-testid="next-btn"]').attributes("aria-label")).toBe("Next comment");
  });

  it("renders a jump-to dropdown with comment list", async () => {
    const w = mount(TriageQueueNav, {
      localVue, propsData: { comments, currentId: 50 },
    });
    await w.find('[data-testid="jump-dropdown"]').trigger("click");
    expect(w.findAll(".jump-item").length).toBe(50);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `yarn vitest run spec/javascript/components/triage/TriageQueueNav.spec.js`
Expected: FAIL — module not found

- [ ] **Step 3: Implement TriageQueueNav**

Create `app/javascript/components/triage/TriageQueueNav.vue`:

- Props: `comments` (Array), `currentId` (Number)
- Emits: `select(commentId)`
- Computed: `currentIndex`, `pendingCount`, `positionText` ("12 of 142"), `hasPrev`, `hasNext`
- Template:
  - `<nav role="navigation" aria-label="Comment queue">`
  - Prev button: `<b-button ... :disabled="!hasPrev" aria-label="Previous comment" data-testid="prev-btn">`
  - Counter: `<span>{{ currentIndex + 1 }} of {{ comments.length }}</span> · <span>{{ pendingCount }} pending</span>`
  - Next button: same pattern
  - Jump dropdown: `<b-dropdown data-testid="jump-dropdown">` with scrollable list, each item shows `#id · section · <TriageStatusBadge :status="comment.triage_status" />`
- Import `TriageStatusBadge` from existing location (search for it in `app/javascript/components/`)

- [ ] **Step 4: Run test to verify it passes**

Run: `yarn vitest run spec/javascript/components/triage/TriageQueueNav.spec.js`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add app/javascript/components/triage/TriageQueueNav.vue \
       spec/javascript/components/triage/TriageQueueNav.spec.js
git commit -m "feat: TriageQueueNav with counter + prev/next + dropdown

Replaces the original pill bar (which didn't scale to 200 comments)
with a compact nav: position counter, pending count, prev/next buttons
with aria-labels, and a scrollable jump-to dropdown. Reuses existing
TriageStatusBadge for status rendering. Accessible via keyboard.

Authored by: Aaron Lippold<lippold@gmail.com>"
```

---

### Task 5: Wire `TriageSplitView.vue` + integration

**Files:**
- Create: `app/javascript/components/triage/TriageSplitView.vue`
- Modify: `app/javascript/components/components/ComponentComments.vue`
- Modify: `app/javascript/components/components/ComponentTriagePage.vue`
- Test: `spec/javascript/components/triage/TriageSplitView.spec.js`
- Test: `spec/javascript/components/components/ComponentComments.spec.js` (extend)

This is the integration task. `TriageSplitView` is a new component that owns all split-mode state: `activeCommentId`, `dirtyDraft` map, optimistic lock check, rule-content lazy-fetch. `ComponentComments` gets a simple `splitMode` boolean and delegates to `TriageSplitView` via `v-if`.

Key fixes incorporated:
- **B2**: `activeCommentId` as data, object derived via `computed`
- **B4**: Optimistic lock — send `updated_at` with save, handle 409 Conflict
- **W1**: Dirty-form guard — `dirtyDraft` map, confirm dialog before switching
- **W2**: Split-mode state lives in TriageSplitView, not in ComponentComments
- **W4**: `col-lg-5`/`col-lg-7` (not md)
- **W7**: If filter change removes activeComment from results, exit split mode
- **W8**: Save button disabled during pending request

- [ ] **Step 1: Write the failing tests**

Create `spec/javascript/components/triage/TriageSplitView.spec.js`:

```javascript
import { mount, createLocalVue } from "@vue/test-utils";
import BootstrapVue from "bootstrap-vue";
import TriageSplitView from "@/components/triage/TriageSplitView.vue";
import axios from "axios";
vi.mock("axios");

const localVue = createLocalVue();
localVue.use(BootstrapVue);

const rows = [
  { id: 3, section: "check_content", triage_status: "pending", updated_at: "2026-05-16T10:00:00Z", rule_id: 10 },
  { id: 2, section: "fixtext", triage_status: "pending", updated_at: "2026-05-16T09:00:00Z", rule_id: 10 },
  { id: 1, section: null, triage_status: "concur", updated_at: "2026-05-16T08:00:00Z", rule_id: 11 },
];

describe("TriageSplitView", () => {
  it("derives activeComment from activeCommentId via computed", () => {
    const w = mount(TriageSplitView, {
      localVue, propsData: { rows, initialCommentId: 3, componentId: 5, effectivePermissions: "admin", commentsClosed: false },
    });
    expect(w.vm.activeComment.id).toBe(3);
  });

  it("lazy-fetches rule content when entering split mode", async () => {
    axios.get.mockResolvedValue({ data: { rows: [{ ...rows[0], rule_title: "Test Rule" }], pagination: {} } });
    const w = mount(TriageSplitView, {
      localVue, propsData: { rows, initialCommentId: 3, componentId: 5, effectivePermissions: "admin", commentsClosed: false },
    });
    await flushPromises();
    expect(axios.get).toHaveBeenCalledWith(expect.stringContaining("include_rule_content=true"));
  });

  it("prompts before switching when form is dirty", async () => {
    window.confirm = vi.fn().mockReturnValue(false);
    const w = mount(TriageSplitView, {
      localVue, propsData: { rows, initialCommentId: 3, componentId: 5, effectivePermissions: "admin", commentsClosed: false },
    });
    w.vm.isDirty = true;
    w.vm.onQueueSelect(2);
    expect(window.confirm).toHaveBeenCalled();
    expect(w.vm.activeCommentId).toBe(3); // didn't switch
  });

  it("handles 409 Conflict on save (optimistic lock)", async () => {
    axios.patch.mockRejectedValue({ response: { status: 409, data: { error: "conflict" } } });
    const w = mount(TriageSplitView, {
      localVue, propsData: { rows, initialCommentId: 3, componentId: 5, effectivePermissions: "admin", commentsClosed: false },
    });
    await w.vm.onTriageSave({ triage_status: "concur", response_comment: "" });
    expect(w.text()).toContain("modified"); // shows conflict alert
  });

  it("handles 422 on save (validation error)", async () => {
    axios.patch.mockRejectedValue({ response: { status: 422, data: { error: "Non-concur requires a response" } } });
    const w = mount(TriageSplitView, {
      localVue, propsData: { rows, initialCommentId: 3, componentId: 5, effectivePermissions: "admin", commentsClosed: false },
    });
    await w.vm.onTriageSave({ triage_status: "non_concur", response_comment: "" });
    expect(w.emitted("error")).toBeTruthy();
  });

  it("disables save button during pending request", async () => {
    axios.patch.mockImplementation(() => new Promise(() => {})); // never resolves
    const w = mount(TriageSplitView, {
      localVue, propsData: { rows, initialCommentId: 3, componentId: 5, effectivePermissions: "admin", commentsClosed: false },
    });
    w.vm.onTriageSave({ triage_status: "concur" });
    await w.vm.$nextTick();
    expect(w.vm.saving).toBe(true);
  });

  it("emits exit when activeComment is removed from rows (filter change)", async () => {
    const w = mount(TriageSplitView, {
      localVue, propsData: { rows, initialCommentId: 3, componentId: 5, effectivePermissions: "admin", commentsClosed: false },
    });
    await w.setProps({ rows: rows.filter(r => r.id !== 3) });
    expect(w.emitted("exit")).toBeTruthy();
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `yarn vitest run spec/javascript/components/triage/TriageSplitView.spec.js`
Expected: FAIL — module not found

- [ ] **Step 3: Implement TriageSplitView**

Create `app/javascript/components/triage/TriageSplitView.vue`:

```vue
<template>
  <div>
    <TriageQueueNav
      :comments="rows"
      :current-id="activeCommentId"
      @select="onQueueSelect"
    />
    <b-row class="mt-3">
      <b-col lg="5" class="rule-context-col">
        <RuleContextPanel
          :rule-content="ruleContentForActive"
          :focused-section="activeComment ? activeComment.section : null"
        />
      </b-col>
      <b-col lg="7" class="triage-form-col">
        <CommentTriageForm
          v-if="activeComment"
          :review="activeComment"
          :component-id="componentId"
          :effective-permissions="effectivePermissions"
          :comments-closed="commentsClosed"
          :loading="saving"
          @save="onTriageSave"
          @save-and-next="onTriageSaveAndNext"
          @cancel="onCancel"
          @dirty="isDirty = $event"
        />
      </b-col>
    </b-row>
  </div>
</template>
```

Data: `activeCommentId`, `ruleContentCache` (Map by comment ID), `isDirty`, `saving`, `conflictAlert`.
Computed: `activeComment() { return this.rows.find(r => r.id === this.activeCommentId) || null }`.
Watch: `activeComment` — if null (filtered out), emit `exit`. On change, fetch rule content if not cached.
Methods:
- `onQueueSelect(id)` — if dirty, `window.confirm("Unsaved changes. Switch anyway?")`. If confirmed or not dirty, switch.
- `onTriageSave(decision)` — PATCH with `updated_at` for optimistic lock. On 409: show inline conflict alert. On 422: surface error. On success: emit `triaged`.
- `onTriageSaveAndNext(decision)` — save then advance (same logic as Task 7).
- `fetchRuleContent(commentId)` — GET `paginated_comments?include_rule_content=true&comment_id=X` or re-fetch current page with the flag. Cache result.

- [ ] **Step 4: Wire into ComponentComments**

In `ComponentComments.vue`, add:

```javascript
import TriageSplitView from "../triage/TriageSplitView.vue";
```

Data: `splitMode: false`, `splitCommentId: null`.

Template: wrap existing `b-table` in `<template v-if="!splitMode">`. Add:

```vue
<TriageSplitView
  v-else
  :rows="rows"
  :initial-comment-id="splitCommentId"
  :component-id="componentId"
  :effective-permissions="effectivePermissions"
  :comments-closed="commentsClosed"
  @exit="exitSplitMode"
  @triaged="onTriaged"
/>
```

Wire Triage button click to `enterSplitMode(row.id)`.

- [ ] **Step 5: Run all tests**

Run: `yarn vitest run spec/javascript/components/triage/ spec/javascript/components/components/ComponentComments.spec.js`
Expected: All pass

- [ ] **Step 6: Commit**

```bash
git add app/javascript/components/triage/TriageSplitView.vue \
       app/javascript/components/components/ComponentComments.vue \
       app/javascript/components/components/ComponentTriagePage.vue \
       spec/javascript/components/triage/TriageSplitView.spec.js \
       spec/javascript/components/components/ComponentComments.spec.js
git commit -m "feat: TriageSplitView with optimistic lock + dirty guard

Extracts split-mode state into TriageSplitView so ComponentComments
stays lean. activeCommentId stored as data, object derived via computed
(Vue 2 reactivity safe). Lazy-fetches rule content via conditional
include_rule_content param. Dirty-form guard prompts before switching.
Optimistic lock sends updated_at with save, handles 409 Conflict.
Save button disabled during pending request. Exits split mode if
active comment is filtered out.

Authored by: Aaron Lippold<lippold@gmail.com>"
```

---

## Phase 2: Unified Triage Interface (post-review refactor)

> **Context:** After implementing Tasks 1-5 and the initial UX polish, three review agents (Architecture/DRY, Test Coverage, Comment System Field Gaps) identified normalization opportunities and bugs. The user's live testing surfaced additional UX feedback. Tasks 6-8 are rewritten to incorporate all findings in a single coherent pass.

### Key architectural decisions (Phase 2)

1. **One field registry:** `ruleFieldConfig.js` already has `STATUS_FIELD_CONFIG` (field visibility per status) and `LOCKABLE_SECTIONS` (section → field mapping). Extend it with per-field labels so it becomes the canonical registry. Delete the duplicate `FIELD_LABELS` from RuleContextPanel.

2. **Section-group fisheye focus:** The comment system uses 10 section groups (not individual fields). The context panel's fisheye should match: when a comment targets `disa_metadata`, expand ALL DISA fields in the panel. `LOCKABLE_SECTIONS` already defines these groups — reuse it.

3. **Unified interface — no modal:** The split-pane replaces the modal for triage. Admin actions (force-withdraw, restore, move-to-rule, hard-delete) move into the split-pane as a disclosure below the triage form. `CommentTriageModal` is removed from `ComponentComments` (no other consumer). The file stays on disk for potential rule-editor use.

4. **`rule_content` nested hash:** Backend serializes all fields into `row[:rule_content]` (not flat `rule_*` keys). Frontend uses `STATUS_FIELD_CONFIG` to decide what to display per status.

5. **`rule_displayed_name` reads from parent row:** The heading in the context panel reads `activeComment.rule_displayed_name` (on the row), NOT from `rule_content` (which doesn't have it). Review agent caught this bug.

---

### Task 6: Normalize field registry + fix heading bug

**Files:**
- Modify: `app/javascript/composables/ruleFieldConfig.js` (add FIELD_LABELS export)
- Modify: `app/javascript/components/triage/RuleContextPanel.vue` (delete local FIELD_LABELS, import from registry, fix heading to read from prop)
- Modify: `app/javascript/components/triage/TriageSplitView.vue` (pass rule_displayed_name as separate prop)
- Test: `spec/javascript/components/triage/RuleContextPanel.spec.js` (update fixtures)
- Test: `spec/javascript/components/triage/TriageSplitView.spec.js` (heading from row, not rule_content)
- Test: `spec/models/components_spec.rb` (assert all 26 fields present)

Steps:
- [ ] Add `FIELD_LABELS` export to `ruleFieldConfig.js` — canonical field-key-to-label mapping
- [ ] Resolve `content` → `check_content` alias in the registry
- [ ] Delete `FIELD_LABELS` dict from `RuleContextPanel.vue` — import from registry
- [ ] Fix heading: RuleContextPanel accepts `ruleDisplayedName` prop (not from ruleContent)
- [ ] TriageSplitView passes `activeComment.rule_displayed_name` as heading prop
- [ ] Backend test asserts all 26 fields present in `serialize_rule_content`
- [ ] Tighten 5 weak `toBeTruthy()` assertions to specific value checks
- [ ] Add unknown-ruleStatus fallback test
- [ ] Verify: `yarn vitest run spec/javascript/components/triage/` + `bundle exec rspec spec/models/components_spec.rb -e rule_content`

---

### Task 7: Admin actions in split-pane + retire modal

**Files:**
- Modify: `app/javascript/components/triage/TriageSplitView.vue` (add admin disclosure)
- Modify: `app/javascript/components/components/ComponentComments.vue` (remove modal import/template)
- Test: `spec/javascript/components/triage/TriageSplitView.spec.js` (admin action tests)
- Test: `spec/javascript/components/components/ComponentComments.spec.js` (no modal reference)

Steps:
- [ ] Move admin actions disclosure block from CommentTriageModal into TriageSplitView (below triage form, gated by canAdminAct)
- [ ] Import RulePicker + admin state/methods into TriageSplitView
- [ ] Remove `CommentTriageModal` import/template/component-registration from ComponentComments
- [ ] Remove orphaned `selectedRow` data and `onTriageModalReplyRequested` method
- [ ] Add admin action tests to TriageSplitView spec (force-withdraw, restore, hard-delete, move-to-rule)
- [ ] Verify: `yarn vitest run spec/javascript/components/triage/ spec/javascript/components/components/`

---

### Task 8: Playwright verification + test hardening + commit

**Files:**
- Test: full backend + frontend suites
- Test: Playwright end-to-end
- Run: RuboCop + ESLint + Brakeman

Steps:
- [ ] `bundle exec rake spec:parallel` — 0 failures
- [ ] `yarn vitest run` — 0 failures
- [ ] `bundle exec rubocop` — 0 offenses
- [ ] `yarn lint` — 0 warnings
- [ ] `bundle exec brakeman -q` — 0 warnings
- [ ] Playwright: login → triage page → click Triage → verify split-pane layout
- [ ] Playwright: verify rule context panel shows status-driven fields
- [ ] Playwright: verify fisheye focus on commented section
- [ ] Playwright: verify admin actions disclosure visible for admin
- [ ] Playwright: verify "Back to Triage Table" returns to table
- [ ] Playwright: verify "Back to Component Editor" visible from table
- [ ] Playwright: Save & next advances, Cancel exits
- [ ] Commit all remaining changes as one logical unit

- [ ] **Step 6: Confirm CommentTriageModal still works from rule editor**

Navigate to a rule's review section → open triage modal from there → verify it still renders and submits correctly. This confirms the extraction didn't break the backward-compat path.

- [ ] **Step 7: Final commit (if any lint fixes)**

```bash
git add -p
git commit -m "chore: integration test + a11y + lint fixes for triage panel

Authored by: Aaron Lippold<lippold@gmail.com>"
```

---

## Estimated effort

| Task | sp | Claude-pace |
|---|---|---|
| 1. Conditional preload in paginated_comments | 2 | ~10 min |
| 2. Extract CommentTriageForm + reconcile constants | 3 | ~25 min |
| 3. RuleContextPanel + fisheye + chevron | 3 | ~20 min |
| 4. TriageQueueNav (counter + nav + dropdown) | 3 | ~20 min |
| 5. TriageSplitView + integration (biggest task) | 8 | ~45 min |
| 6. Fisheye + split-pane CSS (WCAG-safe) | 2 | ~10 min |
| 7. Prev/Next + Save & next + error paths | 3 | ~20 min |
| 8. Integration test + a11y + cleanup | 2 | ~15 min |
| **Total** | **~26** | **~165 min** |

Note: Task 5 grew from sp:5 to sp:8 because it now includes optimistic locking, dirty-form guard, filter-interaction handling, and error-path tests. The overall epic grew from sp:22 / ~135 min to sp:26 / ~165 min — a ~22% increase for substantially better quality and safety.
