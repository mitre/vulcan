#!/bin/bash
# prepare-build.sh - Prepare docs for VitePress build by replacing symlinks
# This script is used in CI to avoid VitePress following symlinks outside docs directory

set -euo pipefail  # Exit on error, undefined variables, and pipe failures

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
log_info() { echo -e "${GREEN}✓${NC} $1"; }
log_warn() { echo -e "${YELLOW}⚠${NC} $1"; }
log_error() { echo -e "${RED}✗${NC} $1" >&2; }

echo "📦 Preparing docs for VitePress build..."
echo "----------------------------------------"

# Change to docs directory if not already there
if [[ ! "$PWD" == */docs ]]; then
  cd docs || { log_error "Failed to change to docs directory"; exit 1; }
fi

# Count symlinks (all files, not just .md)
symlink_count=0
for file in *; do
  [ -L "$file" ] && ((symlink_count++)) || true
done

if [ "$symlink_count" -eq 0 ]; then
  log_info "No symlinks found. Build preparation not needed."
  exit 0
fi

echo "Found $symlink_count symlinks to replace:"
echo ""

# Replace all symlinks with actual files (any file type)
for file in *; do
  if [ -L "$file" ]; then
    target=$(readlink "$file")
    echo "  📄 $file -> $target"
    if cp -fL "$file" "$file.tmp" && mv -f "$file.tmp" "$file"; then
      log_info "Replaced: $file"
    else
      log_error "Failed to replace: $file"
      exit 1
    fi
  fi
done

echo ""
echo "🔧 Fixing self-referential links in all replaced files..."

# Fix any references to ./docs/ in ALL markdown files that were replaced
# This handles cases where root files reference the docs folder
files_fixed=0
for file in *.md; do
  # Only process regular files (not symlinks, since we already replaced them)
  if [ -f "$file" ] && [ ! -L "$file" ]; then
    if grep -q '\./docs/' "$file"; then
      # Special case for README.md pointing to itself
      if [ "$file" = "README.md" ] && grep -q '\./docs/README\.md' "$file"; then
        sed -i.bak 's|\./docs/README\.md|#documentation|g' "$file"
      else
        # General case: remove ./docs/ prefix since we're already in docs
        sed -i.bak 's|\./docs/|\./|g' "$file"
      fi
      rm -f "$file.bak"
      log_info "Fixed docs/ references in $file"
      ((files_fixed++))
    fi
  fi
done

if [ "$files_fixed" -eq 0 ]; then
  log_info "No self-referential links needed fixing"
fi

echo ""
echo "✅ Build preparation complete!"
echo "----------------------------------------"
echo "Ready to run: yarn build"