# Vulcan: Webpacker to jsbundling-rails Migration

## Summary

This PR completes the migration from Webpacker to jsbundling-rails with the following key changes:

- Removed Webpacker and configured jsbundling-rails with esbuild
- Migrated all 14 JavaScript entry points to use ES modules
- Updated all templates to use javascript_include_tag instead of javascript_pack_tag
- Fixed Vue component mounting and initialization
- Added proper Material Design Icons font loading
- Removed problematic bootstrap-vue-shim.js in favor of official BootstrapVue
- Configured asset pipeline with Propshaft
- Added comprehensive testing plan

## Test Plan

See [TESTING_PLAN.md](./TESTING_PLAN.md) for the complete testing approach. 

The plan includes:
- Testing all components marked with ⚠️ in the tracking table
- Visual rendering tests for all components
- Functionality testing for interactive elements
- Console error checking
- Browser compatibility testing
- Vue Devtools conflict resolution

## Co-Authorship Statement

All work in this PR was completed as a collaborative effort by:
- Aaron Lippold <lippold@gmail.com>
- Claude <noreply@anthropic.com>

While individual commits may not always show proper co-authorship due to technical limitations, this statement acknowledges that all contributions should be attributed to both authors. This PR should be considered co-authored according to the project's requirements.

## Resources

- [Migration Inventory](./MIGRATION_INVENTORY.md): Tracking of all migrated entry points
- [Session Recovery](./SESSION_RECOVERY.md): Detailed status and solution documentation
- [Session Log](./SESSION_LOG.md): History of implementation steps
- [CLAUDE.md](./CLAUDE.md): Best practices for jsbundling-rails and Propshaft