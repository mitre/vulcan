# Recovery Context - August 16, 2025 - VitePress Documentation Migration

## 🔴 CRITICAL - READ FIRST
**MUST READ THESE FILES**: 
1. `/Users/alippold/.claude/CLAUDE.md` - Global Claude settings (NEVER use git add -A)
2. `/Users/alippold/github/mitre/vulcan/CLAUDE.md` - Project-specific settings
3. This recovery file for current context

## 📍 CURRENT STATE (August 16, 2025 - Evening - 0% Context)
- **Location**: `/Users/alippold/github/mitre/vulcan`
- **Current Branch**: `feature/mkdocs-documentation` (needs renaming to feature/vitepress-documentation)
- **Working On**: VitePress documentation system migration
- **Status**: VitePress installed and working, needs final cleanup

## ✅ TODAY'S ACCOMPLISHMENTS

### Earlier Today
- Released v2.2.0 (Rails 8 upgrade, major modernization)
- Released v2.2.1 (critical security patch - removed admin@example.com)
- Fixed issue #681 (Applicable-Configurable field display bug)
- Created comprehensive MkDocs documentation initially

### VitePress Migration (Current Session)
- Realized VitePress makes more sense for Rails + Vue app
- Successfully migrated from MkDocs to VitePress 2.0.0-alpha.11
- Fixed PostCSS conflict by creating docs/postcss.config.js
- Updated GitHub Actions workflow for VitePress deployment
- Removed all MkDocs files (mkdocs.yml, requirements.txt, docs.sh)
- Added VitePress cache/dist to .gitignore
- VitePress running successfully at http://localhost:5174/vulcan/

## 🔧 PENDING TASKS

### Immediate Next Steps
1. **Create proper landing page** for Vulcan in VitePress
2. **Fix trailing whitespace** in docs/.vitepress/config.js (pre-commit hook failing)
3. **Rename branch** from `feature/mkdocs-documentation` to `feature/vitepress-documentation`
4. **Commit final changes** with proper message format
5. **Test build** with `yarn docs:build`
6. **Eventually push and create PR**

## 📚 DOCUMENTATION STATUS

### Completed Documentation
- **Getting Started**: Quick start, installation, configuration, environment variables
- **Deployment**: Docker, Kubernetes, Heroku, Bare-metal
- **Authentication**: GitHub OAuth, LDAP, OIDC/OKTA with troubleshooting
- **Development**: Setup, testing, architecture, release process
- **API**: Overview, authentication, endpoints
- **Security**: Compliance (NIST controls), security controls, data encryption
- **User Guide**: References SAF training site

### VitePress Configuration
- Config file: `docs/.vitepress/config.js`
- Using default theme (NO customization needed)
- PostCSS fix: `docs/postcss.config.js` (empty config to avoid Rails conflict)
- Scripts in package.json:
  - `yarn docs:dev` - Development server
  - `yarn docs:build` - Build for production
  - `yarn docs:preview` - Preview built site

## ⚠️ IMPORTANT REMINDERS

### Git Workflow
- **NEVER use `git add -A` or `git add .`** - User gets VERY frustrated
- Always add files individually with `git add <file>`
- Commit format: `Authored by: Aaron Lippold<lippold@gmail.com>`
- No Claude signatures in commits

### VitePress Specifics
- Using VitePress 2.0.0-alpha.11 (latest alpha)
- Default theme only - user dislikes unnecessary customization
- PostCSS conflict resolved with separate config in docs folder
- Cache and dist folders properly gitignored

### Pre-commit Hooks
- Automatically fix trailing whitespace
- Will fail on whitespace issues - must be fixed before commit
- ESLint warnings about VitePress cache can be ignored

## 🚀 QUICK COMMANDS

```bash
# Run VitePress locally
yarn docs:dev

# Build documentation
yarn docs:build

# Preview built docs
yarn docs:preview

# Fix whitespace issues
# Pre-commit hooks will auto-fix on commit attempt

# Rename branch (after committing current changes)
git branch -m feature/vitepress-documentation

# Current status
git status
```

## 💡 KEY LEARNINGS

- VitePress better than MkDocs for Vue projects
- Write tool requires reading files first if they exist
- User prefers simplicity - no unnecessary theme customization
- PostCSS conflicts need separate configs for different tools
- Pre-commit hooks are strict about whitespace

## 🔍 MCP MEMORY KEYS
```ruby
mcp__server-memory__open_nodes with names:
["Vulcan Technical Learnings", "Next Steps Vulcan", 
 "VitePress Documentation"]
```

## 📝 FILES TO CHECK
- `docs/.vitepress/config.js` - Main VitePress config (has whitespace issues)
- `docs/postcss.config.js` - PostCSS fix for VitePress
- `.github/workflows/docs.yml` - Updated for VitePress
- `package.json` - VitePress dependencies and scripts
- `.gitignore` - Updated with VitePress folders

## ⚠️ DO NOT
- Use `git add -A` EVER
- Create custom themes unnecessarily
- Forget to read CLAUDE.md files
- Push without fixing whitespace issues
- Forget to rename the branch