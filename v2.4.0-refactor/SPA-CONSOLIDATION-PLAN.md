# Vulcan SPA Consolidation Plan

**Created:** 2025-11-27
**Based on:** Research from zakariaf/rails-base-app and Edderic/breathesafe
**Approach:** Single Vue 3 SPA with Vue Router + Pinia + Bootstrap-Vue-Next

---

## Research Findings

### Real-World Examples Analyzed

1. **zakariaf/rails-base-app** (234 stars)
   - Rails 7 + Vue 3 + Vite + Pinia + Vue Router
   - Uses TWO separate SPAs: "website" (public) and "panel" (authenticated)
   - Structure:
     - `app/javascript/entrypoints/` - Entry points (panel.ts, website.ts)
     - `app/javascript/pages/` - Route components
     - `app/javascript/routers/` - Router configs
     - `app/javascript/stores/` - Pinia stores
     - `app/javascript/layouts/` - Layout components
   - Each SPA has its own router, routes, and layout

2. **Edderic/breathesafe**
   - Rails + Vue 3 + Pinia + Vue Router
   - Single SPA with 30+ routes
   - Uses createWebHashHistory() for routing
   - Demonstrates router guards for auth/consent

### Key Insights from Research

**Vue.js Official Guidance:**
- SPAs work well with backend APIs
- Use Vue Router for client-side navigation
- Pinia is the official state management (replaces Vuex)
- Use Composition API for new code

**Pinia Best Practices:**
- Name stores with `use` prefix and `Store` suffix (e.g., `useAuthStore`)
- Use Setup Stores (Composition API) for flexibility
- Keep stores in separate files for code-splitting
- Don't destructure - use `storeToRefs()` for reactivity

**Vue Router Best Practices:**
- Use `createWebHistory()` for clean URLs
- Place route components in `pages/` or `views/` directory
- Use lazy loading: `() => import('./Component.vue')`
- Use route guards for authentication

---

## Architecture Decision

### Vulcan's Unique Situation

Current: 14 separate Vue instances (one per page)
Problem: Bootstrap-Vue-Next requires BApp wrapper + single app

**Decision: Consolidate to SINGLE SPA**

Why:
- Bootstrap-Vue-Next architecture requires it
- Enables proper modal/toast management
- Simplifies state management with Pinia
- Modern Vue 3 best practices
- Easier to maintain long-term

---

## Proposed Structure

```
app/javascript/
├── entrypoints/
│   └── application.js          # Main SPA entry point
├── App.vue                      # Root component with BApp
├── router/
│   └── index.js                 # Vue Router configuration
├── routes/
│   └── index.js                 # Route definitions
├── pages/                       # Route components (views)
│   ├── projects/
│   │   ├── IndexPage.vue       # /projects
│   │   └── ShowPage.vue        # /projects/:id
│   ├── components/
│   │   ├── IndexPage.vue       # /components
│   │   └── ShowPage.vue        # /components/:id
│   ├── rules/
│   │   └── EditPage.vue        # /rules/:id/edit
│   ├── stigs/
│   │   └── IndexPage.vue       # /stigs
│   └── LoginPage.vue           # /login
├── components/                  # Reusable components
│   ├── navbar/
│   ├── projects/
│   ├── rules/
│   └── shared/
├── stores/                      # Pinia stores
│   ├── index.js                # Pinia instance
│   ├── auth.js                 # useAuthStore
│   ├── projects.js             # useProjectsStore
│   └── toast.js                # useToastStore
├── composables/                 # Vue composables
│   ├── useApi.js
│   └── useAuth.js
└── bootstrap-vue-next-components.js  # Keep for now
```

---

## Implementation Plan

### Phase 1: Setup Infrastructure (2-3h)

1. **Install dependencies**
   ```bash
   pnpm add vue-router@4 pinia
   ```

2. **Create single entry point**
   - `app/javascript/entrypoints/application.js`
   - Imports App.vue root component
   - Sets up Vue Router + Pinia
   - Registers Bootstrap-Vue-Next components

3. **Create App.vue root component**
   - Wrap with `<BApp>` for Bootstrap-Vue-Next
   - Include `<router-view>` for page content
   - Include navbar (always visible)
   - Include toaster (always visible)

4. **Update Rails layout**
   - Single layout that loads application.js
   - Single `#app` mount point
   - All routes render same layout

### Phase 2: Setup Routing (2-3h)

1. **Create router configuration**
   - `app/javascript/router/index.js`
   - Use `createWebHistory()` for clean URLs
   - Define base path if needed

2. **Define routes** (14 routes for 14 current pages)
   ```javascript
   const routes = [
     { path: '/projects', component: () => import('@/pages/projects/IndexPage.vue') },
     { path: '/projects/new', component: () => import('@/pages/projects/NewPage.vue') },
     { path: '/projects/:id', component: () => import('@/pages/projects/ShowPage.vue') },
     { path: '/components', component: () => import('@/pages/components/IndexPage.vue') },
     { path: '/components/:id', component: () => import('@/pages/components/ShowPage.vue') },
     // ... 9 more routes
   ]
   ```

3. **Configure Rails routes**
   - Catch-all route: `get '*path', to: 'application#index'`
   - All non-API routes serve the SPA
   - SPA handles routing client-side

### Phase 3: Setup Pinia Stores (2-3h)

1. **Create Pinia instance**
   ```javascript
   // app/javascript/stores/index.js
   import { createPinia } from 'pinia'
   export const pinia = createPinia()
   ```

2. **Create auth store**
   ```javascript
   // app/javascript/stores/auth.js
   import { defineStore } from 'pinia'
   
   export const useAuthStore = defineStore('auth', () => {
     const user = ref(null)
     const signedIn = computed(() => !!user.value)
     
     function setUser(userData) {
       user.value = userData
     }
     
     return { user, signedIn, setUser }
   })
   ```

3. **Create toast store** (for Bootstrap-Vue-Next toasts)
   ```javascript
   // app/javascript/stores/toast.js
   import { defineStore } from 'pinia'
   import { useToast } from 'bootstrap-vue-next'
   
   export const useToastStore = defineStore('toast', () => {
     const toast = useToast()
     
     function show(message, options = {}) {
       toast?.show({
         props: {
           body: message,
           title: options.title || 'Notification',
           variant: options.variant || 'info',
         }
       })
     }
     
     return { show }
   })
   ```

### Phase 4: Migrate Pages (10-15h)

Convert each of the 14 current pages to route components:

1. **Create page components** (1h each × 14 = 14h)
   - Move logic from current Vue instances to page components
   - Use Composition API where beneficial
   - Keep Options API where it works

2. **Migration order** (simple → complex):
   1. LoginPage.vue (login.js)
   2. ProjectsIndexPage.vue (projects.js)
   3. ProjectShowPage.vue (project.js)
   4. ComponentsIndexPage.vue (components page)
   5. ComponentShowPage.vue (component page)
   6. RuleEditPage.vue (rules.js)
   7. StigsIndexPage.vue (stigs.js)
   8. StigShowPage.vue (stig.js)
   9. SRGsIndexPage.vue (security_requirements_guides.js)
   10. UsersPage.vue (users.js)
   11. ProjectComponentsPage.vue (project_components.js)
   12. ProjectComponentPage.vue (project_component.js)
   13. NewProjectPage.vue (new_project.js)
   14. HomePage.vue (root /)

### Phase 5: Update Components (3-5h)

1. **Navbar** - Already mostly working
   - Make reactive to route changes
   - Use router.push() instead of href

2. **Shared components** - Already in `app/javascript/components/`
   - No changes needed (already working)

3. **Remove page-specific pack files**
   - Delete all 14 pack files
   - Keep only application.js entry point

### Phase 6: Testing & Cleanup (3-5h)

1. **Test all routes**
2. **Test navigation**
3. **Test authentication flow**
4. **Remove @vue/compat** (move to pure Vue 3)
5. **Update tests**

---

## Benefits of SPA Approach

### Pros ✅
- Bootstrap-Vue-Next works properly (BApp wrapper)
- Modals and toasts work correctly
- Client-side navigation (faster UX)
- Pinia state management (shared state between pages)
- Modern Vue 3 architecture
- Single entry point (simpler builds)
- Easier to maintain

### Cons ❌
- Initial load includes all JS (larger bundle)
  - **Mitigation:** Route-level code splitting with lazy loading
- Loss of Rails server-side rendering
  - **Mitigation:** Not critical for authenticated app
- All pages share same context
  - **Mitigation:** This is actually a PRO (shared state)

---

## Estimated Timeline

| Phase | Task | Hours |
|-------|------|-------|
| 1 | Setup infrastructure | 2-3h |
| 2 | Setup routing | 2-3h |
| 3 | Setup Pinia stores | 2-3h |
| 4 | Migrate 14 pages | 10-15h |
| 5 | Update components | 3-5h |
| 6 | Testing & cleanup | 3-5h |
| **Total** | | **22-34h** |

---

## Next Steps

1. Review this plan
2. Install Vue Router + Pinia
3. Create single entry point with BApp
4. Start migrating pages one by one
5. Test as we go

---

**This is a solid, research-backed approach using real-world examples.**
