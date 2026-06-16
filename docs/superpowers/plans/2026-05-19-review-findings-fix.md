# Expert Review Findings — Fix Plan

**Epic:** vulcan-v3.x-dyl — Fix all expert review findings — PR readiness
**Branch:** feat/comment-triage-context-panel (27 commits ahead of master)
**Context:** 6-agent expert review (DRY, Security, Rails, Vue, Testing, Docs) found 25 issues.

---

## Completed (Phase 1 — committed 7469eef)

- [x] **dyl.1** C1: Prop mutation — emit @reaction-updated instead of $set on computed
- [x] **dyl.1** C4: Redundant conditional in component.rb:723 simplified
- [x] **dyl.3** C3: dev:reset uses destroy_all (not delete_all)
- [x] **dyl.3** S1: Rake reenable before invoke in dev:prime + dev:reset
- [x] **dyl.3** S5: Docs corrected — find_or_seed_review uses Review.create! not FactoryBot
- [x] **dyl.3** dev:reset status message shows actual count
- [x] **dyl.4** C5: Seed pipeline spec excluded from parallel_rspec via :seed_pipeline tag
- [x] **dyl.5** S2: Factory before(:create) replaces after(:build) for membership auto-creation
- [x] **dyl.6** S3: find_or_seed_review scoped to rule (not global comment text match)
- [x] **dyl.6** S4: DEMO_ROLE_USERS, COMPONENT_POC_PATTERNS, GENERIC_POC moved into SeedHelpers module

---

## Remaining (5 cards, ~70 min Claude-pace)

### Phase 2: dyl.2 — Extract AdminActionsPanel (sp:5, ~35 min)

**What:** ~190 lines of admin action logic duplicated between CommentTriageModal.vue and TriageSplitView.vue. Extract into shared AdminActionsPanel.vue component.

**Duplicated elements:**
- Data: `adminAction`, `adminAuditComment`, `adminConfirmationId`, `adminTargetRuleId`
- Computed: `canAdminAct`, `canRestore`, `canSubmitAdminAction`, `adminConfirmVariant`, `adminConfirmLabel`, `adminActionPrompt`
- Methods: `cancelAdminAction`, `submitAdminAction`, `onTargetRuleSelected`
- Template: admin action button group, confirmation textarea, hard-delete safeguard, RulePicker

**Also covers S7:** Triage save logic duplicated between TriageSplitView.doSave and CommentTriageModal.doTriage. Extract shared triage API call pattern.

**Files:**
- Create: `app/javascript/components/triage/AdminActionsPanel.vue`
- Modify: `app/javascript/components/triage/TriageSplitView.vue`
- Modify: `app/javascript/components/components/CommentTriageModal.vue`
- Test: `spec/javascript/components/triage/TriageSplitView.spec.js`, `spec/javascript/components/components/CommentTriageModal.spec.js`

**TDD approach:**
1. Write test: `expect(w.findComponent({ name: 'AdminActionsPanel' }).exists()).toBe(true)`
2. Create AdminActionsPanel with the extracted state + methods
3. Props: `review` (active comment), `componentId`, `effectivePermissions`
4. Events: `force-withdraw`, `restore`, `move-to-rule`, `hard-delete` (bubble up to parent)
5. Remove duplicated code from both consumers
6. Verify both consumer specs pass
7. Playwright verify admin sidebar still works

**Decision:** AdminActionsPanel should own the content INSIDE the b-sidebar, not the sidebar itself. The sidebar container stays in TriageSplitView (it manages visibility).

---

### Phase 2: dyl.9 — DRY utilities (sp:2, ~12 min)

**What:** Extract 3 duplicated utilities.

1. **relativeTime** — exists in TriageSplitView + CommentTriageModal as `relativeTime(iso) { return new Date(iso).toLocaleString() }`. Replace with `DateFormatMixin.friendlyDateTime` which already exists.

2. **truncate** — exists in RuleContextPanel as `truncate(text, len)`. Extract to `app/javascript/utils/text.js`:
   ```javascript
   export function truncate(text, len) {
     if (!text || text.length <= len) return text;
     return text.slice(0, len) + "...";
   }
   ```

3. **statusOptions** — identical computed in ComponentComments + UserComments. Extract to `triageVocabulary.js`:
   ```javascript
   export function buildStatusFilterOptions() { ... }
   ```

**Files:**
- Create: `app/javascript/utils/text.js`
- Modify: TriageSplitView.vue, CommentTriageModal.vue (add DateFormatMixin, remove relativeTime)
- Modify: RuleContextPanel.vue (import truncate from utils/text)
- Modify: ComponentComments.vue, UserComments.vue (import buildStatusFilterOptions)
- Modify: triageVocabulary.js (add export)

---

### Phase 3: dyl.10 — Vue template fixes (sp:2, ~10 min)

**What:** Fix Vue best practice violations.

1. **v-for on template without :key** — `TriageQueueNav.vue:67`:
   ```html
   <!-- Before -->
   <template v-for="group in ruleGroups">
   <!-- After -->
   <template v-for="group in ruleGroups" :key="group.ruleId">
   ```

2. **Set as Vue 2 prop** — `RuleContextPanel.vue:107`: Change `commentedSections` prop from `Set` to `Array`. Add internal computed that converts to Set. Update TriageSplitView to pass `Array.from(commentedSections)`.

3. **Missing @keydown.space.prevent** — `RuleContextPanel.vue` related-comment items have `role="button"` but no space key handler. Add `@keydown.space.prevent="$emit('select-comment', rc.id)"`.

4. **contextMode prop validator** — Add `validator: (v) => ['commented', 'all'].includes(v)` to RuleContextPanel, TriageSplitView, ComponentComments.

---

### Phase 4: dyl.11 — Test quality + factory cosmetics (sp:2, ~10 min)

**What:** Strengthen assertions, clean up factory naming.

1. **Weak assertions** — `spec/factory_specs/factory_traits_spec.rb` lines 78-79:
   - `expect(component.admin_name).to be_present` → `eq('Test Maintainer')`
   - `expect(component.admin_email).to include('@')` → `eq('maintainer@example.com')`

2. **Redundant :viewer trait** — `spec/factories/memberships.rb`: Remove `:viewer` trait (default role is already 'viewer').

3. **:released vs :released_component** — `spec/factories/components.rb`: Add comment documenting that `:released` supersedes `:released_component`. Keep both for backward compat.

4. **flushPromises duplication** — Extract shared helper from TriageSplitView.spec.js and CommentTriageModal.spec.js into `spec/javascript/support/testHelpers.js`.

5. **Hardcoded #007bff** — `RuleContextPanel.vue` scoped CSS: Replace with `var(--primary)` for Bootstrap 4 theme consistency.

6. **S12 documentation** — Add comment in TriageSplitView.vue documenting that `expected_updated_at` optimistic locking is frontend-only (server does not enforce). Known limitation for follow-up.

---

### Phase 5: dyl.7 — CHANGELOG (sp:1, ~5 min)

**What:** Add [Unreleased] section to CHANGELOG.md covering:

- **Added:** Split-pane triage view with 2D navigation, section comment badges, related comments list, reaction buttons in split-pane
- **Added:** Modular seed system (9 numbered files, SeedHelpers, dev:prime/verify/status/reset)
- **Added:** Feature-complete factory traits (22 traits across 6 models)
- **Added:** ReplyComposerMixin with unified composerState
- **Changed:** All test files migrated from Review.create! to factory traits
- **Fixed:** STIG factory deadlock in parallel tests
- **Fixed:** Cross-project comment seed idempotency
- **Fixed:** Bidirectional rule_id sync in Review model
- **Fixed:** Prop mutation in split-pane reaction toggle

---

## Git State at Compact Time

- Branch: `feat/comment-triage-context-panel`
- Last commit: `7469eef` fix: review findings — prop mutation, dev:reset, factories, seeds
- 27 commits ahead of master
- Working tree: clean (all Phase 1 committed)

## Test State

- Frontend: 138/138 triage tests passing
- Backend: 102/102 factory specs passing
- RuboCop: 0 offenses
- ESLint: 0 warnings

## Work Order After Compact

```
1. bd update vulcan-v3.x-dyl.2 --status in_progress
2. Fix dyl.2 (AdminActionsPanel) — biggest card, ~35 min
3. Fix dyl.9 (DRY utilities) — ~12 min
4. Commit Phase 2
5. Fix dyl.10 (Vue template fixes) — ~10 min
6. Commit Phase 3
7. Fix dyl.11 (test quality) — ~10 min
8. Commit Phase 4
9. Fix dyl.7 (CHANGELOG) — ~5 min
10. Commit Phase 5
11. Full test suite: yarn test:unit && bundle exec rake spec:parallel
12. Playwright full walkthrough
13. Open PR
```
