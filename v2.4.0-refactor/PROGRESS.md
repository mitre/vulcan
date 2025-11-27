# v2.4.0 Refactor Progress Tracker

**Last Updated:** 2025-11-27
**Current Phase:** Planning Complete
**Next Phase:** Phase 1 (Database Redesign)

---

## Quick Status

| Phase | Status | Progress | Tests | Notes |
|-------|--------|----------|-------|-------|
| Phase 1: Database | ⏸️ Not Started | 0% | - | Ready to begin |
| Phase 2: Services | ⏸️ Not Started | 0% | - | Waiting on Phase 1 |
| Phase 3: Pundit | ⏸️ Not Started | 0% | - | Waiting on Phase 2 |
| Phase 4: Queries | ⏸️ Not Started | 0% | - | Waiting on Phase 3 |
| Phase 5: Blueprinter | ⏸️ Not Started | 0% | - | Waiting on Phase 4 |
| Phase 6: Full API | ⏸️ Not Started | 0% | - | Waiting on Phase 5 |
| Phase 7: Update File | ⏸️ Not Started | 0% | - | Waiting on Phase 6 |
| Phase 8: Backup/Restore | ⏸️ Not Started | 0% | - | Waiting on Phase 7 |
| Phase 9: mavonEditor | ⏸️ Not Started | 0% | - | Waiting on Phase 8 |
| Phase 10: Vue 3 + BS5 | ⏸️ Not Started | 0% | - | Waiting on Phase 9 |

**Legend:** ⏸️ Not Started | 🔄 In Progress | ✅ Complete | ⚠️ Blocked

---

## Current Statistics

### Baseline (Before Refactor)
- **Component Model:** 785 LOC
- **Rule Model:** 358 LOC
- **ApplicationController:** 245 LOC
- **ComponentsController:** 430 LOC
- **Total Tests:** 309 examples
- **Test Coverage:** ~85%

### Targets (After Refactor)
- **Component Model:** ~400 LOC (49% reduction)
- **Rule Model:** ~200 LOC (44% reduction)
- **ApplicationController:** ~100 LOC (59% reduction)
- **ComponentsController:** ~200 LOC (53% reduction)
- **Total Tests:** ~400+ examples (after all 10 phases)
- **Test Coverage:** >90%
- **Frontend:** Vue 3 + Bootstrap 5 (modern stack)

### Current (Updated as phases complete)
- **Component Model:** 785 LOC (baseline)
- **Rule Model:** 358 LOC (baseline)
- **ApplicationController:** 245 LOC (baseline)
- **ComponentsController:** 430 LOC (baseline)
- **Total Tests:** 309 examples
- **Test Coverage:** ~85%

---

## PHASE 1: Database Redesign

**Status:** ⏸️ Not Started
**Estimated:** 8-12 hours
**Actual:** -

### Tasks
- [ ] Create `component_srg_satisfactions` migration
- [ ] Write data migration script
- [ ] Test migration on copy of production data
- [ ] Run migration
- [ ] Update Component model associations
- [ ] Update import methods to use new schema
- [ ] Write comprehensive tests
- [ ] Verify all 309+ tests pass
- [ ] Manual testing checklist complete

### Commits
None yet

### Blockers
None

### Notes
Ready to begin. Have copy of production data for testing.

---

## PHASE 2: Service Objects

**Status:** ⏸️ Not Started
**Estimated:** 15-20 hours
**Actual:** -

### Tasks
- [ ] Create `app/services/` directory structure
- [ ] Create ApplicationService base class
- [ ] Extract Imports::XccdfImportService
- [ ] Extract Imports::SpreadsheetImportService
- [ ] Extract Imports::SrgMappingService
- [ ] Extract Exports::XccdfExportService
- [ ] Extract Exports::CsvExportService
- [ ] Extract Components::DuplicationService
- [ ] Extract Components::SatisfactionParserService
- [ ] Update controllers to use services
- [ ] Write service tests (100% coverage)
- [ ] Verify all functionality identical

### Commits
None yet

### Blockers
Waiting on Phase 1 completion

### Notes
Will establish service pattern for all future features

---

## PHASE 3: Pundit Authorization

**Status:** ⏸️ Not Started
**Estimated:** 8-12 hours
**Actual:** -

### Tasks
- [ ] Install Pundit gem
- [ ] Generate application_policy.rb
- [ ] Create ComponentPolicy
- [ ] Create ProjectPolicy
- [ ] Update all controllers to use `authorize`
- [ ] Remove permission methods from User model
- [ ] Remove authorization methods from ApplicationController
- [ ] Write policy specs (100% coverage)
- [ ] Verify all authorization works

### Commits
None yet

### Blockers
Waiting on Phase 2 completion

### Notes
Will centralize all 16 scattered permission methods

---

## PHASE 4: Query Objects

**Status:** ⏸️ Not Started
**Estimated:** 4-6 hours
**Actual:** -

### Tasks
- [ ] Create `app/queries/` directory
- [ ] Create ApplicationQuery base class
- [ ] Extract ComponentRulesSummaryQuery
- [ ] Extract ProjectDetailsQuery
- [ ] Extract RelatedRulesQuery
- [ ] Update models to use query objects
- [ ] Verify performance improved (Bullet gem)
- [ ] Write query tests (100% coverage)

### Commits
None yet

### Blockers
Waiting on Phase 3 completion

### Notes
Target: 10+ queries → 2-3 queries for rules_summary

---

## PHASE 5: Blueprinter Serialization

**Status:** ⏸️ Not Started
**Estimated:** 6-8 hours
**Actual:** -

### Tasks
- [ ] Install Blueprinter gem
- [ ] Create `app/blueprints/` directory
- [ ] Create ComponentBlueprint (list/detail views)
- [ ] Create RuleBlueprint
- [ ] Create ProjectBlueprint
- [ ] Create ReviewBlueprint
- [ ] Create MembershipBlueprint
- [ ] Update controllers to use blueprints
- [ ] Remove `as_json` methods from models
- [ ] Write blueprint specs (95% coverage)

### Commits
None yet

### Blockers
Waiting on Phase 4 completion

### Notes
Foundation for clean API responses

---

## PHASE 6: Full API Layer

**Status:** ⏸️ Not Started
**Estimated:** 20-30 hours
**Actual:** -

### Tasks
- [ ] Create `/api/v1/` routes
- [ ] Create Api::V1::BaseController
- [ ] Add `api_token` to users migration
- [ ] Implement token authentication
- [ ] Create ComponentsController (API)
- [ ] Create ProjectsController (API)
- [ ] Create RulesController (API)
- [ ] Create SRGsController (API)
- [ ] Create StigsController (API)
- [ ] Configure Rack::Attack rate limiting
- [ ] Configure CORS
- [ ] Install rswag for documentation
- [ ] Write Swagger specs for all endpoints
- [ ] Generate API documentation
- [ ] Write comprehensive API tests (95% coverage)

### Commits
None yet

### Blockers
Waiting on Phase 5 completion

### Notes
Full REST API for external integrations

---

## PHASE 7: Update from File

**Status:** ⏸️ Not Started
**Estimated:** 2-3 hours
**Actual:** -

### Tasks
- [ ] Add `update` method to XccdfImportService
- [ ] Add `update` method to SpreadsheetImportService
- [ ] Add `update_from_file` controller action
- [ ] Add UI button "Update from File"
- [ ] Write update tests
- [ ] Test roundtrip (export → edit → update)

### Commits
None yet

### Blockers
Waiting on Phase 2 (needs services)

### Notes
Enables external editing workflow

---

## PHASE 8: Project Backup/Restore

**Status:** ⏸️ Not Started
**Estimated:** 3-4 hours
**Actual:** -

### Tasks
- [ ] Create Projects::BackupService
- [ ] Create Projects::RestoreService
- [ ] Add export_backup controller action
- [ ] Add import_backup controller action
- [ ] Add UI buttons for backup/restore
- [ ] Write backup/restore tests
- [ ] Test cross-instance restore

### Commits
None yet

### Blockers
Waiting on Phase 2 (needs export services)

### Notes
Complete disaster recovery solution

---

## PHASE 9: mavonEditor Integration

**Status:** ⏸️ Not Started
**Estimated:** 4-6 hours
**Actual:** -

### Tasks
- [ ] Install mavon-editor package
- [ ] Create RichMarkdownEditor component
- [ ] Replace vuln_discussion textarea
- [ ] Replace mitigations textarea
- [ ] Replace fixtext textarea
- [ ] Replace potential_impacts textarea
- [ ] Test markdown save/load
- [ ] Test markdown export/import
- [ ] Write Vitest tests

### Commits
None yet

### Blockers
Waiting on Phase 8

### Notes
Markdown editing for large text fields (Vue 2)

---

## PHASE 10: Vue 3 + Bootstrap 5 Migration

**Status:** ⏸️ Not Started
**Estimated:** 30-40 hours
**Actual:** -

### Tasks
- [ ] Research Bootstrap 5 component equivalents
- [ ] Update dependencies (Vue 3, Bootstrap 5)
- [ ] Remove Turbolinks
- [ ] Migrate toaster.js (simplest)
- [ ] Migrate navbar.js
- [ ] Migrate projects.js
- [ ] Migrate project.js
- [ ] Migrate security_requirements_guides.js
- [ ] Migrate stigs.js
- [ ] Migrate components.js
- [ ] Migrate component.js
- [ ] Migrate project_components.js
- [ ] Migrate project_component.js
- [ ] Migrate rule.js (most complex)
- [ ] Migrate advanced_rule.js
- [ ] Migrate basic_rule.js
- [ ] Migrate application.js
- [ ] Update all Vue components for Vue 3
- [ ] Update Bootstrap 4 → 5 classes
- [ ] Test all 14 pages thoroughly
- [ ] Write Vue 3 component tests

### Commits
None yet

### Blockers
Waiting on Phase 9 (should have mavonEditor in Vue 2 first)

### Notes
Major frontend migration - page by page approach

---

## Session Log

### 2025-11-27 (Planning Session)
**Time:** 2 hours
**Work:**
- Comprehensive architectural audit completed
- Research on Rails best practices
- Identified proven gems to adopt:
  - Pundit (8,454 stars) - authorization
  - Blueprinter (1,100 stars) - serialization
  - POROs for services/queries (no gems)
- Created 8-phase refactor plan
- Realistic effort estimates: 66-95 hours
- Created planning folder structure

**Decisions:**
- Do all 8 phases for complete foundation
- Focus on quality and testing
- Don't worry about incremental releases
- Work efficiently but thoroughly

**Next Session:**
- Start Phase 1: Database Redesign
- Create migration and data migration script
- Test thoroughly

---

## Testing Progress

### Test Count by Phase
- **Baseline:** 309 examples
- **After Phase 1:** +10 tests = 319
- **After Phase 2:** +20 tests = 339
- **After Phase 3:** +15 tests = 354
- **After Phase 4:** +8 tests = 362
- **After Phase 5:** +10 tests = 372
- **After Phase 6:** +20 tests = 392
- **After Phase 7:** +5 tests = 397
- **After Phase 8:** +5 tests = 402
- **After Phase 9:** +5 tests = 407 (Vitest for mavonEditor)
- **After Phase 10:** +15 tests = 422 (Vue 3 component tests)

**Target:** ~420 tests with >90% coverage

---

## Quality Gates (Every Phase)

Before marking any phase complete, ALL must be ✅:

- [ ] All tests pass (no failures, no pending)
- [ ] RuboCop clean (0 offenses)
- [ ] Brakeman clean (0 security issues)
- [ ] No N+1 queries (Bullet verification)
- [ ] Manual testing checklist complete
- [ ] Code reviewed
- [ ] Documentation updated
- [ ] Committed with clear message

---

## Current Branch Status

**Branch:** v2.3.0
**Commits:** 16 (ready to merge or continue)
**Tests:** 309 passing
**Status:** Clean working tree

**Refactor work will happen on:** v2.4.0 branch (create after deciding)

---

## Recovery Prompt (For Future Sessions)

```
I need to restore context for Vulcan v2.4.0 refactor work.

1. Load memcord: /memcord-use vulcan-2.3.0-helm-0.3.0-coordinated-release

2. Review planning docs:
   - v2.4.0-refactor/PROGRESS.md (current status)
   - v2.4.0-refactor/MASTER-PLAN.md (full plan)

3. Current phase: [Check PROGRESS.md]

4. Show: git status

5. Show: git log --oneline -5

6. Resume work on current phase
```

---

## Notes & Observations

### Keep Updated:
- Current phase status
- Blockers encountered
- Decisions made
- Time actual vs estimated
- Any scope changes

### Review After Each Phase:
- Did estimates match reality?
- Any unexpected issues?
- Pattern working well?
- Need to adjust future phases?

---

**Last updated:** 2025-11-27 (Planning complete, ready to execute)
