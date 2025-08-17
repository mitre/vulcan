# Recovery Prompt - Vulcan & Settingslogic Modernization
## Date: January 9, 2025
## USE THIS AFTER COMPACT TO RESTORE CONTEXT

## CRITICAL: First Actions After Compact
1. **READ THESE FILES COMPLETELY**:
   - `/Users/alippold/github/mitre/vulcan/CLAUDE.md`
   - `/Users/alippold/github/mitre/settingslogic/CLAUDE.md`
   - `/Users/alippold/github/mitre/vulcan/2025-01-09-vulcan-modernization-session.md`
   - `/Users/alippold/github/mitre/vulcan/2025-01-09-vulcan-deep-dive-findings.md`

## Current Situation Summary

### Two Active Projects
1. **Vulcan**: STIG compliance app needing modernization (main project)
2. **Settingslogic**: MITRE fork to unblock Vulcan's Ruby 3 upgrade (current focus)

### Where We Left Off
- Created MITRE fork of settingslogic
- Documented all fixes needed in `FIXES-TO-IMPLEMENT.md`
- Updated gemspec to version 3.0.0
- **NEXT**: Implement the Psych 4 fix and test it

### Critical Context

#### Vulcan Project
- **Current**: Ruby 2.7, Rails 6.1, Vue 2, Webpacker 5
- **Target**: Ruby 3.2+, Rails 7+, then gradually modernize
- **Blocker**: Settingslogic gem incompatible with Ruby 3 (fixing now)
- **Key Insight**: Don't rewrite - too much domain logic in XCCDF library
- **Developer**: Aaron Lippold (solo, no deployment pressure)

#### Settingslogic Fork
- **Location**: `/Users/alippold/github/mitre/settingslogic`
- **Purpose**: Fix Psych 4 compatibility for Ruby 3.1+
- **Main Fix**: Change `YAML.load` to `YAML.unsafe_load` or use `aliases: true`
- **Version**: Bumping to 3.0.0
- **Status**: Fork created, specs updated, ready to implement fixes

### The Upgrade Path (Corrected)
1. ✅ Identify settingslogic as blocker
2. ✅ Create MITRE fork
3. ⏳ Implement Psych 4 fix (CURRENT)
4. ⏳ Test and release settingslogic 3.0.0
5. ⏳ Update Vulcan to use MITRE fork
6. ⏳ Upgrade Vulcan: Ruby 2.7 → 3.2
7. ⏳ Upgrade Vulcan: Rails 6.1 → 7.0
8. ⏳ Later: Webpacker → jsbundling-rails

### Next Immediate Steps
1. Implement Psych 4 fix in settingslogic
2. Run tests with multiple Ruby versions
3. Create small PR for settingslogic
4. Test in Vulcan locally
5. Create minimal Vulcan branch just for Ruby upgrade

### Important Discoveries
- Settingslogic wasn't really blocking Ruby 3 - just needs simple fix
- No need to do jsbundling-rails before Ruby upgrade
- Vulcan's XCCDF library is irreplaceable domain IP
- 72 Vue components make frontend migration complex

### Files to Reference
- `/Users/alippold/github/mitre/settingslogic/FIXES-TO-IMPLEMENT.md` - All fixes needed
- `/Users/alippold/github/mitre/vulcan/UPGRADE-PATH-NOTES.md` - Quick reference
- Research from other forks: minorun99, etozzato have working fixes

### Commands to Get Started
```bash
# For settingslogic work:
cd ~/github/mitre/settingslogic
bundle install
bundle exec rspec

# For Vulcan testing:
cd ~/github/mitre/vulcan
git checkout -b chore/ruby-3-upgrade
# Update Gemfile to use MITRE settingslogic fork
```

### Key Decisions Made
- Use incremental upgrade, not greenfield rewrite
- Fix settingslogic via MITRE fork (not vendor or replace)
- Keep scope small - one fix at a time
- Ruby upgrade first, then Rails, then frontend

### Remember
- Keep PRs small and focused
- Test each change thoroughly
- Document in CLAUDE.md files
- Aaron wants clean commits with proper attribution

---
**Context restored. Ready to continue with settingslogic Psych 4 fix implementation.**