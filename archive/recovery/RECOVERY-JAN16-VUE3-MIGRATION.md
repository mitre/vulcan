# Recovery Context - January 16, 2025 - Vue 3 Migration Ready

## 🔴 CRITICAL - READ FIRST
**ALWAYS READ**: `/Users/alippold/.claude/CLAUDE.md` and `/Users/alippold/github/mitre/vulcan/CLAUDE.md`
- **NEVER use `git add -A` or `git add .`** - ALWAYS add files individually
- **WE DO NOT COMMIT BROKEN CODE EVER** - all tests and linting must pass
- **Use YARN for JavaScript, NOT npm**
- **Git commits use**: `Authored by: Aaron Lippold<lippold@gmail.com>` - NO Claude signatures

## 📍 CURRENT STATE (January 16, 2025)
- **Location**: `/Users/alippold/github/mitre/vulcan`
- **Current Branch**: `fix/issue-681-configurable-status-fields` (PR #684 pending)
- **Rails**: 8.0.2.1 ✅
- **Ruby**: 3.3.9 ✅
- **Node**: 22 LTS ✅
- **Tests**: 190 passing ✅
- **Vue**: 2.6.11 (ready for migration)
- **Bootstrap**: 4.4.1 with Bootstrap-Vue 2.13.0 (ready for migration)

## 🔄 WORK IN PROGRESS

### PR #684 - Bug Fix
- **Status**: CI running, ready to merge
- **Issue**: #681 - "Applicable - Configurable" field display bug
- **Fix**: Made `checkFormFields` conditional in `BasicRuleForm.vue`
- **File**: `app/javascript/components/rules/forms/BasicRuleForm.vue`
- **Will auto-close issue #681 when merged**

### Vue 3 Migration - Ready to Start
- **Branch Created**: `feature/vue3-bootstrap5-migration`
- **Documents Created**: All 3 planning documents committed
  - `VUE3-BOOTSTRAP5-MIGRATION-PLAN.md` - Strategy
  - `VUE3-BOOTSTRAP5-TECHNICAL-IMPLEMENTATION.md` - Code details
  - `VUE3-BOOTSTRAP5-EXECUTION-PLAN.md` - 6-phase branch strategy
- **Next Action**: Start Phase 1 - Remove Turbolinks (4-8 hours)

## ✅ COMPLETED TODAY (January 16)
1. Fixed issue #681 - Applicable-Configurable status field bug
2. Created comprehensive Vue 3 migration plan
3. Closed stale issues #677, #676, #674
4. Updated CLAUDE.md with project context

## 🎯 MIGRATION PLAN SUMMARY

### Phase 1: Remove Turbolinks (4-8 hours) - START HERE
```bash
git checkout master
git pull origin master
git checkout -b feature/vue3-bootstrap5-migration/remove-turbolinks

# Tasks:
1. Remove turbolinks gem from Gemfile
2. Remove turbolinks, vue-turbolinks from package.json
3. Update all 14 pack files: turbolinks:load → DOMContentLoaded
4. Remove data-turbolinks-track from layouts
5. Test all pages load correctly
```

### Remaining Phases (7-9 weeks total)
2. Vue 3 Setup (1 day)
3. Global Components (1 week)
4. Simple Pages (1-2 weeks)
5. Project Pages (2 weeks)
6. Complex Pages (2-3 weeks)

## 🔑 KEY DECISIONS MADE
- **Remove Turbolinks entirely** - vue-turbolinks is dead, no Vue 3 support
- **Migrate Vue 3 + Bootstrap 5 together** - page by page
- **Keep 14 separate Vue instances** - don't consolidate
- **Use native Bootstrap 5** - not Bootstrap-Vue-Next (too buggy)

## 🔍 MCP MEMORY KEYS
```
mcp__server-memory__open_nodes with names:
["Vue 3 Migration Plan", "Vue 3 Migration Execution Plan",
 "Vue 3 Technical Implementation", "Vue 3 Migration Progress",
 "Vulcan Technical Learnings", "Next Steps Vulcan"]
```

## 📂 FILE LOCATIONS
- Migration docs: `/Users/alippold/github/mitre/vulcan/VUE3-*.md`
- Bug fix: `app/javascript/components/rules/forms/BasicRuleForm.vue`
- Package files: `package.json`, `Gemfile`
- JavaScript packs: `app/javascript/packs/*.js` (14 files)

## ⚠️ IMPORTANT REMINDERS
- Turbolinks removal affects ALL 14 JavaScript pack files
- Each Vue instance needs individual migration
- Bootstrap-Vue components need manual replacement with Bootstrap 5
- Test after each phase before merging sub-branches

## 💭 CONTEXT
Yesterday (Jan 15) we completed Rails 8 upgrade and all dependency updates. Today we fixed a UI bug and created the complete Vue 3 migration plan. The project is now ready for the Vue 3 + Bootstrap 5 migration which will modernize the frontend completely.

The user values stability and thorough testing. Always run linting and tests before committing. The migration should be done in stable, testable phases using sub-branches.