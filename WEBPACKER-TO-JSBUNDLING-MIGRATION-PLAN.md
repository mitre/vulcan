# Webpacker to jsbundling-rails Migration Plan

## Migration Overview

This document outlines our plan for migrating from Webpacker to jsbundling-rails + Propshaft in the Vulcan application. This is the first phase of a larger modernization effort that will later include Ruby/Rails version upgrades and Vue 3 migration.

## Phase 1: Asset Pipeline Migration

### Goals
- Replace Webpacker with jsbundling-rails using esbuild
- Implement Propshaft for non-JS assets
- Maintain current Vue 2.6 and Bootstrap Vue functionality
- Ensure all existing assets compile and work correctly
- Update all templates to use new asset helpers

### Branch Strategy
- Create `upgrade-webpack-to-jsbundling` branch from current `upgrade-rails` branch
- Work incrementally with frequent commits
- Merge back to `upgrade-rails` after completion and testing

## Testing and Validation Plan

### 1. Incremental Testing Approach

- Migrate JS assets in small, logical groups
- Test each group after migration before proceeding
- Keep the Webpacker setup running in parallel until everything is migrated

### 2. Manual Testing

**Development Environment Validation:**
- Verify dev server starts without errors: `bin/dev` (after foreman setup)
- Check browser console for JavaScript errors
- Verify CSS styles load correctly
- Confirm all Vue components render properly
- Test interactive features like forms, modals, and dynamic content

**Visual Regression Testing:**
- Take screenshots of key pages before migration for comparison
- Verify UI looks identical after migration

### 3. Automated Testing

**Vue Component Tests:**
- Update the existing test in `spec/javascript/components/MyComponent.spec.js`
- Ensure it runs with the new build system
- Add more component tests for key UI elements

**Feature Tests:**
- Run `spec/features/vue_integration_spec.rb` to verify Vue integration
- Run `spec/features/project_management_spec.rb` to test UI functionality
- Update Capybara configuration if needed for the new asset pipeline

**Test Commands:**
```bash
# Run feature tests that incorporate Vue components
bundle exec rspec spec/features/vue_integration_spec.rb
bundle exec rspec spec/features/project_management_spec.rb

# Run JS/Vue component tests
yarn test
```

### 4. Build Process Validation

**Asset Compilation:**
- Verify development build: `yarn build`
- Test production asset compilation: `RAILS_ENV=production bin/rails assets:precompile`
- Validate file sizes and structure in `app/assets/builds`

**CI Integration:**
- Update `.github/workflows/run-tests.yml` to use new build commands
- Ensure CI pipeline completes successfully with the new setup

### 5. Systematic Testing Checklist

**Before Each Deploy:**
- [ ] All Vue components render correctly
- [ ] All JavaScript functionality works (modals, forms, etc.)
- [ ] CSS styling is applied properly
- [ ] No JavaScript errors in console
- [ ] Assets compile successfully in production mode
- [ ] All tests pass (Ruby and JavaScript)

### 6. Rollback Plan

**Be Prepared to Rollback:**
- Keep Webpacker configuration files until the migration is complete
- Document exact steps to revert to Webpacker if issues arise
- Create backup commits at key points in the migration

### 7. Post-Migration Validation

**Production Environment Simulation:**
- Test with production asset compilation locally
- Verify all assets are properly fingerprinted
- Check asset sizes and loading performance

**Monitoring Plan:**
- Watch for JavaScript errors after deployment
- Monitor application performance metrics
- Check for increased load times or page size

## Implementation Steps

1. **Preparation and Analysis**
   - [ ] Document current Webpacker configuration and asset structure
   - [ ] Identify all entry points and dependencies
   - [ ] Take screenshots of key UI components for comparison

2. **Remove Webpacker**
   - [ ] Remove Webpacker gem from Gemfile
   - [ ] Remove Webpacker configuration files
   - [ ] Keep JS assets in place for migration

3. **Install jsbundling-rails and Propshaft**
   - [ ] Add gems to Gemfile and bundle
   - [ ] Run installation commands
   - [ ] Configure esbuild for Vue.js support

4. **Migrate JavaScript Assets**
   - [ ] Reorganize entry points
   - [ ] Update import paths
   - [ ] Configure Vue component initialization

5. **Update Templates and Helpers**
   - [ ] Replace Webpacker helpers with new asset helpers
   - [ ] Update asset references in templates

6. **Testing and Validation**
   - [ ] Run all tests and fix issues
   - [ ] Perform manual testing
   - [ ] Update CI configuration

7. **Cleanup and Documentation**
   - [ ] Remove unused Webpacker files
   - [ ] Document new build process
   - [ ] Update developer documentation

## Resources

- [Webpacker to jsbundling Migration Guide](webpacker-to-jsbundling-migration-guide.md)
- [Rails Asset Pipeline Guide](https://guides.rubyonrails.org/asset_pipeline.html)
- [jsbundling-rails Documentation](https://github.com/rails/jsbundling-rails)
- [Propshaft Documentation](https://github.com/rails/propshaft)