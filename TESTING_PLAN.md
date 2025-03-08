# Webpacker to jsbundling-rails Migration Testing Plan

## Components to Test

Based on our migration progress tracking, we need to focus on testing the following components that are marked with ⚠️:

| Entry Point | Status | Testing Focus |
|-------------|--------|--------------|
| projects | ⚠️ | Vue component mounting, data loading, and interactivity |
| project | ⚠️ | Project details view and associated actions |
| project_component | ⚠️ | Component details and form functionality |
| project_components | ⚠️ | List view and component filtering |
| rules | ⚠️ | Rule display and editing capabilities |
| security_requirements_guides | ⚠️ | SRG listing and selection functionality |
| stig | ⚠️ | STIG details and associated rule display |
| stigs | ⚠️ | STIG listing and filtering |
| users | ⚠️ | User management functionality |
| new_project | ⚠️ | Project creation form and submission |

## Testing Steps

For each component marked with ⚠️, perform the following tests:

1. **Visual Rendering Test**
   - Verify all UI elements appear correctly
   - Confirm proper font loading and icon display
   - Check for CSS/styling issues

2. **Functionality Test**
   - Test all interactive features (buttons, forms, etc.)
   - Verify data loading and state management
   - Test form submission and validation

3. **Console Error Check**
   - Monitor browser console for errors or warnings
   - Note any Vue-related warnings or issues
   - Document any remaining Vue Devtools conflicts

## Browser Compatibility

Test in the following browsers:
- Chrome (with and without Vue Devtools)
- Firefox (with and without Vue Devtools)
- Safari (optional)

## Vue Devtools Conflict Resolution

For the Vue Devtools conflict issue:

1. **Diagnosis**
   - "Another version of Vue Devtools seems to be installed" warning
   - May be caused by conflict between browser extension and built-in devtools

2. **Resolution Options**
   - Test with browser extension disabled
   - Configure Vue.config to handle multiple instances of devtools
   - Add a specific configuration in main application.js entry point

## Documentation Updates

After completing testing, update the following documentation:
- SESSION_RECOVERY.md with final status
- MIGRATION_INVENTORY.md with complete test results
- CLAUDE.md with any new best practices discovered

## Final Verification

Before submitting the pull request:
- Run all automated tests: `bundle exec rails db:create db:schema:load spec`
- Verify all assets build correctly: `yarn build && yarn build:css`
- Run the application in development mode: `yarn dev`
- Confirm all routes function correctly
- Verify proper co-authorship in commit messages

## Co-Authorship Statement

All work on this migration was completed by:
- Aaron Lippold <lippold@gmail.com>
- Claude <noreply@anthropic.com>

This testing plan is to be included in the pull request to master.