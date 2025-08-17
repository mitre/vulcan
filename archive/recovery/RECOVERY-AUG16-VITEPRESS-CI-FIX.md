# Recovery Context - August 16, 2025 - VitePress CI Fix

## 🔴 CRITICAL - MUST READ FIRST
**ALWAYS READ THESE FILES FIRST**:
1. `/Users/alippold/.claude/CLAUDE.md` - Global Claude settings (CRITICAL: NEVER use git add -A)
2. `/Users/alippold/github/mitre/vulcan/CLAUDE.md` - Project-specific Vulcan settings
3. This recovery file for current session context

## 📍 CURRENT STATE (August 16, 2025 - Late Evening - 0% Context)
- **Location**: `/Users/alippold/github/mitre/vulcan`
- **Current Branch**: `master`
- **Working On**: Fixing VitePress CI build failure
- **Status**: Fix committed to master, waiting for CI to verify

## ✅ TODAY'S ACCOMPLISHMENTS

### VitePress Migration Complete (PR #687)
1. **Successfully migrated documentation from MkDocs to VitePress**
   - Custom Mermaid diagram support via Vue component
   - Reorganized navigation structure
   - Comprehensive compliance documentation
   - Added production/staging deployment links

2. **Dependency Isolation**
   - Created separate `docs/package.json` to avoid Vue 2/3 conflicts
   - Main app: Vue 2.6.11
   - Docs: VitePress with Vue 3
   - This separation is TEMPORARY until Vue 3 migration

### CI Build Issue and Fix
1. **Problem Identified**:
   - CI build failed with: `Missing "./server-renderer" specifier in "vue" package`
   - VitePress was following symlinks like `CODE_OF_CONDUCT.md -> ../CODE_OF_CONDUCT.md`
   - This caused VitePress to process files OUTSIDE docs directory
   - When it tried to import vue/server-renderer from parent context, it failed

2. **Fix Applied** (Commit f8dc65a):
   ```bash
   # In .github/workflows/docs.yml
   for file in *.md; do
     if [ -L "$file" ]; then
       cp --remove-destination "$(readlink "$file")" "$file"
     fi
   done
   ```
   - Replaces symlinks with actual files during CI build
   - Keeps VitePress contained within docs directory

## 🔑 KEY TECHNICAL DETAILS

### VitePress Setup
- **Dev Server**: Works perfectly at http://localhost:5173/vulcan/
- **Local Build**: FAILS due to Vue 2/3 conflict (expected)
- **CI Build**: Should work after symlink fix
- **Deployment**: Will go to https://mitre.github.io/vulcan/

### Important URLs
- **Production**: https://mitre-vulcan-prod.herokuapp.com/users/sign_in
- **Staging**: https://mitre-vulcan-staging.herokuapp.com/users/sign_in
- **Docs (after deploy)**: https://mitre.github.io/vulcan/

### Critical Files
```
docs/.vitepress/config.js         # Main VitePress configuration
docs/.vitepress/theme/index.js    # Theme with Mermaid registration
docs/.vitepress/theme/Mermaid.vue # Custom Mermaid component
docs/package.json                  # Isolated docs dependencies
.github/workflows/docs.yml        # CI/CD workflow with symlink fix
```

## 🚨 KNOWN ISSUES

1. **Local Build Fails**
   - Vue 2/3 conflict when building locally
   - Dev server works fine for development
   - CI should work with clean environment

2. **Symlinks in Docs**
   - Files like CHANGELOG.md, CODE_OF_CONDUCT.md are symlinks
   - Work fine locally but break CI builds
   - Must be replaced with actual files during CI

## 🎯 IMMEDIATE NEXT STEPS

1. **Verify CI Build**
   - Check if docs workflow passes after symlink fix
   - Monitor https://github.com/mitre/vulcan/actions

2. **If CI Still Fails**
   - The symlink replacement might need `-f` flag for force
   - Or use `cp -L` to follow symlinks automatically
   - Check error logs for specific file causing issue

3. **After Docs Deploy**
   - Verify deployment at https://mitre.github.io/vulcan/
   - Start Vue 3 + Bootstrap 5 migration (next major task)

## ⚠️ IMPORTANT REMINDERS

### Git Workflow
- **NEVER use `git add -A` or `git add .`** - User gets EXTREMELY upset
- Always add files individually: `git add file1 file2`
- Commit format: `Authored by: Aaron Lippold<lippold@gmail.com>`
- NO Claude signatures in commits

### Code Quality
- ALL tests must pass before committing (190 tests currently)
- Run linting: `yarn lint:ci` and `bundle exec rubocop`
- Pre-commit hooks auto-fix whitespace issues

### VitePress Specifics
- Mermaid requires custom implementation (plugin incompatible with alpha)
- All root file symlinks need special handling in CI
- Dual package.json setup is temporary workaround
- Port 5173 for dev server (falls back to 5174 if occupied)

## 💡 KEY LEARNINGS THIS SESSION

1. **VitePress Symlink Issue**
   - Symlinks work locally but break in CI
   - VitePress follows them to parent directory
   - Causes module resolution errors outside docs context
   - Solution: Replace with actual files during build

2. **Vue 2/3 Conflict Resolution**
   - Separate package.json isolates dependencies
   - Works for dev but not for local builds
   - CI works due to clean environment
   - Permanent fix requires Vue 3 migration

3. **User Preferences**
   - Gets frustrated quickly with repeated mistakes
   - Values working code over quick fixes
   - Strict about git operations
   - Prefers direct communication

## 🔍 MCP MEMORY KEYS
Access current knowledge with:
```ruby
mcp__server-memory__open_nodes with names:
["Vulcan Technical Learnings", "Next Steps Vulcan", "VitePress Documentation"]
```

## 📂 RECOVERY FILES
- This file: Current VitePress CI fix context
- `RECOVERY-AUG16-VITEPRESS-COMPLETE.md` - Full VitePress migration details
- Various other recovery files in root (can be cleaned up)

## ⚡ QUICK COMMANDS

```bash
# Check CI status
gh run list --workflow=docs.yml

# Test docs locally
cd docs && yarn dev

# Test symlink fix locally (with force)
cd docs
for file in *.md; do
  if [ -L "$file" ]; then
    cp -f "$(readlink "$file")" "$file"
  fi
done

# Check current branch
git branch --show-current

# View recent commits
git log --oneline -5
```

## 🎯 SESSION SUMMARY
Successfully migrated Vulcan docs to VitePress and merged PR #687. CI build failed due to symlinks. Applied fix to replace symlinks with actual files during CI build. Fix pushed to master, waiting for CI verification. Next: Vue 3 + Bootstrap 5 migration after docs are stable.