# REVISED PHASE ORDER (Frontend First)

**Date:** 2025-11-27
**Decision:** Move Vue 3 + Bootstrap 5 migration to PHASE 1
**Reason:** Don't refactor on deprecated stack, do it right from the start

---

## NEW PHASE ORDER

### ⚡ PHASE 1: Vue 3 + Bootstrap 5 Migration (30-40 hours)
**Priority:** CRITICAL - Do first
**Why first:** All other work happens on modern, stable frontend

**Major tasks:**
- Remove Vue 2, Bootstrap-Vue, Turbolinks
- Add Vue 3, Bootstrap 5
- Migrate all 14 Vue instances page-by-page
- Update all components for Vue 3 compatibility
- Optional: Migrate to Vite (or keep esbuild)

**Result:** Modern frontend foundation

---

### 🔴 PHASE 2: Database Redesign (8-12 hours)
**Priority:** CRITICAL - Data model foundation
**Why second:** Backend refactoring needs correct data model

**Major tasks:**
- New `component_srg_satisfactions` join table
- Data migration to remove duplicates
- Update relationships
- Clean satisfaction architecture

**Result:** Clean data model (13 rules not 264)

---

### 🔴 PHASE 3: Service Objects (15-20 hours)
**Priority:** CRITICAL - Backend foundation
**Why third:** Extract business logic from fat models

**Major tasks:**
- Create `app/services/` structure
- Extract import/export services
- Extract component/project services
- Establish service pattern

**Result:** Component model 785 → ~400 LOC

---

### 🔴 PHASE 4: Pundit Authorization (8-12 hours)
**Priority:** CRITICAL - Security
**Why fourth:** Centralize scattered permissions

**Major tasks:**
- Install Pundit
- Create policies (Component, Project)
- Update controllers to use `authorize`
- Remove 16 scattered permission methods

**Result:** ApplicationController 245 → ~100 LOC

---

### 🟡 PHASE 5: Query Objects (4-6 hours)
**Priority:** HIGH - Performance
**Why fifth:** Optimize complex queries

**Major tasks:**
- Create `app/queries/` structure
- Extract ComponentRulesSummaryQuery
- Extract complex queries
- Fix N+1 issues

**Result:** 10+ queries → 2-3 queries

---

### 🟢 PHASE 6: Blueprinter Serialization (6-8 hours)
**Priority:** MEDIUM - API preparation
**Why sixth:** Clean JSON for API

**Major tasks:**
- Install Blueprinter
- Create blueprints for all models
- Replace `as_json` methods
- Different views (list/detail)

**Result:** Clean, consistent JSON responses

---

### 🟢 PHASE 7: Full API Layer (20-30 hours)
**Priority:** MEDIUM - External integrations
**Why seventh:** Build on clean serialization

**Major tasks:**
- Create `/api/v1/` namespace
- Token authentication
- Rate limiting (Rack::Attack)
- CORS configuration
- Swagger documentation

**Result:** Full REST API for external clients

---

### 🟢 PHASE 8: Update from File (2-3 hours)
**Priority:** MEDIUM - User workflow
**Why eighth:** Uses services from Phase 3

**Major tasks:**
- Add update mode to import services
- Controller action
- UI button

**Result:** Export → Edit → Update workflow

---

### 🟢 PHASE 9: Project Backup/Restore (3-4 hours)
**Priority:** MEDIUM - Disaster recovery
**Why ninth:** Uses services from Phase 3

**Major tasks:**
- Projects::BackupService
- Projects::RestoreService
- ZIP export/import
- UI buttons

**Result:** Full project backup/restore

---

### 🟢 PHASE 10: md-editor-v3 Integration (4-6 hours)
**Priority:** LOW - UX polish
**Why last:** Frontend already on Vue 3, easy add

**Major tasks:**
- Install md-editor-v3 (Vue 3 native)
- Create RichMarkdownEditor component
- Replace 4 textareas
- Test save/load/export

**Result:** Markdown editing in key fields

---

## Timeline with New Order

| Week | Days | Phase | Hours | Cumulative |
|------|------|-------|-------|------------|
| 1 | Mon-Fri | Phase 1: Vue 3 + BS5 | 30-40h | 30-40h |
| 2 | Mon-Tue | Phase 2: Database | 8-12h | 38-52h |
| 2 | Wed-Fri | Phase 3: Services | 15-20h | 53-72h |
| 3 | Mon-Tue | Phase 4: Pundit | 8-12h | 61-84h |
| 3 | Wed | Phase 5: Queries | 4-6h | 65-90h |
| 3 | Thu | Phase 6: Blueprinter | 6-8h | 71-98h |
| 4 | Mon-Thu | Phase 7: API | 20-30h | 91-128h |
| 4 | Fri AM | Phase 8: Update File | 2-3h | 93-131h |
| 4 | Fri PM | Phase 9: Backup | 3-4h | 96-135h |
| 5 | Mon | Phase 10: md-editor-v3 | 4-6h | 100-141h |

**Total: 4-5 weeks**

---

## Key Benefits of This Order

### ✅ Frontend Modern From Day 1
- All refactoring happens on Vue 3 (not Vue 2)
- All new components written for Vue 3
- No migration work later

### ✅ Single Markdown Editor Implementation
- Skip mavonEditor (Vue 2)
- Only implement md-editor-v3 (Vue 3)
- Do it once, do it right

### ✅ Modern Stack Throughout
- Vue 3 from start
- Bootstrap 5 from start
- All patterns (services, policies) built on modern frontend

### ✅ No Rework
- Don't build features in Vue 2 then migrate to Vue 3
- Build once on final architecture

---

## Build Tool Decision (esbuild vs Vite)

**Current:** esbuild (fast, works great)

**Vite pros:**
- Hot Module Replacement (HMR) - faster dev
- Better dev server
- Standard for Vue 3 projects

**Vite cons:**
- Migration effort (+4-6h to Phase 1)
- Another tool to learn
- esbuild already fast enough

**Recommendation:** **Keep esbuild for now**
- Works great with Vue 3
- One less thing to migrate
- Can add Vite later if HMR becomes important

**IF you want Vite:** Add to Phase 1 as part of Vue 3 migration (+4-6h)

---

## Updated Dependencies After Phase 1

### Remove:
```json
{
  "vue": "^2.6.11",
  "bootstrap": "^4.4.1",
  "bootstrap-vue": "^2.13.0",
  "vue-turbolinks": "^2.0.3"
}
```

### Add:
```json
{
  "vue": "^3.5.0",
  "bootstrap": "^5.3.3",
  "@popperjs/core": "^2.11.8"
}
```

### Phase 10 adds:
```json
{
  "md-editor-v3": "^4.0.0"
}
```

---

## Summary: Frontend-First Approach

**Week 1:** Vue 3 + Bootstrap 5 migration (DONE = modern stack)
**Weeks 2-4:** Backend refactoring (services, policies, API) on Vue 3
**Week 5:** Final features (backup, markdown editor)

**Result:** Everything built on modern, stable foundation from day 1

---

**Should I update MASTER-PLAN.md to reflect this new Phase 1-first order?**