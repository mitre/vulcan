# Recovery Context - August 17, 2025 - Vulcan Branding & Whitespace Hooks

## 🔴 CRITICAL - MUST READ FIRST
**ALWAYS READ THESE FILES FIRST**:
1. `/Users/alippold/.claude/CLAUDE.md` - Global Claude settings (CRITICAL: NEVER use git add -A)
2. `/Users/alippold/github/mitre/vulcan/CLAUDE.md` - Project-specific Vulcan settings
3. This recovery file for current session context

## 📍 CURRENT STATE (August 17, 2025 - Morning - 2% Context)
- **Location**: `/Users/alippold/github/mitre/vulcan`
- **Current Branch**: `master`
- **Just Completed**: 
  1. Added Vulcan branding with custom SVG logos
  2. Created comprehensive whitespace fix hook for Overcommit
  3. Fixed VitePress documentation infrastructure
- **All changes pushed to master**

## ✅ TODAY'S ACCOMPLISHMENTS

### 1. Vulcan Branding Implementation
- **Custom SVG Logos Created**:
  - `logo.svg` - Main blue hexagon shield with hammer (1.4KB optimized)
  - `logo-transparent.svg` - Version for any background
  - `favicon.svg` (32x32), `app-icon.svg` (64x64), `favicon-simple.svg` (16x16)
  - Used osvg tool for minimization (logo.min.svg - 1.3KB)

- **Design Elements**:
  - Blue hexagon with gradient (#3498db to #2c3e50)
  - White shield symbolizing security
  - Brown hammer (#8b6f47) representing Vulcan forge theme
  - Blue "V" overlay with "VULCAN" text (#2980b9)
  - "Security Guidance Platform" subtitle

- **Media Kit Page**: `/docs/about/media-kit.md`
  - All logo variations with download links
  - Brand colors: Vulcan Blue, Deep Blue, Dark Navy
  - Usage guidelines and project description

### 2. VitePress Infrastructure Improvements
- **SVG Optimization**: Added vite-plugin-image-optimizer with svgo
  - Automatic optimization during build (35-55% size reduction)
  - Configured to preserve viewBox, title, desc for accessibility
  
- **Symlink Issues Fixed**:
  - Renamed LICENSE to LICENSE.md for consistency
  - Removed prepare-build.sh script (no longer needed)
  - All symlinks now work properly with .md extensions
  - Simplified GitHub Actions workflow

- **Configuration Cleanup**:
  - ignoreDeadLinks now only needs localhost regex
  - Removed circular README reference
  - Base URL switching via GITHUB_DEPLOY environment variable

### 3. Comprehensive Whitespace Fix Hook
- **Created FixWhitespace Overcommit Hook**:
  - Location: `.git-hooks/pre_commit/fix_whitespace.rb`
  - Automatically fixes trailing whitespace
  - Converts tabs to spaces (2 spaces per tab)
  - Handles UTF-8 encoding (skips binary files)
  - Re-stages files after fixing

- **Configuration**:
  ```yaml
  TrailingWhitespace:
    enabled: false  # Using FixWhitespace instead
  HardTabs:
    enabled: false  # FixWhitespace handles this
  FixWhitespace:
    enabled: true
    exclude:
      - '**/db/schema.rb'
      - '**/db/structure.sql'
      - '**/*.md'  # Preserve markdown line breaks
      - '**/Makefile'  # Makefiles require tabs
  ```

- **Key Learning**: Pre-commit hooks fix staged files, not working directory - this is correct behavior

## 🔑 KEY TECHNICAL DETAILS

### Overcommit Hook Development
- Custom hooks go in `.git-hooks/pre_commit/` directory
- Must run `bundle exec overcommit --sign` after changes
- Hooks should handle encoding: `File.read(file, encoding: 'UTF-8')`
- Use Ruby (not sed) for consistency with Rails project
- Hooks run in order - checks happen before fixes

### VitePress Asset Pipeline
- SVG files in `docs/public/` are optimized during build
- vite-plugin-image-optimizer configuration in `docs/.vitepress/config.js`
- Production deployment to vulcan.mitre.org uses custom domain base URL

### Files Changed This Session
```
- docs/.vitepress/config.js (SVG optimization, cleanup)
- docs/about/media-kit.md (new Media Kit page)
- docs/index.md (using new logo)
- docs/public/*.svg (all branding assets)
- .git-hooks/pre_commit/fix_whitespace.rb (new hook)
- .overcommit.yml (hook configuration)
- .github/workflows/docs.yml (removed prepare-build.sh)
- LICENSE -> LICENSE.md (renamed for consistency)
- README.md (removed circular reference)
- CHANGELOG.md (updated with changes)
```

## 🚨 KNOWN ISSUES & NEXT STEPS

### Immediate Priorities
1. **Monitor Deployment**: Check vulcan.mitre.org for proper branding display
2. **Dependabot**: 64 vulnerabilities (5 critical, 12 high) need addressing
3. **RuboCop Changes**: Review automatic fixes to migration files

### Upcoming Work
1. **Vue 3 + Bootstrap 5 Migration** - Next major priority
2. **Documentation**: Fill remaining VitePress placeholders
3. **Cleanup**: Remove recovery files and docs-old when appropriate
4. **Team Documentation**: Document FixWhitespace hook usage

## ⚠️ IMPORTANT REMINDERS

### Git Workflow
- **NEVER use `git add -A` or `git add .`** - User gets EXTREMELY upset
- Always add files individually
- Commit format: `Authored by: Aaron Lippold<lippold@gmail.com>`
- NO Claude signatures in commits

### Testing Hooks
- Create test files with trailing whitespace/tabs
- Run `bundle exec overcommit --run` to test manually
- Check staged vs working directory with `git diff --cached`
- Remember: hooks fix staged version, not working files

### User Preferences
- Frustrated with sed on macOS - use Python/Ruby instead
- Wants clean, working solutions - not workarounds
- Values proper integration over quick fixes
- Gets upset when tools don't work as expected

## 💡 SESSION LEARNINGS

1. **Overcommit Integration**:
   - Signing required for security after hook changes
   - RuboCop handles Ruby files, custom hooks for others
   - Hooks can modify and re-stage files automatically

2. **SVG Optimization**:
   - osvg tool great for manual minimization
   - vite-plugin-image-optimizer for automatic build-time optimization
   - 35-55% size reduction typical

3. **VitePress Deployment**:
   - Symlinks work when files have consistent .md extensions
   - Custom domain needs different base URL configuration
   - GitHub Actions can be simplified once issues fixed

## 🔍 MCP MEMORY KEYS
- "Vulcan Technical Learnings" - All technical discoveries
- "Next Steps Vulcan" - Upcoming work items
- "VitePress Documentation" - Documentation system details

## ⚡ QUICK COMMANDS

```bash
# Test whitespace hook
echo "test    " > test.txt && git add test.txt && bundle exec overcommit --run

# Sign Overcommit changes
bundle exec overcommit --sign && bundle exec overcommit --sign pre-commit

# Check staged changes
git diff --cached [file]

# Run VitePress locally
cd docs && yarn dev

# Build VitePress
cd docs && yarn build
```

## 🎯 RECOVERY INSTRUCTIONS

After compact, to restore full context:
1. Read CLAUDE.md files (global and project)
2. Check current git status and branch
3. Review recent commits with `git log --oneline -10`
4. Check MCP memory for "Vulcan Technical Learnings", "Next Steps Vulcan", "VitePress Documentation"
5. Verify hook is working: `bundle exec overcommit --run`
6. Check deployment: https://vulcan.mitre.org

Current working directory: /Users/alippold/github/mitre/vulcan
User is Aaron Lippold, very particular about git practices and clean solutions.