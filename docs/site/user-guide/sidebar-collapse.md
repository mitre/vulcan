# Collapsed Sidebar for Nested Requirements

For STIGs with heavy satisfies/satisfied-by nesting (e.g. Container SRG
has 264 rules of which ~250 are child requirements satisfied by 13
parent controls), the flat sidebar listing every rule is unusable —
95% of the entries are children the author never edits individually.
The sidebar collapses by default to show only parent controls plus
standalone (unnested) rules, with disclosure triangles for on-demand
expansion.

## Default view

When a component has nested requirements, the sidebar shows:

- **Parent controls** — rules that are satisfied-by something else
  (i.e., they satisfy at least one child).
- **Standalone rules** — rules with no satisfies relationship in either
  direction.

For Container SRG, that's 13 items instead of 264.

Each parent shows:

- A **disclosure triangle** (right-pointing when collapsed,
  down-pointing when expanded).
- A **satisfies-count badge** ("satisfies 100") so you know how many
  children sit under it without expanding.
- A **rolled-up comment count** combining the parent's own comments
  plus all child comments — so the parent reflects the full discussion
  attached to its sub-tree.

## Expand children

Click the disclosure triangle on any parent to expand its children
inline; click again to collapse. Expansion is per-parent — opening one
doesn't affect the others. Children render with the standard rule-row
treatment (selectable, comment counts, status indicators).

Clicking the **parent name** (not the triangle) selects the parent for
editing — it does *not* expand the children. This preserves the
default-collapsed flow for the common "edit the parent" case.

## Show all rules flat

Power users who need the old flat list (e.g. searching across all
264 rules) can toggle **Show nested requirements** at the top of the
sidebar. With the toggle on, every rule renders flat as it did before;
turn it off to return to the parents-only view.

The toggle is **off by default** so first-time users see the readable
view.

## Search behavior

- **Toggle off (default):** search operates only on the currently
  visible rules — parents and standalone. This eliminates the
  "100 search hits across child requirements you can't navigate to"
  problem.
- **Toggle on (flat view):** search runs across all rules; matches
  under parent controls are grouped under the parent with a match
  count, so you can see *which parent's children* matched without
  expanding everything.

## Open Rules section

The "Open Rules" panel (showing rules with open status) follows the
same default — only parent/standalone open rules are listed. Combined
with the rolled-up comment count, you can see at a glance which
parent-control sub-trees still need attention.

## Unaffected components

If a component has **no nesting** (no satisfies relationships), the
sidebar renders unchanged — flat, as it did before. The collapse
behavior only activates when there's something to collapse.
