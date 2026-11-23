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

- **Parent controls** — rules that satisfy at least one other
  requirement.
- **Standalone rules** — rules with no satisfies relationship in either
  direction.

For Container SRG, that's 13 items instead of 264.

Each parent shows:

- A **disclosure triangle** (right-pointing when collapsed,
  down-pointing when expanded).
- A **child-count badge** — the number of requirements nested under it,
  so you know how many there are without expanding.
- A **rolled-up open-comment indicator** combining the parent's own open
  comments plus those of all its children — so the parent reflects the
  full discussion attached to its sub-tree.

## Expand children

Click the disclosure triangle on any parent to expand its children
inline; click again to collapse. Expansion is per-parent — opening one
doesn't affect the others. Children render with the standard rule-row
treatment (selectable, comment counts, status indicators).

Clicking the **parent name** (not the triangle) selects the parent for
editing — it does *not* expand the children. This preserves the
default-collapsed flow for the common "edit the parent" case.

## Show all rules flat

Power users who need the old flat list (e.g. searching across every
rule at once) can turn off **Nest Satisfied** in the sidebar's
**Display** filter group. With it off, every rule renders flat as a
single list; turn it back on to return to the parents-only view.

The toggle is **on by default** so first-time users see the readable
view. Your choice is remembered per component.

## Search behavior

- **Nest Satisfied on (default):** search operates only on the rows the
  collapsed view lists — parents and standalone rules. This eliminates
  the "100 search hits across child requirements you can't navigate to"
  problem.
- **Nest Satisfied off (flat view):** search runs across every rule, and
  matching children appear as ordinary rows in the flat list.

## Open Rules section

The "Open Rules" panel at the top of the sidebar lists the rules you
currently have open for editing. It is not affected by the collapse: a
child you open from an expanded parent appears there like any other
rule.

## Unaffected components

If a component has **no nesting** (no satisfies relationships), the
sidebar renders unchanged — flat, as it did before. The collapse
behavior only activates when there's something to collapse.

Nesting is a STIG-authoring feature. SRG components carry no
satisfies/satisfied-by relationships at all, so the toggle presents as
unavailable there rather than doing nothing.
