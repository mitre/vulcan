# Bootstrap 5 Migration Plan for Vulcan

## Current State
- **Bootstrap**: 4.4.1
- **Bootstrap-Vue**: 2.13.0 (Bootstrap 4 + Vue 2)
- **Bootstrap Icons**: 1.13.1
- **Vue**: 2.x
- **Rails**: 8.0.2.1 ✅ (just upgraded)
- **Asset Pipeline**: jsbundling-rails + esbuild

## Key Challenges

### 1. Bootstrap-Vue Incompatibility
Bootstrap-Vue 2.x only supports Bootstrap 4 and Vue 2. For Bootstrap 5, we need to either:
- Migrate to **BootstrapVueNext** (Bootstrap 5 + Vue 3)
- Use plain Bootstrap 5 without Vue components
- Find alternative Vue component libraries

### 2. Breaking Changes in Bootstrap 5
- **jQuery removed** - Bootstrap 5 doesn't require jQuery
- **Utility classes renamed**:
  - `ml-*` → `ms-*` (margin-left → margin-start)
  - `mr-*` → `me-*` (margin-right → margin-end)
  - `pl-*` → `ps-*` (padding-left → padding-start)
  - `pr-*` → `pe-*` (padding-right → padding-end)
- **Form controls**: New floating labels, updated validation styles
- **Modal/Dropdown API**: Changed data attributes (`data-bs-*` prefix)

### 3. Vue 2 → Vue 3 Migration (if upgrading to BootstrapVueNext)
- Composition API
- Different reactivity system
- Changed lifecycle hooks
- New template directives

## Migration Options

### Option 1: Incremental Migration (Recommended)
1. **Phase 1**: Upgrade Bootstrap CSS only
   - Update from Bootstrap 4.4.1 to 5.3.x
   - Fix utility class changes
   - Keep Bootstrap-Vue components (they'll still work with BS4 classes)

2. **Phase 2**: Replace Bootstrap-Vue components gradually
   - Start with simple components (buttons, alerts)
   - Move to complex ones (modals, dropdowns)
   - Use native Bootstrap 5 JavaScript or Vue 3 alternatives

3. **Phase 3**: Vue 3 migration (future)
   - Upgrade Vue 2 → Vue 3
   - Migrate to BootstrapVueNext or alternative

### Option 2: Full Migration
- Upgrade Bootstrap, Vue, and all components at once
- Higher risk but cleaner end result
- Requires significant testing

## Reference Projects

### Rails 8 + Bootstrap 5 Examples
1. **Rails 8 Authentication** (Most relevant)
   - https://github.com/dangkhoa2016/Rails-8-Authentication
   - Rails 8.0.2 + Bootstrap 5.3.3 + Devise
   - Uses cssbundling-rails + Sass
   - No Vue (uses Hotwire)

2. **Twitter Bootstrap Rails**
   - https://github.com/seyhunak/twitter-bootstrap-rails
   - Updated for Rails 8
   - Gem-based approach

3. **Bootstrap Form Gem**
   - https://github.com/bootstrap-ruby/bootstrap_form
   - Official Bootstrap 5 form builder for Rails

### Vue + Bootstrap 5 Options
1. **BootstrapVueNext**
   - https://bootstrap-vue-next.github.io/
   - Bootstrap 5 + Vue 3
   - Similar API to Bootstrap-Vue

2. **PrimeVue**
   - Modern Vue 3 component library
   - Built-in Bootstrap 5 theme support

## Implementation Steps

### Step 1: Audit Current Usage
```bash
# Find all Bootstrap utility classes
grep -r "ml-\|mr-\|pl-\|pr-" app/javascript/components/
grep -r "data-toggle\|data-dismiss" app/javascript/components/

# Find Bootstrap-Vue components
grep -r "<b-" app/javascript/components/ | cut -d: -f2 | sed 's/.*<\(b-[a-z-]*\).*/\1/' | sort -u
```

### Step 2: Update Dependencies
```json
// package.json
{
  "dependencies": {
    "bootstrap": "^5.3.3",
    "bootstrap-icons": "^1.11.3",
    "@popperjs/core": "^2.11.8"
  }
}
```

### Step 3: Update SCSS
```scss
// app/javascript/application.scss
@import "bootstrap/scss/bootstrap";
// Remove jQuery-dependent customizations
```

### Step 4: Fix Utility Classes
```javascript
// Create migration script
const replacements = {
  'ml-': 'ms-',
  'mr-': 'me-',
  'pl-': 'ps-',
  'pr-': 'pe-',
  'data-toggle': 'data-bs-toggle',
  'data-dismiss': 'data-bs-dismiss'
};
```

### Step 5: Test Critical Features
- [ ] Authentication (Devise)
- [ ] Component editing
- [ ] Rule management
- [ ] STIG viewing
- [ ] Project management

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Bootstrap-Vue components break | High | Keep BS4 classes temporarily |
| Custom styles break | Medium | Audit and update SCSS |
| JavaScript plugins fail | Medium | Use BS5 native or alternatives |
| Vue reactivity issues | Low | Stay on Vue 2 initially |

## Timeline Estimate
- **Phase 1**: 1-2 sprints (Bootstrap CSS only)
- **Phase 2**: 3-4 sprints (Component replacement)
- **Phase 3**: 4-6 sprints (Vue 3 migration - future)

## Next Steps
1. Create feature branch from `rails-8-upgrade`
2. Install Bootstrap 5 alongside Bootstrap 4
3. Create test pages with BS5 styles
4. Gradually migrate components
5. Remove Bootstrap 4 when complete