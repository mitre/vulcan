# Vulcan Webpacker to jsbundling-rails Migration - Session Recovery

## Current Status

We have successfully completed the initial phase of migrating from Webpacker to jsbundling-rails:

1. ✅ Created a new branch `upgrade-webpack-to-jsbundling` from the `upgrade-rails` branch
2. ✅ Added jsbundling-rails and propshaft gems to replace Webpacker
3. ✅ Set up esbuild as the JavaScript bundler
4. ✅ Created a basic working build setup with simplified components
5. ✅ Modified the application layout to use the new asset helpers
6. ✅ Set up build scripts and watch mode for development
7. ✅ Can successfully login to the application with admin@example.com / 1234567ab!

## Current Challenges

1. We're seeing errors related to missing `javascript_pack_tag` in various view templates:
   - `app/views/projects/index.html.haml` still uses `javascript_pack_tag 'projects'`
   - Other templates likely have the same issue

2. Vue components need to be fully migrated:
   - We've created temporary shims for Bootstrap Vue components
   - We need to properly implement or migrate all required components

## Next Steps

1. Create a migration mapping for all remaining JavaScript entry points:
   - Identify all templates using `javascript_pack_tag` 
   - Create corresponding entry points in `app/javascript/`
   - Update esbuild.config.js to include all entry points

2. Update all templates:
   - Replace `javascript_pack_tag` with `javascript_include_tag`
   - Update all asset paths and references

3. Migrate Vue components:
   - Move components from Webpacker structure to new structure
   - Update import paths in components
   - Update component initialization

4. Fix styling:
   - Properly import Bootstrap and Bootstrap Vue styles
   - Handle Material Design Icons

5. Comprehensive testing:
   - Test all functionality after migration
   - Fix any issues that arise
   - Ensure all tests pass

## Migration Progress Tracking

| Entry Point | Migrated | Template Updated | Tested |
|-------------|----------|------------------|--------|
| application | ✅       | ✅               | ✅     |
| login       | ✅       | ✅               | ✅     |
| navbar      | ✅       | ✅               | ✅     |
| toaster     | ✅       | ✅               | ✅     |
| projects    | ❌       | ❌               | ❌     |
| project     | ❌       | ❌               | ❌     |
| project_component | ❌ | ❌               | ❌     |
| project_components | ❌ | ❌               | ❌     |
| rules       | ❌       | ❌               | ❌     |
| security_requirements_guides | ❌ | ❌     | ❌     |
| stig        | ❌       | ❌               | ❌     |
| stigs       | ❌       | ❌               | ❌     |
| users       | ❌       | ❌               | ❌     |

## Resources and Configuration

- Docker PostgreSQL is running for development
- Login credentials: admin@example.com / 1234567ab!
- Dev server command: `yarn dev`
- Build command: `yarn build && yarn build:css`