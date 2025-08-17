# Recovery Context - August 16, 2025 - MkDocs Documentation Setup

## 🔴 CRITICAL - READ FIRST
**MUST READ THESE FILES**: 
1. `/Users/alippold/.claude/CLAUDE.md` - Global Claude settings (NEVER use git add -A)
2. `/Users/alippold/github/mitre/vulcan/CLAUDE.md` - Project-specific settings
3. `/Users/alippold/github/mitre/vulcan/RECOVERY-AUG16-V2.2.1-SECURITY.md` - Today's earlier work

## 📍 CURRENT STATE (August 16, 2025 - Evening - 2% Context)
- **Location**: `/Users/alippold/github/mitre/vulcan`
- **Current Branch**: `feature/mkdocs-documentation` (committed but not pushed)
- **Working On**: Setting up MkDocs Material documentation system
- **Status**: MkDocs mostly working, some encoding issues remain

## ✅ TODAY'S ACCOMPLISHMENTS

### Earlier Today (Before MkDocs)
- Released v2.2.0 (Rails 8 upgrade, major modernization)
- Released v2.2.1 (critical security patch - removed admin@example.com from production)
- Fixed issue #681 (Applicable-Configurable field display bug)

### MkDocs Documentation Setup (Current Session)
- Created `feature/mkdocs-documentation` branch
- Set up MkDocs Material theme configuration
- Migrated wiki content from `vulcan-wiki-local/` folder
- Created comprehensive documentation structure
- Added GitHub Actions workflow for automatic deployment
- Created helper script `docs.sh` for local development
- Updated README with new documentation links
- Created API documentation based on Rails JSON endpoints
- Referenced SAF training site for user guide

## 🔧 CURRENT ISSUES

### Encoding Problems
- `docs/development/architecture.md` has Windows-1252 characters (byte 0x92)
- Character is Windows right single quote at position 4684
- Tried `iconv -f WINDOWS-1252 -t UTF-8` but file still shows as "data"
- Lines 192-195 have broken arrow characters (showing as �)

### MkDocs Configuration
- Git revision plugin disabled due to uncommitted files issues
- Need to add `fallback_to_build_date: true` when re-enabling
- Some symlinks may cause issues with certain plugins

### File Structure
```
docs/
├── about.md                          ✓ Created
├── api/
│   ├── authentication.md              ✓ Created  
│   ├── endpoints.md                   ✓ Created
│   └── overview.md                    ✓ Created
├── deployment/
│   ├── docker.md                      ✓ Created
│   ├── heroku.md                      ✗ Empty
│   ├── kubernetes.md                  ✓ Created
│   └── auth/
│       ├── github.md                  ✗ Empty
│       ├── ldap.md                    ✗ Empty
│       └── oidc-okta.md              ✓ Migrated from wiki
├── development/
│   ├── architecture.md                ✓ Created (has encoding issues)
│   ├── release-process.md            ✓ Migrated from wiki
│   ├── setup.md                       ✗ Empty
│   ├── testing.md                     ✗ Empty
│   └── vue3-migration.md             ✗ Empty
├── getting-started/
│   ├── configuration.md              ✓ Migrated from wiki
│   ├── environment-variables.md      ✓ Copied from root
│   ├── installation.md               ✓ Migrated from wiki
│   └── quick-start.md                ✓ Created
├── release-notes/
│   ├── v2.2.0.md                     ✓ Renamed from RELEASE_NOTES_v2.2.0.md
│   └── v2.2.1.md                     ✓ Renamed from RELEASE_NOTES_v2.2.1.md
├── security/
│   ├── data-encryption.md            ✗ Empty
│   └── security-controls.md          ✓ Migrated from wiki
├── user-guide/
│   └── overview.md                   ✓ References SAF training site
└── Symlinks:
    ├── index.md -> ../README.md
    ├── CHANGELOG.md -> ../CHANGELOG.md
    ├── LICENSE.md -> ../LICENSE
    └── etc.
```

## 🎯 NEXT STEPS

1. **Fix Encoding Issues**
   ```bash
   # Try removing and recreating architecture.md
   rm docs/development/architecture.md
   # Recreate with clean UTF-8 content
   ```

2. **Commit and Push**
   ```bash
   git add docs/ mkdocs.yml requirements.txt .github/workflows/docs.yml docs.sh
   git commit -m "fix: Clean up MkDocs configuration and encoding issues"
   git push -u origin feature/mkdocs-documentation
   ```

3. **Create PR**
   ```bash
   gh pr create --title "feat: Add MkDocs Material documentation system" \
                --body "Modernize documentation with MkDocs Material theme"
   ```

4. **After Merge**
   - Enable GitHub Pages in repository settings
   - Set source to GitHub Actions
   - Verify deployment at https://mitre.github.io/vulcan/

5. **Then Continue Vue 3 Migration**
   - Switch back to master
   - Start Phase 1: Remove Turbolinks (4-8 hours)

## 💡 KEY LEARNINGS

- MkDocs Material is good but cyber-trackr-live uses VitePress (might consider)
- Windows encoding issues are common when migrating old docs
- Git revision plugin needs committed files to work properly
- SAF training site has comprehensive Vulcan user guide already
- API documentation can be generated from Rails controller analysis

## 🔍 MCP MEMORY KEYS
```ruby
mcp__server-memory__open_nodes with names:
["Vulcan Technical Learnings", "Next Steps Vulcan", 
 "MkDocs Documentation Setup", "Vulcan v2.2.1 Release"]
```

## 🚀 QUICK COMMANDS
```bash
# Test MkDocs locally
mkdocs serve
# Or use helper script
./docs.sh serve

# Check for encoding issues
file docs/**/*.md | grep -v "UTF-8\|ASCII"

# Find Windows characters
grep -r $'\x92' docs/

# Current branch status
git status
git log --oneline -5
```

## ⚠️ REMEMBER
- NEVER use `git add -A` or `git add .`
- Always add files individually
- Use "Authored by: Aaron Lippold<lippold@gmail.com>" in commits
- Run linting before commits
- We're at 2% context - be concise!