# Vue 3 Migration Workflow (Using @vue/compat)

**Source:** https://v3-migration.vuejs.org/migration-build.html#upgrade-workflow
**Approach:** Gradual migration using compatibility build

---

## The @vue/compat Strategy

**What it is:** A special build of Vue 3 that runs in Vue 2 compatibility mode
**Purpose:** Migrate gradually, fix warnings one by one
**Timeline:** Typically faster than big-bang rewrite

---

## Step-by-Step Workflow

### 1. Preparations
- Update any deprecated named/scoped slot syntax to Vue 2.6+ format

### 2. Update Build Tools
**Webpack:**
```bash
yarn upgrade vue-loader@^16.0.0
```

**Vue CLI:**
```bash
vue upgrade
# Updates @vue/cli-service to latest
```

**OR migrate to Vite:**
```bash
yarn add vite vite-plugin-vue2
```

### 3. Install @vue/compat
```bash
yarn remove vue vue-template-compiler
yarn add vue@3 @vue/compat
yarn add -D @vue/compiler-sfc
```

### 4. Configure Build Tool

**For esbuild (Vulcan uses this):**
```javascript
// esbuild.config.js
const esbuild = require('esbuild')
const vue = require('esbuild-plugin-vue3')

esbuild.build({
  // ... existing config
  plugins: [
    vue({
      compilerOptions: {
        compatConfig: {
          MODE: 2 // Vue 2 compatibility mode
        }
      }
    })
  ],
  alias: {
    vue: '@vue/compat'
  },
  define: {
    __VUE_OPTIONS_API__: 'true',
    __VUE_PROD_DEVTOOLS__: 'false',
    __VUE_PROD_HYDRATION_MISMATCH_DETAILS__: 'false'
  }
})
```

### 5. Fix Compiler Warnings
- Run build, look for compile-time errors
- Fix template syntax issues
- Once compiler warnings gone, proceed

### 6. Boot App, Address Runtime Warnings
```javascript
// In browser console, you'll see deprecation warnings:
[Vue warn]: GLOBAL_MOUNT: Vue detected as global on window...
[Vue warn]: INSTANCE_LISTENERS: $listeners has been merged into $attrs...
```

**Strategy:**
- Filter console by component/feature
- Fix warnings one by one
- Use per-component compatConfig if needed

### 7. Configure Compatibility Per Component
```javascript
// Fix app-wide
import { configureCompat } from 'vue'

configureCompat({
  GLOBAL_MOUNT: false,
  INSTANCE_LISTENERS: false
})

// OR fix per-component
export default {
  compatConfig: {
    MODE: 3, // Vue 3 mode for this component
    INSTANCE_LISTENERS: true // Keep Vue 2 behavior for this one feature
  }
}
```

### 8. Migrate Global API
**Update main entry point:**
```javascript
// BEFORE (Vue 2)
import Vue from 'vue'
new Vue({ ... }).$mount('#app')

// AFTER (Vue 3)
import { createApp } from 'vue'
createApp({ ... }).mount('#app')
```

### 9. Update Dependencies
- Upgrade Vuex to v4 (if used)
- Upgrade vue-router to v4 (if used)

### 10. Remove @vue/compat
Once all warnings resolved:
```bash
yarn remove @vue/compat
yarn add vue@3
```

Remove alias from build config.

---

## For Vulcan (14 Separate Vue Instances)

**Each pack file needs:**
1. Update from `new Vue()` to `createApp()`
2. Fix any deprecation warnings
3. Test that page works

**Estimate:** 1-2 hours per page = 14-28 hours total

**BUT with @vue/compat:** Can migrate one page at a time while others still work

---

## Timeline

- **Day 1:** Setup @vue/compat, configure esbuild (2-3h)
- **Days 2-4:** Migrate 14 pages one by one (14-20h)
- **Day 5:** Remove @vue/compat, final testing (3-4h)

**Total: 19-27 hours** (more realistic than 30-40h)
