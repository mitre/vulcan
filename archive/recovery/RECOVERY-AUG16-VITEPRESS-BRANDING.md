# Recovery Context - August 16, 2025 - VitePress Branding & Symlinks

## 🔴 CRITICAL - MUST READ FIRST
**ALWAYS READ THESE FILES FIRST**:
1. `/Users/alippold/.claude/CLAUDE.md` - Global Claude settings (CRITICAL: NEVER use git add -A)
2. `/Users/alippold/github/mitre/vulcan/CLAUDE.md` - Project-specific Vulcan settings
3. This recovery file for current session context

## 📍 CURRENT STATE (August 16, 2025 - Night - 0% Context)
- **Location**: `/Users/alippold/github/mitre/vulcan`
- **Current Branch**: `master`
- **Working On**: Adding Vulcan branding and fixing VitePress symlink issues
- **Status**: Created logos, Media Kit, trying to commit but pre-commit hooks failing on whitespace

## ✅ TODAY'S ACCOMPLISHMENTS

### VitePress Documentation (Completed Earlier)
- Successfully migrated from MkDocs to VitePress
- Fixed CI build issues with symlinks using `prepare-build.sh`
- Deployed to vulcan.mitre.org with custom domain support

### Branding & Logo Creation (Just Completed)
1. **Created Custom SVG Logos**:
   - `logo-alt.svg` - Main logo: Blue hexagon with shield, hammer, and "V"
   - `logo-transparent.svg` - Version for any background
   - `favicon.svg` (32x32), `app-icon.svg` (64x64), `favicon-simple.svg` (16x16)
   - Removed red shield versions - keeping blue theme consistent

2. **Logo Design Elements**:
   - Blue hexagon background (#3498db gradient to #2c3e50)
   - White shield for security
   - Brown wooden hammer handle (#8b6f47)
   - Metallic gradient hammer head
   - Blue "V" overlay
   - "VULCAN" text in #2980b9 (darker blue for readability)
   - "Security Guidance Platform" subtitle

3. **Media Kit Page**:
   - Created `/docs/about/media-kit.md`
   - Shows all logo variations with download links
   - Brand colors and usage guidelines
   - Added to navigation under "Overview" section

## 🚨 CURRENT ISSUES

### 1. Symlink Problem (Partially Solved)
- **Issue**: VitePress dev server serves symlinks as raw markdown (text/markdown MIME type)
- **Attempted Fixes**:
  - Added `preserveSymlinks: true` to vite config - didn't help dev mode
  - Links must use `.md` extension explicitly
  - Project files now link to actual files, not GitHub
- **Current Workaround**: `prepare-build.sh` replaces symlinks for production builds
- **User Frustration**: This is messy, wants clean solution

### 2. Pre-commit Hook Failures
- **Issue**: Trailing whitespace in SVG files blocking commit
- **Error**: Pre-commit hook DETECTS whitespace but doesn't auto-fix
- **Files Affected**: All SVG files in `/docs/public/`
- **Solution Needed**: Must manually remove trailing whitespace from SVGs

## 🔑 KEY TECHNICAL DETAILS

### VitePress Configuration
```javascript
// docs/.vitepress/config.js
vite: {
  resolve: {
    preserveSymlinks: true  // Added but doesn't fix dev mode
  }
}

// Base URL switching for deployment
base: process.env.GITHUB_DEPLOY === "true" ? "/" : "/vulcan/",
```

### Files Changed (Uncommitted)
- `docs/.vitepress/config.js` - Added preserveSymlinks, fixed navigation
- `docs/index.md` - Using logo-alt.svg
- `docs/about/media-kit.md` - New Media Kit page
- `docs/public/` - All logo SVG files (WITH TRAILING WHITESPACE)

## 🎯 IMMEDIATE NEXT STEPS

1. **Fix Trailing Whitespace**:
   ```bash
   cd docs/public
   for file in *.svg; do
     sed -i '' 's/[[:space:]]*$//' "$file"
   done
   ```

2. **Stage and Commit**:
   ```bash
   git add docs/.vitepress/config.js docs/index.md docs/about/media-kit.md docs/public/*.svg
   git commit -m "feat: Add Vulcan branding and improve documentation setup"
   ```

3. **Push Changes**: `git push origin master`

## ⚠️ IMPORTANT REMINDERS

### Git Workflow
- **NEVER use `git add -A` or `git add .`** - User gets EXTREMELY upset
- Always add files individually
- Commit format: `Authored by: Aaron Lippold<lippold@gmail.com>`
- NO Claude signatures in commits

### User Preferences
- Gets frustrated with repeated issues (like trailing whitespace)
- Wants CLEAN solutions, not workarounds
- Dislikes complex scripts when simple solutions exist
- Values working code over quick fixes

## 💡 KEY LEARNINGS THIS SESSION

1. **VitePress Symlinks Are Broken**:
   - Claims to support symlinks since v1.0.0-rc.4 but doesn't work
   - Dev server serves them as raw markdown
   - Build process follows symlinks causing module resolution errors
   - No clean solution exists - considering just copying files

2. **Branding Decisions**:
   - Blue color scheme chosen over red
   - Hexagon shape for modern tech feel
   - Hammer represents forge/creation (Vulcan mythology)
   - Shield for security focus
   - "Security Guidance Platform" as tagline

3. **Pre-commit Hooks**:
   - They DETECT issues but don't auto-fix
   - Must manually fix trailing whitespace
   - User got frustrated when I suggested re-running would fix it

## 🔍 MCP MEMORY KEYS
```ruby
mcp__server-memory__open_nodes with names:
["Vulcan Technical Learnings", "Next Steps Vulcan", "VitePress Documentation"]
```

## 📂 FILES TO CHECK
- `/docs/public/*.svg` - Need whitespace cleanup
- `/docs/.vitepress/config.js` - Has symlink config
- `/docs/about/media-kit.md` - New Media Kit page
- `/.github/workflows/docs.yml` - Has GITHUB_DEPLOY env var

## ⚡ QUICK COMMANDS

```bash
# Fix trailing whitespace in SVGs
cd docs/public && sed -i '' 's/[[:space:]]*$//' *.svg

# Test VitePress locally
cd docs && yarn dev

# Check git status
git status

# Stage specific files (NEVER use -A)
git add docs/.vitepress/config.js docs/index.md docs/about/media-kit.md docs/public/*.svg

# Commit with proper signature
git commit -m "message" # Will add proper signature
```

## 🎯 SESSION SUMMARY
Created comprehensive Vulcan branding with custom SVG logos and Media Kit. Struggled with VitePress symlink issues - they don't work properly despite claims. Currently blocked on committing due to trailing whitespace in SVG files that pre-commit detects but doesn't fix. User frustrated with messy workarounds and wants clean solutions.