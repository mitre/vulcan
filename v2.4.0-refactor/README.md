# v2.4.0 Refactor Planning Directory

**Purpose:** Comprehensive architectural refactor to establish best-practice foundation
**Timeline:** 66-95 hours over 2.5-3 weeks
**Approach:** Adopt proven Rails patterns, test thoroughly, execute efficiently

---

## Directory Contents

### Core Planning Documents

**MASTER-PLAN.md** - Complete 8-phase refactor plan
- Phase descriptions
- Task breakdowns
- Code examples
- Testing checklists
- Completion criteria

**PROGRESS.md** - Current status tracker
- What's complete
- What's in progress
- What's next
- Session log
- Actual vs estimated hours

**RESEARCH-FINDINGS.md** - Rails best practices research
- Service object patterns
- Pundit authorization
- Blueprinter serialization
- Query object patterns
- Gem evaluations
- Community consensus

**TESTING-CHECKLIST.md** - Quality gates and testing strategy
- Automated testing requirements
- Manual testing checklists
- Phase-specific tests
- Regression testing
- Performance testing

---

## Quick Start (New Session)

### 1. Check Current Status
```bash
cat v2.4.0-refactor/PROGRESS.md | head -20
```

### 2. Review Current Phase
```bash
# See what tasks are pending for current phase
grep -A 20 "Current Phase" v2.4.0-refactor/PROGRESS.md
```

### 3. Load Context
- Read PROGRESS.md for current state
- Check MASTER-PLAN.md for current phase details
- Review TESTING-CHECKLIST.md for quality gates

### 4. Start Working
- Execute tasks for current phase
- Update PROGRESS.md as you go
- Check off items in testing checklist
- Commit when phase complete

---

## The 10 Phases

| # | Phase | Hours | Focus |
|---|-------|-------|-------|
| 1 | Database Redesign | 8-12h | Fix data model |
| 2 | Service Objects | 15-20h | Extract business logic |
| 3 | Pundit Authorization | 8-12h | Centralize permissions |
| 4 | Query Objects | 4-6h | Optimize performance |
| 5 | Blueprinter | 6-8h | Clean serialization |
| 6 | Full API | 20-30h | External integrations |
| 7 | Update from File | 2-3h | External editing |
| 8 | Backup/Restore | 3-4h | Disaster recovery |
| 9 | mavonEditor | 4-6h | Markdown editing |
| 10 | Vue 3 + Bootstrap 5 | 30-40h | Frontend migration |

**Total:** 100-141 hours (4-5 weeks)

---

## Gems to Install

### During Refactor
```ruby
# Phase 3
gem 'pundit'

# Phase 5
gem 'blueprinter'

# Phase 6
gem 'rswag'
gem 'rswag-api'
gem 'rswag-ui'
gem 'rack-cors' # Might already have

# Development/Test
gem 'bullet', group: :development
gem 'rspec-benchmark', group: :test
```

### Don't Install (Use POROs)
- interactor
- dry-rb
- rails-patterns

---

## Quality Standards

Every phase must meet ALL criteria:
- ✅ All tests pass
- ✅ RuboCop clean
- ✅ Brakeman clean
- ✅ No N+1 queries
- ✅ Coverage >90% for new code
- ✅ Manual testing complete

**No exceptions.**

---

## What This Achieves

### Code Quality
- Component: 785 → ~400 LOC
- ApplicationController: 245 → ~100 LOC
- ComponentsController: 430 → ~200 LOC

### Patterns Established
- Service objects
- Policy objects
- Query objects
- Blueprints
- API controllers

### Features Delivered
- Clean database (no duplicates)
- Centralized authorization
- Optimized queries
- Full REST API
- Update from file
- Project backup/restore

### Future Benefits
- Features 3x easier to build
- Bugs 2x easier to fix
- Performance issues 2x easier to solve
- New developers onboard faster

---

## Recovery Prompt (For Context Restore)

```
I need to restore context for Vulcan v2.4.0 refactor.

1. Load memcord: /memcord-use vulcan-2.3.0-helm-0.3.0-coordinated-release

2. Review status: v2.4.0-refactor/PROGRESS.md

3. Check current phase and tasks

4. Review plan: v2.4.0-refactor/MASTER-PLAN.md

5. Continue with current phase
```

---

## Session Guidelines

### At Start of Session
1. Read PROGRESS.md
2. Review current phase in MASTER-PLAN.md
3. Check testing requirements in TESTING-CHECKLIST.md
4. Start working

### During Session
1. Update PROGRESS.md as tasks complete
2. Run tests frequently
3. Commit completed tasks
4. Note any blockers or decisions

### At End of Session
1. Update PROGRESS.md with current state
2. Run full test suite
3. Commit all work
4. Note what's next in PROGRESS.md

---

## Important Notes

### Do Not Commit This Folder
This is internal planning documentation. Add to `.gitignore`:
```
v2.4.0-refactor/
```

### Keep All Files
- Session notes
- Research findings
- Progress tracking
- Testing checklists

These maintain context across sessions.

---

**Planning complete. Ready to execute Phase 1.**
