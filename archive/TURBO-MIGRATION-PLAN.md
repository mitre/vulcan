# Turbolinks to Turbo Migration Plan

## 🔍 Current State Analysis

### Dependencies
- **Vue**: 2.6.11 (using vue-turbolinks adapter)
- **Bootstrap**: 4.4.1 with Bootstrap-Vue 2.13.0
- **Turbolinks**: 5.2.0 (gem and npm package)
- **Rails UJS**: 7.1.3-4 (still in use)
- **13 Vue components** using TurbolinksAdapter

### Key Challenges Identified

1. **Vue Component Lifecycle**
   - Currently using `vue-turbolinks` to handle component teardown/remounting
   - All Vue apps mount on `turbolinks:load` event
   - Need to ensure proper cleanup on navigation to prevent memory leaks

2. **Bootstrap-Vue Compatibility**
   - Bootstrap-Vue 2.x is tightly coupled with Vue 2
   - No known conflicts with Turbo Drive itself
   - Modal/tooltip/popover components may need special handling

3. **Event Naming Changes**
   - `turbolinks:load` → `turbo:load`
   - `turbolinks:before-cache` → `turbo:before-cache`
   - `turbolinks:before-render` → `turbo:before-render`
   - `turbolinks:click` → `turbo:click`
   - `turbolinks:request-start` → `turbo:submit-start`
   - `turbolinks:request-end` → `turbo:submit-end`

4. **Data Attributes**
   - `data-turbolinks-track` → `data-turbo-track`
   - `data-turbolinks-permanent` → `data-turbo-permanent`
   - `data-turbolinks-action` → `data-turbo-action`
   - `data-turbolinks="false"` → `data-turbo="false"`

## 📋 Migration Strategy

### Phase 1: Setup & Compatibility Layer (2-3 hours)

1. **Update Gemfile**
   ```ruby
   # Remove
   gem 'turbolinks', '~> 5'
   
   # Add
   gem 'turbo-rails', '~> 2.0'
   ```

2. **Create Vue-Turbo Adapter**
   - Replace `vue-turbolinks` with custom adapter
   - Handle component cleanup on `turbo:before-cache`
   - Remount components on `turbo:load`

3. **Add Compatibility Shim (temporary)**
   ```javascript
   // Temporary shim for gradual migration
   window.Turbolinks = window.Turbo;
   document.addEventListener('turbo:load', () => {
     const event = new CustomEvent('turbolinks:load', { bubbles: true });
     document.dispatchEvent(event);
   });
   ```

### Phase 2: JavaScript Migration (3-4 hours)

1. **Update package.json**
   ```json
   // Remove
   "turbolinks": "^5.2.0",
   "vue-turbolinks": "^2.1.0"
   
   // Add
   "@hotwired/turbo": "^8.0.0"
   ```

2. **Create New Vue Adapter** (`app/javascript/utils/vue-turbo-adapter.js`)
   ```javascript
   export default {
     install(Vue) {
       let instances = [];
       
       // Store Vue instances for cleanup
       Vue.mixin({
         beforeMount() {
           instances.push(this);
         }
       });
       
       // Clean up before cache
       document.addEventListener('turbo:before-cache', () => {
         instances.forEach(instance => {
           instance.$destroy();
         });
         instances = [];
       });
       
       // Handle form submissions
       document.addEventListener('turbo:submit-end', (event) => {
         if (!event.detail.success) return;
         // Re-initialize Vue apps if needed
       });
     }
   };
   ```

3. **Update All Vue Pack Files** (13 files)
   ```javascript
   // Before
   import TurbolinksAdapter from "vue-turbolinks";
   document.addEventListener("turbolinks:load", () => {
   
   // After
   import VueTurboAdapter from "../utils/vue-turbo-adapter";
   document.addEventListener("turbo:load", () => {
   ```

### Phase 3: Rails Views & Controllers (2-3 hours)

1. **Update Application Layout**
   - Change `data-turbolinks-track` to `data-turbo-track`
   - Update meta tags if any reference turbolinks

2. **Search and Replace in Views**
   ```bash
   # Find all turbolinks references
   grep -r "turbolinks" app/views/
   
   # Update data attributes
   data: { turbolinks: false } → data: { turbo: false }
   ```

3. **Controller Updates**
   - Remove any Turbolinks-specific redirects
   - Ensure Turbo Drive handles form errors properly

### Phase 4: Testing & Validation (3-4 hours)

1. **Component Testing Checklist**
   - [ ] Projects page - Vue components load
   - [ ] Components page - Bootstrap-Vue tables work
   - [ ] STIGs page - File uploads via Turbo
   - [ ] Rules editor - Monaco editor initializes
   - [ ] Navigation - No memory leaks
   - [ ] Forms - Error handling works
   - [ ] Modals - Bootstrap modals function

2. **Memory Leak Testing**
   - Navigate between pages multiple times
   - Check browser DevTools for detached DOM nodes
   - Verify Vue components properly cleanup

3. **Performance Testing**
   - Page navigation speed
   - Form submission response
   - Asset loading with turbo:track

### Phase 5: Cleanup (1 hour)

1. Remove compatibility shim
2. Remove old Turbolinks references
3. Update documentation
4. Clean up any deprecated code

## ⚠️ Risk Mitigation

### High-Risk Areas

1. **Vue Component Memory Leaks**
   - Risk: Components not properly destroyed
   - Mitigation: Implement robust cleanup in adapter
   - Testing: Use Chrome Memory Profiler

2. **Bootstrap Modals/Tooltips**
   - Risk: May not work after navigation
   - Mitigation: Re-initialize on turbo:load
   - Testing: Manual testing of all modals

3. **File Uploads**
   - Risk: STIG upload forms may break
   - Mitigation: Test thoroughly, may need turbo:false
   - Testing: Upload various file types

### Rollback Plan

1. Keep branch separate until fully tested
2. Document all changes for easy revert
3. Test in staging environment first
4. Have Turbolinks branch ready as backup

## 📊 Effort Estimate

- **Total Estimated Time**: 11-15 hours
- **Complexity**: Medium-High
- **Risk Level**: Medium

## 🔗 Key Resources

1. [Official Turbo Rails Upgrade Guide](https://github.com/hotwired/turbo-rails/blob/main/UPGRADING.md)
2. [Honeybadger Migration Guide](https://www.honeybadger.io/blog/hb-turbolinks-to-turbo/)
3. [GoRails Upgrade Tutorial](https://gorails.com/episodes/upgrade-from-turbolinks-to-hotwire-and-turbo)
4. [Turbo Handbook](https://turbo.hotwired.dev/handbook/introduction)

## 📝 Implementation Notes

### Vue-Specific Considerations

1. **Component State Preservation**
   - Consider using `data-turbo-permanent` for stateful components
   - May need to store state in sessionStorage for complex forms

2. **Event Handling**
   - Vue event listeners should be properly cleaned up
   - Global event bus may need special handling

3. **Routing Conflicts**
   - Turbo Drive handles navigation
   - Vue components should not use vue-router

### Bootstrap-Vue Considerations

1. **Dynamic Components**
   - Modals, tooltips, popovers need re-initialization
   - Consider creating a Bootstrap reinitializer

2. **Form Validation**
   - Bootstrap-Vue form validation should work unchanged
   - Test with Turbo form submissions

## ✅ Success Criteria

1. All 190 tests passing
2. No JavaScript console errors
3. All Vue components functional
4. No memory leaks detected
5. Page navigation feels smooth
6. Form submissions work correctly
7. File uploads functional
8. No visual regressions

## 🚀 Next Steps

1. Review plan with team
2. Create feature branch
3. Start with Phase 1 (Setup)
4. Implement custom Vue-Turbo adapter
5. Test incrementally
6. Deploy to staging for UAT