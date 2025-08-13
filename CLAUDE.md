# Vulcan Development Guide

## Version Requirements
- **Ruby**: 3.3.6 (specified in `.ruby-version`)
- **Node.js**: 20.x (specified in `.nvmrc`, matches production Dockerfile)
- **PostgreSQL**: 12 (from docker-compose.dev.yml)
- **Rails**: 7.0.8.7 (from Gemfile.lock)

These versions are enforced by:
- `.ruby-version` - RVM/rbenv will auto-switch
- `.nvmrc` - NVM will auto-switch (with proper shell setup)
- `bin/dev-setup` - Checks and switches both Ruby and Node versions

Note: When using Node.js 17+, webpack-dev-server requires the `NODE_OPTIONS=--openssl-legacy-provider` flag

## Reference Documentation

### Modernization & Migration Planning ✅
- **Vulcan-Modernization-Roadmap.md**: Phased plan for upgrades with milestones and decision points
- **VULCAN-WORKSTREAM-PLAN.md**: Structured plan for breaking scope creep into manageable PRs
- **webpacker-to-jsbundling-migration-guide.md**: Practical guide for migrating from Webpacker
- **MIGRATION_INVENTORY.md**: Inventory of JavaScript pack tags that need migration
- **docs/webpacker-to-jsbundling-analysis.md**: Technical analysis of current Webpacker setup

### GitHub Issues - Research & Planning
- **Issue #670**: [Heroku-20 Stack EOL + Webpacker Compatibility](https://github.com/mitre/vulcan/issues/670) - Comprehensive research and analysis
- **Issue #382**: [Switch from webpacker to jsbundling-rails](https://github.com/mitre/vulcan/issues/382) - Original migration tracking
- **Issue #667**: [Implement OIDC auto-discovery](https://github.com/mitre/vulcan/issues/667) - OIDC modernization (completed)

### Future Documentation (Planned)
- **Vulcan-System-Overview.md**: Comprehensive description of Vulcan's purpose, features, and architecture  
- **Vulcan-Design-Decisions.md**: Technical decisions and options for the modernization project

## Project Policies

### Git Commit Standards
- All commits MUST be co-authored by Aaron Lippold <lippold@gmail.com>
- Commits should include proper signing 
- Format for co-authorship:
  ```
  Co-Authored-By: Aaron Lippold <lippold@gmail.com>
  ```
- Existing commits without proper co-authorship must be amended before merging

## Development Setup
- Full setup: `./bin/dev-setup` (includes Docker, database, seeds)
- With Okta: `./bin/dev-setup --okta`
- Clean restart: `./bin/dev-setup --clean --refresh`
- Simple Rails setup: `bin/setup` (no Docker)

## Build & Test Commands
- Start development servers: `foreman start -f Procfile.dev`
- Or separately:
  - Rails: `bundle exec rails s`
  - Webpack: `./bin/webpack-dev-server` (Node 16) or `NODE_OPTIONS=--openssl-legacy-provider ./bin/webpack-dev-server` (Node 17+)
- Run all tests: `bundle exec rspec`
- Run single test: `bundle exec rspec path/to/spec_file.rb:line_number`
- Run specific file: `bundle exec rspec path/to/spec_file.rb`
- Run Ruby linting: `bundle exec rubocop`
- Run JS linting: `yarn lint`

## Search Tools
- Use `rg` (ripgrep) for fast code searching: `rg "pattern" path/`
- Common rg flags:
  - `-A 5 -B 5`: Show 5 lines before and after matches
  - `-l`: List only filenames with matches
  - `-c`: Count matches per file
  - `-i`: Case-insensitive search

## CI/CD and GitHub CLI
- Use `gh` CLI for checking CI/CD logs and workflow status
- List recent runs: `gh run list --branch branch-name --limit 5`
- View failed logs: `gh run view <run-id> --log-failed | grep -B 10 -A 10 "failed\|Failed"`
- View workflow configuration: `gh workflow view workflow-name --yaml`
- Check PR status: `gh pr view <pr-number>`
- View PR checks: `gh pr checks <pr-number>`

## External API Access
- Always use `env curl` instead of `curl` for accessing external APIs
- Example: `env curl -s https://cyber.trackr.live/api`
- This bypasses the curl command restriction in Claude Code

## Asset System Best Practices

### Working with jsbundling-rails and Propshaft

1. **Trust the Asset Pipeline**: Let jsbundling-rails and Propshaft handle asset paths and compilation. Avoid manually setting paths or trying to override the built-in behavior.

2. **CSS Assets Strategy**:
   - Use stylesheet_link_tag in layouts to load CSS files from app/assets/stylesheets/
   - For third-party CSS that needs to be included directly, import it in application.scss
   - Let Sass handle imports of Bootstrap and other frameworks

3. **Icon System - Bootstrap Icons**:
   - Use Bootstrap Icons via the BootstrapVue IconsPlugin
   - Enable the plugin in your entry points:
     ```javascript
     import { BootstrapVue, IconsPlugin } from 'bootstrap-vue'
     Vue.use(BootstrapVue)
     Vue.use(IconsPlugin)
     ```
   - Use in templates with the b-icon component:
     ```html
     <b-icon icon="house" />
     ```
   - Standard asset naming in esbuild.config.js:
     ```javascript
     assetNames: '[name]-[hash].[ext]'
     ```
   - Set `publicPath: '/assets'` in esbuild.config.js to ensure proper URL resolution

4. **Font System - Bootstrap Native Font Stack**:
   - Use Bootstrap's built-in native font stack
   - No custom web fonts are loaded - leverages system fonts for optimal performance
   - The font stack is defined in Bootstrap's variables.scss:
     ```scss
     $font-family-sans-serif: system-ui, -apple-system, "Segoe UI", Roboto, "Helvetica Neue", 
       Arial, "Noto Sans", "Liberation Sans", sans-serif, "Apple Color Emoji", 
       "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji";
     ```
   - Access in custom CSS using Bootstrap's CSS variables:
     ```css
     font-family: var(--font-family-sans-serif);
     ```
   - Don't load additional web fonts unless absolutely necessary

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

### Component Adaptation Patterns
When adapting components for similar but different data structures (like SRG/STIG):
- Extend the base component with a new adapter component
- Add error handling for missing or null properties
- Create placeholder data for required fields when empty
- Add extensive null checks with optional chaining (?.)
- Override methods that access specific data structures
- Implement comprehensive logging for debugging
- Use try/catch blocks to avoid crashing on data errors

### Testing
- Group tests with describe/context/it blocks
- Use Factory Bot for test data
- Test validations, associations, and methods separately