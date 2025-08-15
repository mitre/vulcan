# Vulcan Modernization Deep Dive Session
## Date: January 9, 2025
## Focus: Ruby/Rails Upgrade Path Investigation

### Session Context
Working with Aaron Lippold to modernize the Vulcan security compliance application from its current legacy state to modern supported versions. Solo developer, no deployment pressure, can release when complete.

### Current State (As of Jan 9, 2025)
- **Ruby**: 2.7.5 (EOL March 2023)
- **Rails**: 6.1.4 (EOL October 2024)
- **Node**: 16 (EOL September 2023)
- **Vue**: 2.7 with Webpacker 5
- **Bootstrap**: 4.6
- **Database**: PostgreSQL 12

### Key Discovery: Settingslogic Not a Real Blocker!
**Investigation Date**: Jan 9, 2025

Previously thought `settingslogic` gem blocked Ruby 3 upgrade. Research revealed:
- Gem itself has NO Ruby version constraints
- Issue is with Psych 4 (YAML parser) in Ruby 3.1+, not Ruby itself
- Simple fix available (YAML.load needs `aliases: true` parameter)

**Fix Options**:
1. **Quick Fork** (5 min): `gem 'settingslogic', github: 'minorun99/settingslogic'`
2. **Vendor & Patch** (10 min): Copy to vendor/, add `aliases: true` to YAML.load
3. **Replace** (1 hr): Use `gem 'config'` - similar API, actively maintained

### Revised Upgrade Path (Simpler!)
1. ✅ Fix settingslogic (10 minutes with fork)
2. ⏳ Ruby 2.7 → 3.2 (now unblocked!)
3. ⏳ Rails 6.1 → 7.0 (can keep Webpacker temporarily)
4. ⏳ Webpacker → jsbundling-rails (when convenient)
5. ⏳ Vue 2 → Vue 3 (gradual migration)

**No need to do jsbundling first!** - Previous assumption was wrong.

### Discussion Points from Session
1. **Greenfield vs Incremental**: Explored full rewrite with Rails 8, but complexity of domain (STIG/SRG compliance) makes incremental more practical
2. **Inertia.js Option**: Could use Inertia to keep NuxtUI components while using Rails backend
3. **Component Libraries**: Concerned about losing NuxtUI's polished components if going pure Hotwire

### Next Investigation Areas
- Existing upgrade attempt branches Aaron mentioned
- Other gems that might block Ruby 3
- XCCDF processing library compatibility
- Vue component coupling with Rails

### Notes for Tomorrow
- Ask Aaron about his existing upgrade branches to see what other blockers he hit
- Deep dive into the XCCDF processing library (app/lib/xccdf/)
- Map out all 72 Vue components and their complexity
- Check test suite compatibility with Ruby 3

---
*Session conducted via Claude Code with Aaron Lippold*