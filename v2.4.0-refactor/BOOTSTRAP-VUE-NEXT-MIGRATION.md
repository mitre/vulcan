# Bootstrap-Vue to Bootstrap-Vue-Next Migration

**Source:** https://bootstrap-vue.org/vue3
**Source:** https://bootstrap-vue-next.github.io/bootstrap-vue-next/docs/migration-guide.html
**Approach:** Update components, not rewrite them

---

## Key Insight

**NOT THIS:** Rewrite all components to vanilla Bootstrap 5
**THIS:** Update Bootstrap-Vue → Bootstrap-Vue-Next (keeps component API mostly same)

---

## Migration Strategy

### Step 1: Install Bootstrap-Vue-Next
```bash
yarn remove bootstrap-vue
yarn add bootstrap-vue-next
yarn add bootstrap@5
```

### Step 2: Update Imports
**BEFORE:**
```javascript
import { BootstrapVue } from 'bootstrap-vue'
Vue.use(BootstrapVue)
```

**AFTER:**
```javascript
import { createBootstrap } from 'bootstrap-vue-next'
app.use(createBootstrap())
```

### Step 3: Update Component Syntax

**Most Common Changes:**

#### .sync → v-model:
```vue
<!-- BEFORE -->
<BFormCheckbox :indeterminate.sync="indeterminate" />

<!-- AFTER -->
<BFormCheckbox v-model:indeterminate="indeterminate" />
```

#### visible → model-value:
```vue
<!-- BEFORE -->
<BModal :visible="showModal" @hide="showModal = false">

<!-- AFTER -->
<BModal v-model="showModal">
```

#### $bvModal → useModal():
```javascript
// BEFORE
this.$bvModal.show('my-modal')

// AFTER
import { useModal } from 'bootstrap-vue-next'
const { show } = useModal()
show('my-modal')
```

#### $bvToast → useToast():
```javascript
// BEFORE
this.$bvToast.toast('Message', { title: 'Title' })

// AFTER
import { useToast } from 'bootstrap-vue-next'
const { show } = useToast()
show({ props: { body: 'Message', title: 'Title' } })
```

### Step 4: Update Props

**Common prop changes:**
- `sub-title` → `subtitle`
- `visible` → `model-value`
- `right` → `end`
- `drop-up/drop-left/drop-right` → `placement` prop

### Step 5: Update Class Names (Bootstrap 5)
- `.ml-*` / `.mr-*` → `.ms-*` / `.me-*`
- `.pl-*` / `.pr-*` → `.ps-*` / `.pe-*`
- `.float-left` / `.float-right` → `.float-start` / `.float-end`

---

## What Stays the Same

✅ Component names (BButton, BModal, BTable, etc.)
✅ Most props and functionality
✅ Core Bootstrap-Vue API
✅ Grid system (BContainer, BRow, BCol)

---

## Breaking Changes to Handle

### 1. No More Component Aliases
Must use full names:
- `b-btn` → `BButton`
- `b-dd` → `BDropdown`

### 2. HTML Props Removed (Security)
Replace with slots:
```vue
<!-- BEFORE -->
<BCard footer-html="<strong>Footer</strong>" />

<!-- AFTER -->
<BCard>
  <template #footer><strong>Footer</strong></template>
</BCard>
```

### 3. Form Props Changed
- Remove `trim`, `lazy`, `number` props → use native Vue modifiers
- `BFormRow` removed → use grid classes

---

## Estimated Timeline for Vulcan

**Current:** 14 Vue instances, ~50 Vue components

**Realistic estimate:**
- Setup (compat + bootstrap-vue-next): 2-3h
- Update each pack file: 1h × 14 = 14h
- Update shared components: 0.5h × 50 = 25h
- Fix breaking changes: 5-10h
- Testing: 5-8h

**Total: 51-60 hours**

**BUT we can do this incrementally with @vue/compat!**

---

## Incremental Approach (Better)

### Week 1: Setup
- Install @vue/compat + bootstrap-vue-next
- Configure esbuild
- Get ONE page working
- Document pattern

### Week 2-3: Migrate Pages
- Do 2-3 pages per day
- Test each page before moving on
- Fix shared components as needed

### Week 4: Polish
- Remove @vue/compat
- Final testing
- Performance check

**Total: 3-4 weeks, but working app throughout**

---

## Critical Resources

- Vue 3 compat build: https://v3-migration.vuejs.org/migration-build.html
- Bootstrap-Vue-Next docs: https://bootstrap-vue-next.github.io/bootstrap-vue-next/
- Migration guide: https://bootstrap-vue-next.github.io/bootstrap-vue-next/docs/migration-guide.html
