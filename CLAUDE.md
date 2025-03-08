# Vulcan Development Guide

## Reference Documentation
- **Vulcan-System-Overview.md**: Comprehensive description of Vulcan's purpose, features, and architecture
- **Vulcan-Modernization-Roadmap.md**: Phased plan for upgrades with milestones and decision points
- **Vulcan-Design-Decisions.md**: Technical decisions and options for the modernization project
- **MIGRATION_INVENTORY.md**: Inventory of JavaScript pack tags that need migration
- **webpacker-to-jsbundling-migration-guide.md**: Practical guide for migrating from Webpacker

## Project Policies

### Git Commit Standards
- All commits MUST be co-authored by Aaron Lippold <lippold@gmail.com>
- Commits should include proper signing 
- Format for co-authorship:
  ```
  Co-Authored-By: Aaron Lippold <lippold@gmail.com>
  Co-Authored-By: Claude <noreply@anthropic.com>
  ```
- Existing commits without proper co-authorship must be amended before merging

## Build & Test Commands
- Run development server with hot-reloading: `yarn dev`
- Run server only (no asset compilation): `bundle exec rails s`
- Build assets once: `yarn build && yarn build:css`
- Watch and rebuild assets: `yarn build:watch`
- Run all tests: `bundle exec rails db:create db:schema:load spec`
- Run single test: `bundle exec rspec path/to/spec_file.rb:line_number`
- Run specific file: `bundle exec rspec path/to/spec_file.rb`
- Run JS tests: `yarn test`
- Run Ruby linting: `bundle exec rubocop`
- Run JS linting: `yarn lint`

## Asset System Best Practices

### Working with jsbundling-rails and Propshaft

1. **Trust the Asset Pipeline**: Let jsbundling-rails and Propshaft handle asset paths and compilation. Avoid manually setting paths or trying to override the built-in behavior.

2. **CSS Assets Strategy**:
   - Use stylesheet_link_tag in layouts to load CSS files from app/assets/stylesheets/
   - For third-party CSS that needs to be included directly, import it in application.scss
   - Let Sass handle imports of Bootstrap and other frameworks

3. **Material Design Icons and Font Handling**:
   - Store fonts in app/assets/fonts/
   - Reference them through the asset pipeline with stylesheet_link_tag
   - For libraries like MDI, use the precompiled CSS from app/assets/stylesheets/mdi/
   - CRITICAL: Always use `assetNames: 'materialdesignicons-webfont.[ext]'` in esbuild.config.js  
   - MDI CSS expects font files at exact path /assets/materialdesignicons-webfont.[ext]
   - The CSS already has correct /assets/ prefix in font URLs
   - Include MDI CSS with `stylesheet_link_tag 'mdi/materialdesignicons.min'`
   - NEVER change this pattern or manually copy font files around
   - Set `publicPath: '/assets'` in esbuild.config.js to ensure proper URL resolution

4. **JavaScript Module Loading**:
   - Use ESM format with `type: 'module'` in javascript_include_tag
   - Prefer global component registration for Vue components
   - Make sure all import paths are correct in JavaScript files
   
5. **Vue Component Initialization Pattern**:
   ```javascript
   // Most reliable Vue initialization pattern for Turbolinks
   const initComponent = () => {
     const el = document.getElementById('ComponentContainer')
     if (el) {
       new Vue({
         el: '#ComponentContainer',
         render: h => h(ComponentName)
       })
     }
   }
   
   // Try both event hooks for maximum compatibility
   document.addEventListener('turbolinks:load', initComponent)
   document.addEventListener('DOMContentLoaded', initComponent)
   ```

6. **Common Pitfalls**:
   - Don't try to manually fix font paths in CSS files
   - Avoid custom asset naming schemes that conflict with how Propshaft serves files
   - Remember that CSS processing and JavaScript bundling are separate processes
   - When in doubt, check the generated files in app/assets/builds/

## Code Style Guidelines
### Ruby
- Use snake_case for variables and methods
- Use CamelCase for classes
- Prefix boolean methods with verbs (can_?, is_?)
- Use custom error classes in app/errors/
- Place `frozen_string_literal: true` at the top of files

### JavaScript/Vue
- Use PascalCase for component names and files
- Use camelCase for variables and methods
- Define props with types and required status
- Use Single File Component format (.vue)
- Scope component styles with scoped attribute

### Testing
- Group tests with describe/context/it blocks
- Use Factory Bot for test data
- Test validations, associations, and methods separately