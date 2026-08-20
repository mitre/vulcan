# Beads Board Cleanup — Research & Plan

**Date:** 2026-05-20
**Status:** Research complete, defer execution until after PR #731 merges
**Trigger:** Orphan detection warning on every bd command

## Current State

One Dolt database at `vulcan-v3.x/.beads/`, redirected from vulcan-v2.x.

### Prefixes in DB
- `vulcan-v3.x-`: 190 issues (ALL are v2.x work despite the prefix — PR #717, #731, Blueprinter, seeds, triage panel, etc.)
- `vulcan-clean-`: 302 issues (unknown origin — possibly a "clean fork off master" worktree from earlier. Contains v3 stabilization work, security hardening, import/export, and general product work)
- Total: 492 issues

### The Orphan Warning
Every `bd` command shows "found N orphaned child issues whose parent no longer exists." This is because the v2.x workspace has no `prefix` config set, so the orphan detector thinks all `vulcan-v3.x-*` issues lack a project parent.

`bd doctor --deep` says "All parent-child relationships valid" — the actual issue links are fine. It's a config-level mismatch, not data corruption.

### Workaround (not yet applied)
`bd config set prefix vulcan-v3.x` in v2.x worktree would silence the warning without changing any data. Not applied because it's a band-aid that doesn't fix the naming problem.

## The Naming Problem

- v2.x = Rails 8 + Vue 2.7, active production (this worktree)
- v3.x = Rails 8 + Vue 3, SPA migration (separate worktree, different tech stack)
- They are different projects sharing one beads DB

All v2.x work was created with `vulcan-v3.x-` prefix because the DB lives in the v3.x worktree. This is confusing — a card called `vulcan-v3.x-75k` is actually v2.x work.

## Options Analyzed

### Option 1: Set prefix config (band-aid)
- `bd config set prefix vulcan-v3.x` in v2.x
- Silences warning, changes nothing else
- Cards still have wrong prefix names
- Fastest, lowest risk

### Option 2: Rename prefix (needs --repair)
- `bd rename-prefix vulcan-v2- --repair` renames ALL 492 issues to `vulcan-v2-`
- Generates NEW random hash IDs (destroys old short IDs)
- Would rename vulcan-clean issues too (unknown provenance)
- Breaks every reference in recovery files, PR descriptions, memories, plan docs
- Too destructive without understanding vulcan-clean first

### Option 3: Separate databases
- Remove redirect, `bd init` in each worktree
- Export/import issues to correct DB
- Clean but complex — 492 issues to categorize and migrate
- Cross-references between v2/v3 work would break

### Option 4: Audit vulcan-clean first, then decide
- Determine what vulcan-clean is and whether it's still relevant
- Compact/archive stale closed issues
- Then rename with clear understanding
- Correct approach but needs dedicated time

## Recommended Path (post-PR-merge)

1. Apply Option 1 now (set prefix) to stop the noise during active development
2. After PR #731 merges, do Option 4:
   a. Audit vulcan-clean — read 10-20 representative cards, determine origin
   b. Compact all closed issues in both prefixes
   c. Decide: rename, separate, or leave as-is based on audit findings
   d. If renaming: accept that all card IDs change, update recovery files

## Quick Reference

```bash
# Silence orphan warning (Option 1 — safe, reversible)
bd config set prefix vulcan-v3.x

# See what rename would do (dry run)
bd rename-prefix vulcan-v2- --repair --dry-run

# Count by prefix
bd list --limit 0 --json | python3 -c "import json,sys,re; ..."
```
