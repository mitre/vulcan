# Task 28: Migrate filter dropdowns to FilterDropdown — STIG/SRG + visible-page sweep

**Depends on:** none (FilterDropdown.vue is already shipped from earlier in PR #717)
**Estimate:** 30 min Claude-pace
**File touches:**
- `app/javascript/components/stigs/StigRuleList.vue` (1 dropdown)
- `app/javascript/components/project/RevisionHistory.vue` (1 dropdown)
- `app/javascript/components/project/DiffViewer.vue` (3 dropdowns: baseComponent, diffComponent, diffTheme)
- `app/javascript/components/benchmarks/RuleList.vue` (1 dropdown)
- Spec files for each component (extend; create if absent)

## Why this task exists

PR #717 introduced `FilterDropdown.vue` as the project-standard
viewport-aware filter dropdown (commit `4f1c571`) to replace
`<b-form-select>` filter chrome that clips at viewport edges. Three
consumers were migrated during the comment-workflow build:
`ComponentComments`, `RuleReviews`, `UserComments`.

Visual inconsistency in the rest of the app — STIG/SRG list pages,
revision history, diff viewer, benchmarks rule list — looks
unprofessional during a public comment window. Federal stakeholders
seeing two different dropdown styles on adjacent pages is a worse
first-impression than a single missing feature. Aaron flagged this
2026-04-30 as F1-now-in-scope.

## Verified facts

- `FilterDropdown.vue` API: `:value`, `:options` (array of
  `{value, text}`), `aria-label`, optional `:variant`, `:size`,
  `:placeholder`. Emits `input` for v-model. Uses `<b-dropdown>` +
  `<b-dropdown-item-button>` with `boundary="viewport"` so the menu
  stays inside the visible window.
- 6 filter-dropdown migration targets confirmed via grep:
  `app/javascript/components/{stigs/StigRuleList.vue:57,
  project/RevisionHistory.vue:7, project/DiffViewer.vue:{43,68,95},
  benchmarks/RuleList.vue:53}`.
- **Out of scope** (these stay as `<b-form-select>`):
  - Form inputs that submit values: `rules/forms/RuleForm.vue` (status,
    severity), `rules/forms/AdditionalAnswerForm.vue`,
    `rules/InspecControlEditor.vue` (language picker — semantic
    correctness)
  - Modal-internal dropdowns: `projects/RestoreProjectModal.vue`,
    `projects/NewProjectModal.vue`, `components/AddQuestionsModal.vue`,
    `components/MembersModal.vue` — modals constrain dropdown placement;
    no viewport-edge clipping risk
- Existing migration pattern (commits `4f1c571`, `e416e61`):
  ```vue
  <!-- before -->
  <b-form-select v-model="value" :options="opts" aria-label="..." />
  <!-- after -->
  <FilterDropdown v-model="value" :options="opts" aria-label="..." />
  ```
  Plus import + components registration:
  ```javascript
  import FilterDropdown from '../shared/FilterDropdown.vue';
  components: { FilterDropdown },
  ```

## Design decisions

- **Filter dropdowns only** — form inputs and modal dropdowns stay as
  `<b-form-select>`. The viewport-edge clipping problem is specific to
  page-level filter chrome, not form inputs or modal-constrained
  selectors.
- **Drop-in migration** — keep `:options` shape identical (FilterDropdown
  accepts the same `[{value, text}]` array). No data shape changes.
- **Preserve existing styling hooks** — class lists carry over; the
  parent layout's spacing should remain unchanged.
- **No backend changes** — pure frontend swap.
- **One commit per consumer** — easier to revert any single migration
  if a layout regression appears in browser testing. (Optional: bundle
  if all 4 files migrate cleanly with no surprises.)

## Step 1: StigRuleList.vue

**Failing spec** (extend or create
`spec/javascript/components/stigs/StigRuleList.spec.js`):

```javascript
it("uses FilterDropdown for the rule-field filter", () => {
  const w = mount(StigRuleList, {
    localVue,
    propsData: { /* ... existing required props ... */ },
  });
  expect(w.find("select").exists()).toBe(false);
  expect(w.findComponent({ name: "FilterDropdown" }).exists()).toBe(true);
});
```

**Implementation:**

```vue
<!-- StigRuleList.vue line 57 -->
<FilterDropdown
  v-model="field"
  :options="ruleFields"
  aria-label="Filter by rule field"
/>
```

Plus import + components registration. Run vitest + visual check.

## Step 2: RevisionHistory.vue

Same pattern. The dropdown selects which component's revision history
to show — clearly a filter.

```vue
<FilterDropdown
  id="componentName"
  v-model="componentName"
  :options="componentOptions"
  aria-label="Select component for revision history"
/>
```

(Verify `componentOptions` is in the `[{value, text}]` shape; if it
uses raw values, normalize.)

## Step 3: DiffViewer.vue (3 dropdowns)

Three migrations:

1. `baseComponent` (line 43) — base side of diff
2. `diffComponent` (line 68) — compare side of diff
3. `diffTheme` (line 95) — Monaco diff theme

DiffViewer uses inline `<option>` children rather than `:options`. The
new FilterDropdown takes `:options` only; convert the inline options
to a computed array.

For example:
```vue
<!-- before -->
<b-form-select v-model="diffTheme" class="form-select-sm">
  <option value="vs">Visual Studio Light</option>
  <option value="vs-dark">Visual Studio Dark</option>
  <option value="hc-black">High Contrast Dark</option>
</b-form-select>

<!-- after -->
<FilterDropdown v-model="diffTheme" :options="themeOptions" aria-label="Diff theme" />

<!-- in script -->
computed: {
  themeOptions() {
    return [
      { value: 'vs', text: 'Visual Studio Light' },
      { value: 'vs-dark', text: 'Visual Studio Dark' },
      { value: 'hc-black', text: 'High Contrast Dark' },
    ];
  },
}
```

Same conversion for `baseComponent` and `diffComponent` (currently
`v-for` over component objects with inline `<option>` slot).

## Step 4: benchmarks/RuleList.vue

```vue
<FilterDropdown
  v-model="field"
  :options="fieldOptions"
  aria-label="Filter by field"
  size="sm"
/>
```

## Step 5: Browser visual check (each migrated page)

Run `yarn build`, then for each page exercise the dropdown:

1. Open the page in a desktop browser at 1440x900.
2. Open the FilterDropdown menu — confirm it doesn't clip off-screen
   when positioned near the viewport edge.
3. Resize to 768x1024 (tablet) and 375x812 (mobile) — confirm menu
   stays inside the visible window.
4. Confirm the visual treatment matches the existing FilterDropdown
   consumers (`ComponentComments`, `RuleReviews`, `UserComments`) —
   same outline button, same chevron, same active-row highlight.

## Step 6: Vocabulary + lint + commit

```bash
yarn lint app/javascript/components/{stigs,project,benchmarks}/*.vue
pnpm vitest run spec/javascript/components/{stigs,project,benchmarks}/
```

Single commit covering all 4 files, message:

```
Refactor: migrate STIG/SRG/diff/history filter dropdowns to FilterDropdown

Visual consistency sweep across pages visible during the public
comment window. PR #717 introduced FilterDropdown.vue (commit
4f1c571) to replace <b-form-select> filter chrome that clips at
viewport edges. The comments-workflow consumers were migrated then;
this completes the sweep across remaining filter dropdowns:

  - stigs/StigRuleList.vue (rule-field filter)
  - project/RevisionHistory.vue (component selector)
  - project/DiffViewer.vue (base, compare, theme)
  - benchmarks/RuleList.vue (field filter)

Form-input dropdowns (RuleForm status/severity, AdditionalAnswerForm)
intentionally stay as <b-form-select> — they're real form inputs, not
filter chrome, and don't have viewport-edge clipping issues.

Modal-internal dropdowns also stay — modal containers constrain
placement.

Authored by: Aaron Lippold<lippold@gmail.com>
```

Then DONE rename per the standard pattern.

## Acceptance criteria

- [ ] `StigRuleList.vue` rule-field filter uses FilterDropdown
- [ ] `RevisionHistory.vue` component selector uses FilterDropdown
- [ ] `DiffViewer.vue` baseComponent, diffComponent, diffTheme all use FilterDropdown
- [ ] `benchmarks/RuleList.vue` field filter uses FilterDropdown
- [ ] Form-input dropdowns (RuleForm, AdditionalAnswerForm, InspecControlEditor) remain as `<b-form-select>` (regression-only assertion)
- [ ] Modal-internal dropdowns remain as `<b-form-select>` (regression-only assertion)
- [ ] Browser test at 3 viewports (1440, 768, 375) confirms no clipping on any migrated page
- [ ] No regression on existing specs for the migrated components
- [ ] `yarn lint` clean
