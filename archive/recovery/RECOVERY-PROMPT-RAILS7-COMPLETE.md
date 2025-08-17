# Recovery Prompt - Vulcan Rails 7 + Ruby 3.1 + jsbundling Complete Upgrade
## Date: January 12, 2025
## Context Level at Compact: 5%

### CRITICAL: First Actions After Compact
1. **READ /Users/alippold/.claude/CLAUDE.md** - User's global preferences and rules (NO HACKS, proper fixes only)
2. **READ /Users/alippold/github/mitre/vulcan/CLAUDE.md** - Vulcan project-specific context
3. **READ this file completely** before taking any actions
4. **CHECK MCP memory**: `mcp__server-memory__open_nodes` with name "Vulcan Rails 7 Upgrade"
5. **CHECK TODO list** to see current progress

### Current Working Directory
`/Users/alippold/github/mitre/vulcan`

### Current Git Status
- **Branch**: upgrade-settingslogic-ruby31
- **Status**: Uncommitted changes from Rails 7 + jsbundling migration
- **Major Changes Complete**: Rails 6.1→7.0, Ruby 2.7.5→3.1.6, Webpacker→jsbundling-rails

### What We Successfully Completed
1. **Rails Upgrade**: 6.1.4 → 7.0.8.7
2. **Ruby Upgrade**: 2.7.5 → 3.1.6
3. **Settingslogic Fix**: Replaced with mitre-settingslogic 3.0.3 for Psych 4 compatibility
4. **Asset Pipeline Migration**: Webpacker → jsbundling-rails with esbuild
5. **Vue 2 Component Fixes**:
   - Changed esbuild format from ESM to IIFE
   - Removed `type: 'module'` from all script tags
   - Fixed HAML boolean attribute syntax issues
6. **Ruby 3.1 Compatibility**:
   - Added `gem 'rexml'` to Gemfile
   - Fixed DisaRuleDescription model with `require 'rexml/document'`
7. **Asset Organization**:
   - Moved images to app/assets/images/ for Propshaft
   - Created proper esbuild.config.js with Vue plugin
   - Bootstrap Vue CSS working through SCSS imports

### Current State
- **Database**: Seeding in progress when we compacted
- **Server**: Working with `foreman start -f Procfile.dev`
- **Assets**: Building correctly with `yarn build`
- **Login**: User alippold@mitre.org exists with password: password
- **UI**: Headers and footers displaying correctly after fixes

### Key Technical Details
```ruby
# Gemfile key additions
gem 'rails', '~> 7.0.0'
gem 'concurrent-ruby', '1.3.4'  # Pinned for Rails 7.0 Logger bug
gem 'mitre-settingslogic', '~> 3.0'
gem 'jsbundling-rails'
gem 'propshaft'
gem 'rexml'  # Required for Ruby 3.0+
gem 'audited', '~> 5.8.0'
```

```javascript
// esbuild.config.js key settings
format: 'iife',  // IIFE format for Vue 2 browser compatibility
entryPoints: {
  'application': 'app/javascript/packs/application.js',
  'bootstrap-vue': 'app/javascript/bootstrap-vue.scss',
  // ... other entry points
}
```

### Files Modified (Key ones)
- `Gemfile` & `Gemfile.lock` - All gem updates
- `config/application.rb` - config.load_defaults set to 7.0
- `config/initializers/audited.rb` - String class name 'VulcanAudit'
- `app/views/layouts/application.html.haml` - Fixed v-bind syntax
- `app/views/**/*.haml` - Changed pack_tag to include_tag
- `esbuild.config.js` - New build configuration
- `package.json` - Updated with esbuild dependencies
- `Procfile.dev` - Changed to use yarn build:watch
- `.nvmrc` - Updated to Node 20
- `app/models/disa_rule_description.rb` - Added REXML require

### Immediate Next Steps
1. **Verify database seeding completed**:
   ```bash
   bundle exec rails runner "puts 'Projects: #{Project.count}, Components: #{Component.count}'"
   ```

2. **Run ActiveStorage migrations**:
   ```bash
   bundle exec rails db:migrate
   ```

3. **Test application**:
   - Login at http://localhost:3000 with alippold@mitre.org / password
   - Verify all pages load with headers/footers
   - Check Vue components are interactive

4. **Commit everything**:
   ```bash
   git add -A
   git commit -m "Upgrade to Rails 7.0 + Ruby 3.1.6 + jsbundling-rails

   - Upgrade Rails from 6.1.4 to 7.0.8.7
   - Upgrade Ruby from 2.7.5 to 3.1.6
   - Replace settingslogic with mitre-settingslogic 3.0.3
   - Migrate from Webpacker to jsbundling-rails with esbuild
   - Fix Vue 2 components with IIFE format
   - Add REXML gem for Ruby 3.0+ compatibility
   - Update all view helpers and configurations

   Authored by: Aaron Lippold<lippold@gmail.com>"
   ```

5. **Push and create PR**:
   ```bash
   git push origin upgrade-settingslogic-ruby31
   gh pr create --title "Upgrade to Rails 7.0 + Ruby 3.1 + jsbundling" \
                --body "Major upgrade including Rails, Ruby, and asset pipeline migration"
   ```

### Known Issues & Solutions
- **Vue components not mounting**: Use IIFE format, not ESM
- **Boolean attributes as strings**: Use v-bind with string "true"/"false"
- **REXML missing**: Add gem 'rexml' to Gemfile
- **Assets not found**: Move to app/assets/images/, not public/
- **Headers/footers missing**: Check esbuild format and script tag types

### Other Available Branch
- **origin/upgrade-webpack-to-jsbundling**: Has cleaner JS structure but uses old Ruby/settingslogic

### REMEMBER
- User HATES workarounds - wants proper fixes only
- No Claude signatures in commits
- Fix root causes, not symptoms
- Rails 7.0 needs concurrent-ruby 1.3.4 (not 1.3.5)
- Audited gem needs string class name with Zeitwerk