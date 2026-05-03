# Design: Public Comment Review Workflow

**Status:** Draft for review
**Date:** 2026-04-29
**Author:** Aaron Lippold (with Claude)
**Branch:** `feat/viewer-comments` (PR #717)
**Supersedes:** Plan B (`commenter` role) — superseded by the simpler "expand viewer" decision
**Extends:** PR #717 (viewer-can-comment + structured 403) and Plan C (component-wide comments table)

---

## 1. Goal

Vulcan needs to support a **public comment period** workflow on a Component. External commenters (industry, agency partners, community) post comments against rules during a defined window; the internal team (project admins/authors) triages each comment, decides accept/modify/reject, replies, and tracks completion — closing the loop so commenters know their input was heard.

This design extends the work already on `feat/viewer-comments` (PR #717), keeps the bundle of unrelated improvements moving forward, fixes the role-gate bug Copilot flagged, and adds the missing piece: comment lifecycle + triage table.

---

## 2. User Story — Container SRG

Concrete anchor: the Container SRG project has ~25 industry commenters (Red Hat, Microsoft, IBM, etc.) providing feedback during a public review period.

**John (commenter, viewer role) reads rule `CRI-O-000050` and posts:**

> "Check text mentions runc 1.0; should be 1.1+ since CVE-2024-XXXX. Suggest changing line 3 to `runc --version | grep -E '1\.[1-9]'`."

**What John experiences:**

1. **Composition** — when John opens the comment composer on `CRI-O-000050`, he sees a banner: *"3 existing comments on this rule — read them first to avoid duplicates"* (cheap dedup, no ML). He expands, sees Sarah from Microsoft already raised the same concern in different words, and chooses to add to her thread instead of opening a new one. (If he posts anyway, a project admin can later mark his as `duplicate` of Sarah's.)
2. **Confirmation** — submission succeeds; UI confirms; if his project preferences allow, an email arrives with a deep link back to his comment so he can follow up later.
3. **Visibility** — John can return any time and see his comment in the rule's existing review thread, plus any new comments others have added.

**What the internal team experiences:**

1. **Inbox** — admin opens the Component's "Comments" panel (replaces today's flat 20-row slideover; this is Plan C). She sees a **paginated, filterable, sortable table** of every comment across the Component with a status column. Default filter: `Pending`.
2. **Triage** — she clicks John's row. A modal shows the full comment, similar comments on the same rule (one-click "merge as duplicate"), and a triage form with three states:
   - **Accept** — incorporate as suggested
   - **Modify** — incorporate with changes
   - **Reject** — won't incorporate, with reason
   - **Duplicate of** — link to canonical comment
3. **Response** — she writes a polite, specific reply: *"Thanks for catching this. We'll adopt the spirit but use a stricter regex to reject 1.0.x as well."* Click **Save triage**.
4. **Async work** — the rule edit happens later, by whoever on the team picks up the work. The comment shows **"Accept with changes"** (status set) but is not yet **Closed**.
5. **Completion** — once the rule is updated, the team member who did the work clicks **Close** on the comment row; status flips to **✓ Closed (Accept)**, and John sees the response in his "My Comments" page (v1) — outbound email is deferred to v2.

**What John sees back:**

- **In the per-rule review thread** (existing `RuleReviews.vue`): his comment now shows a 🟡 Modified badge inline, with the team's response right below it.
- **By email** (if his project preferences allow): the response, plus a deep link back to his comment.

### 2.1 Lifecycle state diagram (DISA-aligned vocabulary)

We use DISA's STIG-comment-matrix idiom, not generic English. A comment moves through a **triage decision** (what we plan to do) and, for non-terminal decisions, a **resolution** (whether the team did the work).

```
                    [posted by John, action='comment', triage_status='pending']
                                  │
                                  ▼
                              ┌────────┐
                              │pending │
                              └───┬────┘
                                  │
            ┌──── PATCH /reviews/:id/triage  (author+) ─────┐
            │                                                │
            │ commenter-initiated:                           │
            │   PATCH /reviews/:id/withdraw  (commenter)     │
            │                                                │
   ┌────────┼─────────┬─────────┬──────────┬──────────┬──────┴──────────┐
   ▼        ▼         ▼         ▼          ▼          ▼                  ▼
┌──────┐┌────────────┐┌──────────┐┌──────────┐┌──────────────┐ ┌───────────────────┐
│concur││concur_with_││non_concur││duplicate ││informational │ │needs_clarification│
│      ││ comment    ││          ││          ││              │ │                   │
└──┬───┘└──────┬─────┘└────┬─────┘└────┬─────┘└──────┬───────┘ └─────────┬─────────┘
   │ work pending          │ work pending            │                    │
   │           │           │                         │ adjudicated_at     │ commenter
   │           │           │ ←── terminal ──────→   │ auto-set           │ replies → 'pending'
   │           │           │                         │                    │ OR period closes →
   ▼           ▼           ▼                         │                    │ auto 'non_concur'
┌─────────────────────────────────────┐              │                    │
│ PATCH /reviews/:id/adjudicate       │              │                    │
│ (author+ marks work complete)       │              │                    │
└──────────────┬──────────────────────┘              │                    │
               ▼                                     │                    │
        ┌──────────────┐                             │                    │
        │ adjudicated  │ ← terminal                  │                    │
        └──────────────┘                             │                    │

         ┌──────────┐
         │withdrawn │ ← terminal (commenter-initiated; auto-sets adjudicated_at)
         └──────────┘
```

Key points:
- `concur` = "we'll incorporate as suggested" (DISA matrix: "Concur")
- `concur_with_comment` = "we'll incorporate with changes" (DISA matrix: "Concur with comment")
- `non_concur` = "we won't incorporate" with reason text in the response Review (DISA: "Non-concur")
- `duplicate` = points to canonical via `duplicate_of_review_id`; `adjudicated_at` auto-set
- `informational` = no action required (vendor note, FYI); `adjudicated_at` auto-set
- `needs_clarification` = round-trip with commenter; reverts to `pending` when commenter replies; auto-`non_concur` if comment period closes without reply
- `withdrawn` = commenter pulled their own comment; terminal; `adjudicated_at` auto-set

Terminal states: `adjudicated` (after work), `duplicate`, `informational`, `withdrawn`. Non-terminal: `pending`, `needs_clarification`, plus the work-pending intermediates `concur`, `concur_with_comment`, `non_concur` (which become terminal only after `PATCH /adjudicate`).

The endpoint formerly called `/resolve` is renamed to `/adjudicate` to match the vocabulary; the column formerly `addressed_at`/`addressed_by_id` is renamed to `adjudicated_at`/`adjudicated_by_id`.

### 2.2 Mockup — Component "Comments" panel (triage table)

Replaces today's flat 20-row slideover (`ControlsSidepanels.vue:133-161`). Width responsive: 700px on `md+`, full-width below.

Status indicators always pair an icon (decorative, `aria-hidden`) with a visible text label — no color-only states (WCAG 1.4.1).

```
Container SRG  ›  Comments
Comment phase: Open  ·  16 days remaining  (closes 2026-05-15)

[Status: Pending ▾] [Rule: All ▾] [Section: All ▾] [Author: All ▾] [🔍 Search]   42 total

┌─────┬──────────────┬──────────┬──────────────────┬─────────────────┬──────────┬───────────────────────┬──────────┐
│  #  │ Rule         │ Section  │ Author           │ Comment (prev.) │ Posted   │ Status                │ Action   │
├─────┼──────────────┼──────────┼──────────────────┼─────────────────┼──────────┼───────────────────────┼──────────┤
│ 142 │ CRI-O-000050 │ Check    │ John Doe (RH)    │ Check text men… │ 2d ago   │ ◯ Pending             │ [Triage] │
│ 141 │ CRI-O-000051 │ Severity │ Sarah K (MS)     │ Could we softe… │ 3d ago   │ ◐ Accept w/ changes   │ [Close]  │
│ 140 │ CRI-O-000010 │ —        │ Mike L (IBM)     │ Why is this on… │ 5d ago   │ ◑ Decline             │ [Close]  │
│ 139 │ CRI-O-000050 │ Check    │ John Doe (RH)    │ Same as #142, … │ 5d ago   │ ◭ Duplicate of #142   │   —      │
│ 137 │ CRI-O-000010 │ Title    │ Brian S (MITRE)  │ Spelling — “con… │ 6d ago   │ ⓘ Informational       │   —      │
│ 135 │ CRI-O-000020 │ Fix      │ Tim P (RH)       │ Could you clari… │ 7d ago   │ ⌛ Needs clarification │ [View]   │
│ 130 │ CRI-O-000030 │ Check    │ Lee R  (Cisco)   │ Withdrawing — d… │ 9d ago   │ ⊘ Withdrawn           │   —      │
│ 110 │ CRI-O-000020 │ Fix      │ Tim P (RH)       │ The fix here is │ 14d ago  │ ✓ Closed (Accept)     │   —      │
└─────┴──────────────┴──────────┴──────────────────┴─────────────────┴──────────┴───────────────────────┴──────────┘

Summary: 12 pending · 5 accept · 3 accept-w/-changes · 8 decline · 2 duplicate
       · 4 informational · 1 needs-clarification · 1 withdrawn · 12 closed
                                                        ← Page 1 of 9 →
```

(All friendly UI labels above come from `triageVocabulary.js` / `en.yml`. Hover any status badge → tooltip shows the DISA term per §3.1.2.)

`—` in Section = `(general)` (NULL). Action column shows the keyboard-accessible primary button per row (`[Triage]` for pending, `[Adjudicate]` for triaged, `[View]` for needs-clarification, `—` for terminal states). Row-click is a mouse-only convenience that emits the same action.

Default filter on open: `Triage: Pending`. Sort: newest first. Click `[Triage]` → triage modal (§2.3).

Status icons (all `aria-hidden`, paired with text label):

| Icon | Text label | State |
|---|---|---|
| `◯` | Pending | untriaged |
| `●` | Concur | concur |
| `◐` | Concur w/ comment | concur_with_comment |
| `◑` | Non-concur | non_concur |
| `◭` | Duplicate of #N | duplicate |
| `ⓘ` | Informational | informational |
| `⌛` | Needs clarification | needs_clarification |
| `⊘` | Withdrawn | withdrawn |
| `✓` | Adjudicated | adjudicated |

Glyph shapes (not just colors) distinguish states for color-blind users. Text label is the source of truth for screen readers.

### 2.3 Mockup — Triage modal

```
Comment #142 on CRI-O-000050  ·  Section: Check                [Open in rule editor ↗]
John Doe (Red Hat) — john@redhat.com  ·  posted 2 days ago

  ▌ Check text mentions runc 1.0; should be 1.1+ since CVE-2024-XXXX.
  ▌ Suggest changing line 3 to:
  ▌   runc --version | grep -E '1\.[1-9]'

Other comments on this rule's Check section (2):
  • #139 John Doe (5d ago)  "Same as #142, different wording"      [Mark dup of #142]
  • #87  Brian S  (12d ago) "runc version reference is stale"      [Open]

──── Decision ────────────────────────────────────────────────────────
  ( ) Accept (Concur)                  — incorporate as suggested
  (•) Accept with changes (Concur w/c) — incorporate with changes
  ( ) Decline (Non-concur)             — won't incorporate (response required)
  ( ) Duplicate of:           [search comments…]
  ( ) Informational         — note acknowledged, no action required
  ( ) Needs clarification   — round-trip with commenter before deciding

Response to John (visible in his rule thread + on his "My Comments" page):
┌───────────────────────────────────────────────────────────────────┐
│ Thanks for catching this. We'll adopt the spirit but use a        │
│ stricter regex to reject 1.0.x as well. — Aaron                   │
└───────────────────────────────────────────────────────────────────┘

[ Save decision ]    [ Save & close ]    [ Cancel ]
```

The triage modal is the **one place** the doc shows DISA terms in parens after the friendly label — pedagogical for triagers. Everywhere else (table, badges, profile) shows friendly labels alone with DISA in tooltip. Radios are wrapped in `<b-form-group label="Decision">` (renders as fieldset/legend). Section context (`Section: Check`) is shown read-only.

`Save decision` → `PATCH /reviews/142/triage` with `triage_status` (DISA-native key on the wire) + optional `response_comment`. **The response text becomes a child Review with `responding_to_review_id=142`, `action='comment'`, and inherited `section`.**

`Save & close` → atomic `PATCH /reviews/142/triage` then `PATCH /reviews/142/adjudicate`. Status flips to `✓ Closed (Accept)`. Disabled when decision is `informational`, `duplicate`, `withdrawn`, or `needs_clarification` (these auto-set `adjudicated_at` per §2.1).

Decline requires `response_comment` (server-side validation: `triage_status='non_concur'` + blank response → 422 with friendly error message "Decline requires a response — explain why so the commenter understands.").

### 2.4 Mockup — Composer dedup banner (the cheap dedup)

When a viewer opens the comment composer on a rule that has ≥1 existing comments:

```
┌─ New comment on CRI-O-000050 ────────────────────────────────────┐
│                                                                   │
│  ⓘ 3 existing comments on this rule. [Read first ▾]              │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │ Type your comment...                                         │ │
│  │                                                              │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                              [Cancel]  [Submit]   │
└───────────────────────────────────────────────────────────────────┘
```

Click **Read first** expands inline:

```
  ⓘ 3 existing comments on this rule. [Hide ▴]

      • Sarah K (3d) "Could we soften the check text wording so old…"  [Reply]
      • Brian S (12d) "runc version reference is stale, see CVE-2024…" [Reply]
      • Mike L (18d) "Why is this only checking 64-bit hosts?"          [Reply]
```

Each item has a `[Reply]` button that pre-fills the composer with `responding_to_review_id` set, so John can add to the existing thread instead of opening a new top-level comment.

This is the **v1 dedup mechanism** — covers ~80% of duplicates at near-zero engineering cost. Semantic similarity matching is YAGNI for v1 (see §5).

### 2.5 What each persona sees, summarized

| Persona | Where they live in the UI | What they can do |
|---|---|---|
| **Commenter (John, viewer)** | Per-rule `RuleReviews` thread + new "My Comments" page on their profile (§2.9) | Read all comments on a rule, post a section-tagged comment, reply to a thread, edit own pending comment, withdraw own comment, view triage status of all their comments across all projects |
| **Triager (admin/author)** | Component "Comments" panel + triage modal | See full triage queue across the component, decide concur/concur_with_comment/non_concur/duplicate/informational/needs_clarification, write responses, mark adjudicated |
| **Author doing rule edits** | Same `RuleReviews` thread + triage modal "Open in rule editor" link | Deep-link from a triage decision to the rule editor, make the change, return to the comment to mark it adjudicated |

### 2.6 Section-tagged comments — making triage targeted

Most comments are about a specific *section* of a rule, not the rule as a whole. "Check text mentions runc 1.0" is about Check; "this severity rating is too low" is about Severity. Pre-tagging the section dramatically speeds up triage and lets commenters discover existing feedback that's relevant to their concern.

**Section vocabulary** — reuses the existing `RuleConstants::LOCKABLE_SECTION_NAMES`:

```
Title · Severity · Status · Fix · Check · Vulnerability Discussion ·
DISA Metadata · Vendor Comments · Artifact Description · XCCDF Metadata · (general)
```

`(general)` is the nullable default — used when the comment isn't tied to a specific section.

#### 2.6.1 Mockup — per-section comment icons in the rule editor

Each section's `<RuleFormGroup>` invocation in `app/javascript/components/rules/forms/` (RuleForm, CheckForm, DisaRuleDescriptionForm, RuleDescriptionForm — orchestrated by UnifiedRuleForm) gets a small, subtle `💬` icon next to its label, via a new optional `comment-section` prop on `RuleFormGroup.vue`. Hover shows a tooltip; click opens the composer with that section pre-tagged. A counter badge appears when the section has pending comments.

```
╔══ CRI-O-000050 ═══════════════════════════════════════ [💬+1 General comment] ═══╗
║                                                                                    ║
║  Title 💬                                                                          ║
║  ┌────────────────────────────────────────────────────────────────────────────┐  ║
║  │ Container runtime version must be supported and patched...                  │  ║
║  └────────────────────────────────────────────────────────────────────────────┘  ║
║                                                                                    ║
║  Severity 💬                       Status 💬                                       ║
║  ┌──────────────────────┐         ┌──────────────────────────────────────────┐   ║
║  │ medium               │         │ Applicable - Configurable                │   ║
║  └──────────────────────┘         └──────────────────────────────────────────┘   ║
║                                                                                    ║
║  Check 💬③                                                                         ║
║  ┌────────────────────────────────────────────────────────────────────────────┐  ║
║  │ Inspect the container runtime by running:                                   │  ║
║  │   runc --version | grep -E '1\.0'                                           │  ║
║  │ ...                                                                          │  ║
║  └────────────────────────────────────────────────────────────────────────────┘  ║
║                                                                                    ║
║  Fix 💬                                                                            ║
║  ┌────────────────────────────────────────────────────────────────────────────┐  ║
║  │ Update the container runtime to the latest supported version...             │  ║
║  └────────────────────────────────────────────────────────────────────────────┘  ║
║                                                                                    ║
╚════════════════════════════════════════════════════════════════════════════════════╝
```

- `💬` (no badge) — section has no pending comments. Click to start a new one tagged to that section.
- `💬③` — section has 3 pending (untriaged) comments. Click expands an inline read-first list (mini version of §2.4 dedup banner, scoped to this section) before the composer.
- Top-right floating button: `[💬+1 General comment]` — adds a comment with `section=null`. Only present at the top of the rule, not duplicated per section.

For locked rules during a non-comment-period state, the icons hide entirely. For viewers (the commenter persona), the icons are the *only* mutating UI elements visible — everything else is read-only.

#### 2.6.2 Mockup — composer with section selector

When the composer opens (whether from a per-section icon, the general-comment button, or a `[Reply]` link in the dedup expand list):

```
┌─ New comment ────────────────────────────────────────────────────┐
│                                                                   │
│  Commenting on:  CRI-O-000050  ›  [Check ▾]                      │
│                                                                   │
│  ⓘ 3 existing Check comments on this rule. [Read first ▾]        │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │ Type your comment...                                         │ │
│  │                                                              │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                              [Cancel]  [Submit]   │
└───────────────────────────────────────────────────────────────────┘
```

The section dropdown is editable — John can re-tag if he picked the wrong section by accident. The dedup banner is filtered to the chosen section (so changing section repopulates the list). When section is `(general)`, the banner shows all comments on the rule.

#### 2.6.3 Triage table — Section + Rule filtering (whole vs. part)

§2.2 mockup updated:

```
[Status: Pending ▾] [Section: All ▾] [Rule: All ▾] [Author: All ▾] [🔍 Search] 12 total

┌─────┬──────────────┬──────────┬──────────────────┬─────────────────┬──────────┬───────────┐
│  #  │ Rule         │ Section  │ Author           │ Comment preview │ Posted   │ Status    │
├─────┼──────────────┼──────────┼──────────────────┼─────────────────┼──────────┼───────────┤
│ 142 │ CRI-O-000050 │ Check    │ John Doe (RH)    │ Check text men… │ 2d ago   │ ⚪ Pending │
│ 141 │ CRI-O-000051 │ Severity │ Sarah K (MS)     │ Could we softe… │ 3d ago   │ ⚪ Pending │
│ 140 │ CRI-O-000010 │ —        │ Mike L (IBM)     │ Why is this on… │ 5d ago   │ ⚪ Pending │
│ 138 │ CRI-O-000020 │ Fix      │ Tim P (RH)       │ The fix here i… │ 8d ago   │ ✅ Addressed│
└─────┴──────────────┴──────────┴──────────────────┴─────────────────┴──────────┴───────────┘
```

`—` is the visual rendering for `section IS NULL` (a general comment).

The Section filter values are `RuleConstants::LOCKABLE_SECTION_NAMES + ['(general)']`.

**The two filters compose to give whole-vs-part views:**

| Filter combo | What you see |
|---|---|
| `Rule = (none)`, `Section = All` | Everything across the component — the default triage queue view |
| `Rule = (none)`, `Section = Check` | Every Check-related comment across all rules — useful for batch triage of one section type |
| `Rule = CRI-O-000050`, `Section = All` | **All comments on rule CRI-O-000050, every section** — the "whole rule" view |
| `Rule = CRI-O-000050`, `Section = Check` | Just Check comments on that one rule — the "specific concern" view |

The `Rule` filter is a typeahead/autocomplete bound to the component's rule list. Selecting a rule keeps the table layout (so you still see Section column for context) but narrows to one rule. From there a triager can scan whole-rule context, or layer the Section filter on top to drill into one part.

**Rule-level grouping in the table itself:** when `Rule` filter is set to a single rule, an optional sort-by-section toggle lets you group the rows visually:

```
With Rule=CRI-O-000050, Section=All, Group-by-section=on:

┌─────┬──────────────────────────────────────────────────────────────────────────┐
│ Section: Check  (3 comments)                                                   │
├─────┼──────────────────────────────────────────────────────────────────────────┤
│ 142 │ John Doe   (RH)     Check text men…    2d ago    ⚪ Pending               │
│ 139 │ John Doe   (RH)     Same as #142, …   5d ago    ⚫ Dup→#142               │
│  87 │ Brian S    (MITRE)  runc version re…  12d ago   🟢 Accepted               │
│─────│──────────────────────────────────────────────────────────────────────────│
│ Section: Fix  (1 comment)                                                      │
├─────┼──────────────────────────────────────────────────────────────────────────┤
│  92 │ Sarah K    (MS)     Suggested fix t…  10d ago   ⚪ Pending               │
│─────│──────────────────────────────────────────────────────────────────────────│
│ Section: (general)  (1 comment)                                                │
├─────┼──────────────────────────────────────────────────────────────────────────┤
│  44 │ Mike L     (IBM)    Why is this on…   18d ago   🔴 Rejected              │
└─────┴──────────────────────────────────────────────────────────────────────────┘
```

This is the "whole rule" view a triager wants when sitting down to fully process one rule's feedback before moving on.

**Convenience entry point from the rule editor:** the rule editor's header gets a `[💬 View all comments on this rule]` link next to the `[💬+1 General comment]` button. Click → opens the Component "Comments" panel pre-filtered to `Rule = current rule, Section = All, Group-by-section = on`. Same effect as opening the panel and setting the filter manually, but one click instead of three.

#### 2.6.4 Thread rendering — section badges in `RuleReviews.vue`

Each comment in the existing rule thread gets a small section badge:

```
─── John Doe (Red Hat)  ·  2 days ago  ·  [Check]  ─────────────  ⚪ Pending ──
   Check text mentions runc 1.0; should be 1.1+ since CVE-2024-XXXX...
   ↳ Aaron (project admin)  ·  yesterday  ·  responding to ↑
       Thanks for catching this. We'll adopt the spirit but use a
       stricter regex to reject 1.0.x as well.

─── Sarah K (Microsoft)  ·  3 days ago  ·  [Severity]  ────────────  🟢 Accepted ──
   Could we soften the check text wording so old container runtimes...

─── Mike L (IBM)  ·  5 days ago  ·  [general]  ─────────────────  ⚪ Pending ──
   Why is this only checking 64-bit hosts?
```

The thread can be filtered by section via a dropdown at the top, mirroring the triage table filter — so a triager looking at one rule can quickly see all Check-related conversation in one filtered view.

### 2.7 Component-level main view integration

The Component page (`ProjectComponent.vue`) already has tabs/panels for Rules, Members, etc. Two additions:

#### 2.7.1 Comment period banner

When a component is in an active public comment window (admin-set start/end dates — see Q6 below), a banner appears at the top:

```
ⓘ Public comment period open · 16 days remaining (closes 2026-05-15)
   12 pending comments awaiting triage   [Open Comments panel →]
```

The banner is dismissable per-session for triagers who don't want it on every page load. For commenters (viewers), it remains sticky as a reminder of the deadline.

When no comment period is active, no banner is shown — comments still work, but it's clearly a closed-loop internal flow.

#### 2.7.2 Rule list — comment count badges

The rule list on the Component page is `RuleNavigator.vue` (a left-sidebar navigator/tree, not a table). Each rule row already shows a stack of icons (locked, changes-requested, review-requested, satisfies). Add one more — a comment-count indicator — alongside the existing icons:

```
┌───────────────────┬─────────────────────────────────┬──────────┬───────────┬──────────────┐
│ Rule ID           │ Title                           │ Severity │ Status    │ 💬 Comments  │
├───────────────────┼─────────────────────────────────┼──────────┼───────────┼──────────────┤
│ CRI-O-000010      │ The container runtime must …    │ medium   │ Configura…│              │
│ CRI-O-000020      │ Container images must be sig…   │ high     │ Inherentl…│ 1 closed     │
│ CRI-O-000050      │ Container runtime must be …     │ medium   │ Configura…│ ⚪ 3 pending  │
│ CRI-O-000051      │ Containers must run with …      │ low      │ Does Not …│ 🟢 1 accepted │
└───────────────────┴─────────────────────────────────┴──────────┴───────────┴──────────────┘
```

The column shows the *most actionable* status per rule (UI labels per §3.1.2):
- `◯ N pending` if any comments are untriaged
- otherwise `◐ N accept-w/-changes` / `● N accept` / `◑ N decline` based on the most "open" triage state
- `N closed` (no glyph) if all comments are closed (adjudicated)
- empty if zero comments

A new filter at the top of the rule list: `[Show only rules with pending comments]` — toggles the table to rules where ≥1 comment is `triage_status='pending'`. This is what a triager turns on when starting a triage session.

### 2.8 Edit Component view integration

The "Edit Component" page (the form for editing a Component's metadata — based_on SRG, name, etc.) gets one new fieldset:

```
─── Public Comment Period ──────────────────────────────────────
  Comment phase:  ( ) Draft        — viewers cannot post comments
                  (•) Open         — accepting comments + triaging
                  ( ) Adjudication — no new comments, triage continues
                  ( ) Final        — read-only archive

  Start date: [____________]    End date: [____________]

  ⓘ Phase advances automatically based on dates, but admins can
    advance/revert manually. During Adjudication, existing comments
    are triaged but no new ones can be posted. v1 has no outbound
    email — commenters track status via their profile (see §2.9).
─────────────────────────────────────────────────────────────────
```

Admin-only (component admin or higher). Persists to new `Component#comment_phase`, `comment_period_starts_at`, `comment_period_ends_at` fields. See §3.5.1 for schema. Outbound email toggles are deferred to v2 along with the rest of the email infrastructure.

### 2.9 "My Comments" page on the user profile (in-app commenter feedback loop)

Replaces what email *would* do in v1 — gives commenters a single place to track every comment they've made across every project, see triage status, read responses, and act on their own comments (edit while pending, withdraw, reply).

**Entry point:** new "My Comments" link in the user dropdown menu (top-right navbar). Plus a small `(N)` badge on the user avatar when there's unread activity (something triaged or responded to since last view).

**Mockup:**

```
Aaron Lippold  ›  My Comments

[Status: All ▾]   [Project: All ▾]                                            12 total

┌─────┬──────────────────┬──────────────┬──────────┬─────────────────┬──────────┬───────────────────────┬──────────────┐
│  #  │ Project          │ Rule         │ Section  │ Comment (prev.) │ Posted   │ Status                │ Last activity│
├─────┼──────────────────┼──────────────┼──────────┼─────────────────┼──────────┼───────────────────────┼──────────────┤
│ 142 │ Container SRG    │ CRI-O-000050 │ Check    │ Check text men… │ 2d ago   │ ◯ Pending             │ 2d ago       │
│ 139 │ Container SRG    │ CRI-O-000050 │ Check    │ Same as #142, … │ 5d ago   │ ◭ Duplicate of #142   │ 1d ago       │
│ 110 │ RHEL 9 STIG      │ RHEL-09-0001 │ Fix      │ Suggest using … │ 14d ago  │ ✓ Closed (Accept)     │ 9d ago    🔵│
│ 099 │ Container SRG    │ CRI-O-000020 │ Title    │ Spelling — “con… │ 18d ago  │ ⓘ Informational       │ 16d ago      │
│ 087 │ RHEL 9 STIG      │ RHEL-09-0042 │ —        │ Why is this onl… │ 22d ago  │ ◑ Decline             │ 18d ago      │
│ 044 │ Container SRG    │ CRI-O-000050 │ Check    │ Older runc ver…  │ 35d ago  │ ⌛ Needs clarification │ 30d ago   🔵│
└─────┴──────────────────┴──────────────┴──────────┴─────────────────┴──────────┴───────────────────────┴──────────────┘

🔵 = new activity since last view                                          ← Page 1 of 1 →
```

Click any row → opens the **comment detail drawer**:

```
Comment #142 on CRI-O-000050  ·  Container SRG  ·  Check section
Posted 2 days ago  ·  Status: ◯ Pending

Your comment:
  ▌ Check text mentions runc 1.0; should be 1.1+ since CVE-2024-XXXX.
  ▌ Suggest changing line 3 to:
  ▌   runc --version | grep -E '1\.[1-9]'

Triage response: (none yet — your comment is awaiting review)

──── Actions you can take ──────────────────────────────────────────
  [✏ Edit comment]      ← only available while Pending
  [⊘ Withdraw]          ← terminal; cannot be undone
  [🔗 Open in rule editor]
  [✕ Close]
─────────────────────────────────────────────────────────────────────
```

For a closed comment, the drawer shows the full triage response thread:

```
Comment #110 on RHEL-09-0001  ·  RHEL 9 STIG  ·  Fix section
Posted 14d ago  ·  Status: ✓ Closed (Accept, 9d ago)

Your comment:
  ▌ Suggest using systemctl mask instead of disable for the …

Response from Aaron Lippold (project admin), 9d ago:
  ▌ Good catch — adopting your suggestion. Updated rule will go
  ▌ out in next draft.

──── Actions you can take ──────────────────────────────────────────
  [💬 Reply to thread]
  [🔗 Open in rule editor]
  [✕ Close]
─────────────────────────────────────────────────────────────────────
```

**What the commenter can do, by status:**

| Triage status | Edit | Withdraw | Reply |
|---|---|---|---|
| `pending` | ✓ | ✓ | ✓ |
| `needs_clarification` | – | ✓ | ✓ (replying transitions back to `pending` per §2.1) |
| any non-terminal triaged (`concur`, `concur_with_comment`, `non_concur`) | – | – | ✓ |
| `adjudicated` / `duplicate` / `informational` / `withdrawn` | – | – | ✓ (still can reply, but doesn't change status) |

**Endpoints backing this page** (see §3.5):
- `GET /users/:id/comments` — lists current_user's top-level comments across all accessible projects (paginated, filterable)
- `PUT /reviews/:id` — edit own comment text (only while `triage_status='pending'`; AppSec note: this needs explicit `before_action :authorize_self_or_author_project, only: [:update]`)
- `PATCH /reviews/:id/withdraw` — commenter sets own comment to `triage_status='withdrawn'` + auto-sets `adjudicated_at`/`adjudicated_by_id=current_user.id`

**The "new activity" badge** (`🔵` indicator + navbar badge): backed by `User#comments_last_viewed_at` timestamp. When a commenter visits `/my/comments`, we update the timestamp. Comments where `latest_activity_at > comments_last_viewed_at` show the dot. `latest_activity_at` is computed as `GREATEST(triage_set_at, adjudicated_at, latest_response_review.created_at)`. Cheap to implement; no separate notification queue needed.

**This is the v1 in-app substitute for email.** Commenters bookmark `/my/comments`, get visual feedback on status changes, and have a clear path to act on their own comments — without any of the email compliance/deliverability overhead deferred to v2.

---

## 3. Design — Decisions Made

### 3.1 Role model: expand `viewer` (not new role)

Decided: viewer = read + comment. **No new `commenter` role.** Plan B's tri-state `viewer/commenter/author` is superseded by this simpler decision.

Implications:
- `ReviewsController#create` filter stays `authorize_viewer_project` (already in PR #717).
- Per-action enforcement moves to the model layer (see 3.2) — viewers can only successfully save `comment`; everything else is rejected.
- Frontend stays binary `readOnly` boolean; the Comment button is the one collaboration action that survives `readOnly=true`.

### 3.1.1 Vocabulary layering — DISA in storage, friendly English in UI

**This principle applies everywhere in the implementation. Read this section first if you are an agent picking up this doc to write code.**

**The rule:**

| Layer | Vocabulary | Why |
|---|---|---|
| Database column values | **DISA-native** (`concur`, `concur_with_comment`, `non_concur`, `duplicate`, `informational`, `needs_clarification`, `withdrawn`, `adjudicated_at`) | Stable keys for export to DISA STIG comment-resolution matrix (CSV/OSCAL). Never break when UI strings change. |
| API request/response payloads | **DISA-native** | API consumers (current frontend, future SDK, future export tools) get stable contracts. |
| CSV / OSCAL / OHDF export | **DISA-native** | Native interop with DISA-published comment matrices and downstream SAF tools. |
| Vue template UI labels | **Friendly English** ("Accept", "Decline", "Closed") | Industry commenters at Red Hat/Microsoft/IBM should not need a DISA glossary to use Vulcan. Lower onboarding friction for the commenter persona. |
| HAML view UI labels | **Friendly English** | Same. |
| Triage modal *radios specifically* | **Both** ("Accept (Concur)") | Pedagogical: triagers learn the DISA mapping organically without it being everywhere. |
| Tooltips on status badges | **DISA term + brief explanation** | Triagers and admins who DO need to interface with DISA's matrix can hover for the native term. |
| Admin-only screens / config | **DISA-native acceptable** | Component admins are operational power users; "Adjudication" phase label is fine. |
| Error messages / validations | **Friendly English** | "Decline requires a response" beats "Non-concur requires a response_comment". |
| Internal logs, audit trail, beads cards | **DISA-native** | Searchability across the matrix; one term per concept in operational tooling. |
| Email (v2) | **Friendly English in body, DISA-native in audit metadata** | When v2 ships, recipients see "Your comment was accepted"; the audit log shows `triage_status='concur'`. |

**Single source of truth (one file each, no duplication):**

- **Backend / Rails views:** `config/locales/en.yml` with namespace `vulcan.triage.*` — see §3.1.2 below.
- **Frontend / Vue:** `app/javascript/constants/triageVocabulary.js` — exports `TRIAGE_LABELS` (friendly), `TRIAGE_DISA_LABELS` (matrix), `TRIAGE_TOOLTIPS` (combined).
- **Status icons:** also exported from `triageVocabulary.js` so the icon glyph + label always travel together.

**Anti-patterns to avoid (these are the failure modes this section exists to prevent):**

1. ❌ Hardcoding "Concur" in a Vue template. → Always import from `triageVocabulary.js`.
2. ❌ Storing "accepted" in the database. → DB column values are always the DISA-native key.
3. ❌ Translating in the controller before render. → Translation happens at the template layer only.
4. ❌ Writing "Adjudicated" in a user-facing error message. → Use t('vulcan.triage.errors.cannot_adjudicate_pending') which renders friendly English.
5. ❌ Using the friendly label as a CSS class or DOM id. → Use the DISA-native key for class names (`triage-status--concur`, not `triage-status--accept`) so a UI label change doesn't break selectors or tests.
6. ❌ Writing parallel mappings in HAML and Vue. → If you find yourself typing the mapping twice, stop and import.

**Acceptance criteria** (also called out in §7): grep verifications must pass before merge:

```bash
# No friendly labels in the database / migrations / models / controllers / API
grep -rE "accept|decline|closed" app/models app/controllers db/migrate \
  | grep -iE "(triage|concur)" \
  # → must return zero matches that aren't comments

# No DISA terms in user-facing templates (except where intentionally pedagogical)
grep -rE "concur|adjudicat" app/javascript/components app/views \
  | grep -v triageVocabulary.js | grep -v locales/en.yml \
  # → matches must be intentional (radio fine print, tooltips) — review each
```

### 3.1.2 The canonical label table

This is the source of truth referenced by both `config/locales/en.yml` and `app/javascript/constants/triageVocabulary.js`. Implementations of those files MUST match this table exactly.

| DB key (stable) | Icon | UI label (friendly) | Tooltip (DISA + hint) | Export term |
|---|---|---|---|---|
| `pending` | `◯` | Pending | "Awaiting triage" | Pending |
| `concur` | `●` | Accept | "Concur — incorporate as suggested" | Concur |
| `concur_with_comment` | `◐` | Accept with changes | "Concur with comment — incorporate with changes" | Concur with comment |
| `non_concur` | `◑` | Decline | "Non-concur — won't incorporate (response required)" | Non-concur |
| `duplicate` | `◭` | Duplicate of #N | "Duplicate of comment #N" | Duplicate |
| `informational` | `ⓘ` | Informational | "Note acknowledged, no action required" | Informational |
| `needs_clarification` | `⌛` | Needs clarification | "Awaiting more info from commenter" | Needs clarification |
| `withdrawn` | `⊘` | Withdrawn | "Commenter retracted this comment" | Withdrawn |
| `adjudicated_at IS NOT NULL` | `✓` | Closed | "Adjudicated — work complete" | Adjudicated |

For the `comment_phase` enum on Component:

| DB key | UI label | Note |
|---|---|---|
| `draft` | Draft | "Not accepting comments yet" |
| `open` | Open for comment | "Accepting new comments + triaging" |
| `adjudication` | Adjudication | "No new comments; finalizing decisions" |
| `final` | Final | "Read-only archive" |

(Admin-facing config, so the labels lean closer to DISA terminology — but still avoid the awkward "Non-concur" form because admins don't see it as a status.)

### 3.2 Per-action role gate in the Review model — fixes Copilot bug

**The bug** (Copilot finding #1): with `authorize_viewer_project` on the controller, `Review#can_request_review` does not check role — a viewer sending `action=request_review` against an unlocked, not-under-review rule will pass validation and become the review_requestor.

**The fix:** add `Review::ACTION_PERMISSIONS` as the single source of truth, with an explicit `TIER_ROLES` lookup hash (no `constantize` — fragile and a security smell):

```ruby
TIER_ROLES = {
  viewers:   %w[viewer author reviewer admin],
  authors:   %w[author reviewer admin],
  reviewers: %w[reviewer admin],
  admins:    %w[admin]
}.freeze

ACTION_PERMISSIONS = {
  'comment'               => :viewers,    # post-PR #717: viewers can comment
  'request_review'        => :authors,
  'revoke_review_request' => :authors,
  'request_changes'       => :reviewers,
  'approve'               => :reviewers,
  'lock_control'          => :admins,
  'unlock_control'        => :admins
}.freeze
```

The `Review::VALID_ACTIONS` constant added in PR #717 is replaced by `ACTION_PERMISSIONS.keys`.

`validate_project_permissions` becomes:

```ruby
def validate_project_permissions
  return unless user && rule
  required_tier = ACTION_PERMISSIONS[action]
  return if required_tier.nil?  # inclusion validator catches unknowns
  return if TIER_ROLES.fetch(required_tier).include?(project_permissions)
  errors.add(:base, "Insufficient permissions to #{action} on this component")
end
```

This single check replaces the existing "blank permissions" check and makes every per-action `can_*` validator a *finer-grained* state check (not under review, etc.) layered on top of the role gate.

### 3.3 Comment lifecycle — extend Review (not separate table)

**Decision:** add lifecycle columns to `Review`. Keep responses as Review records linked back via self-FK.

**Why this over a separate `comment_triages` table:**
- One model, one migration, one set of policies
- Response text already has a home (the comment field of the response Review)
- The existing rule thread renders responses naturally, no new UI required there
- Email/audit/blueprint infrastructure already covers Review writes
- The "extra NULL columns on non-comment reviews" cost is negligible at Vulcan's scale

**Schema additions** (single migration on `reviews`):

```ruby
add_column :reviews, :triage_status, :string, default: 'pending', null: false
# values: pending | concur | concur_with_comment | non_concur | duplicate
#       | informational | needs_clarification | withdrawn

add_column :reviews, :triage_set_by_id, :bigint
add_column :reviews, :triage_set_at, :datetime
add_column :reviews, :adjudicated_at, :datetime          # was addressed_at
add_column :reviews, :adjudicated_by_id, :bigint         # was addressed_by_id
add_column :reviews, :duplicate_of_review_id, :bigint
add_column :reviews, :responding_to_review_id, :bigint
add_column :reviews, :section, :string  # XCCDF element key (see SECTION_KEYS below); NULL = general

add_index :reviews, [:action, :triage_status]
add_index :reviews, [:rule_id, :section, :triage_status]  # composite drives triage queue + dedup banner
add_index :reviews, :responding_to_review_id
add_index :reviews, :duplicate_of_review_id
add_index :reviews, :user_id  # backs /users/:id/comments listing (verify if exists)

add_foreign_key :reviews, :users,   column: :triage_set_by_id,    on_delete: :nullify
add_foreign_key :reviews, :users,   column: :adjudicated_by_id,   on_delete: :nullify
add_foreign_key :reviews, :reviews, column: :duplicate_of_review_id, on_delete: :nullify
add_foreign_key :reviews, :reviews, column: :responding_to_review_id, on_delete: :cascade

# Backfill note: the default + null:false on triage_status sets 'pending' on
# all existing Review rows in a single statement. At Vulcan's per-project
# Review counts (low thousands) this is fine in a single migration.
```

**Section vocabulary — XCCDF element keys** (stable for export, render via `RuleConstants::FIELD_TO_SECTION` for human label):

```ruby
SECTION_KEYS = %w[
  title severity status fixtext check_content vuln_discussion
  disa_metadata vendor_comments artifact_description xccdf_metadata
].freeze
# nil represents a general (un-sectioned) comment.

ALLOWED_SECTIONS = (SECTION_KEYS + [nil]).freeze
validates :section, inclusion: { in: ALLOWED_SECTIONS, allow_nil: true,
                                  message: 'is not a recognized section' }
```

The frontend renders `nil` as `(general)` and `—` in tables. The keys map 1:1 to entries in `RuleConstants::SECTION_FIELDS` (already in `app/constants/rule_constants.rb`). Display labels are derived, not stored.

**Triage status validation + invariants:**

```ruby
TRIAGE_STATUSES = %w[
  pending concur concur_with_comment non_concur
  duplicate informational needs_clarification withdrawn
].freeze
TERMINAL_TRIAGE_STATUSES = %w[duplicate informational withdrawn].freeze
WORK_PENDING_STATUSES   = %w[concur concur_with_comment non_concur].freeze

validates :triage_status, inclusion: { in: TRIAGE_STATUSES }
validate  :duplicate_status_requires_target
validate  :non_concur_requires_response_text   # checked in controller; model knows about response Reviews via has_many
validate  :no_self_responding_reference
validate  :no_self_duplicate_reference
validate  :adjudicated_at_required_for_terminal_states

# auto-set rules (via before_save):
# - duplicate / informational / withdrawn → adjudicated_at = Time.current if blank
# - withdrawn → adjudicated_by_id = user_id (the commenter themselves)
```

**Audit:**

```ruby
include VulcanAuditable
vulcan_audited only: %i[triage_status adjudicated_at adjudicated_by_id
                         duplicate_of_review_id comment]
# captures who flipped status, when, prior value
```

**Transaction discipline:**

`Review.create` and `take_review_action`'s `rule.save!` are wrapped in `Review.transaction do ... end` at the controller layer. If review insertion fails, the rule mutation rolls back. This was a quiet bug pre-existing in master and we close it here.

**Lifecycle rules** (enforced in model validations):

| Field | Set when | Set by |
|---|---|---|
| `triage_status` | always (default `pending`) | system on create; updated by `PATCH .../triage` or `PATCH .../withdraw` |
| `triage_set_by_id`, `triage_set_at` | when `triage_status` moves off `pending` | `PATCH .../triage` |
| `adjudicated_at`, `adjudicated_by_id` | when comment is closed (work complete or terminal-by-rule) | `PATCH .../adjudicate`, OR auto-set by model on `duplicate`/`informational`/`withdrawn` |
| `duplicate_of_review_id` | when `triage_status = 'duplicate'` | required iff status=duplicate; validated in model |
| `responding_to_review_id` | only on response Reviews (action=`comment`) | set when triage/adjudicate creates the response child |

**Triage, adjudicate, and withdraw are controller endpoints, not Review actions.** They operate on an *existing* top-level comment Review:

- `PATCH /reviews/:id/triage` — updates the parent Review's `triage_status` + `triage_set_by_id` + `triage_set_at`. If `response_comment` is supplied, atomically creates a new child Review (`action='comment'`, `responding_to_review_id=:id`, inherited `section`) so the response shows up in the rule's existing thread. Author+ via controller-level `authorize_author_project`.
- `PATCH /reviews/:id/adjudicate` — sets `adjudicated_at` + `adjudicated_by_id` on the parent. If `resolution_comment` is supplied, also creates a child Review the same way. Author+. Idempotent: re-adjudicate is a no-op returning current state.
- `PATCH /reviews/:id/withdraw` — commenter-only; sets `triage_status='withdrawn'` + auto-sets `adjudicated_at`/`adjudicated_by_id=current_user.id` on the parent. The user must be the original commenter (`review.user_id == current_user.id`).

This split keeps `Review#action` as a finite enumerable set (the seven existing actions, gated by `ACTION_PERMISSIONS`) while still attributing lifecycle changes to specific users at specific times via the new columns.

### 3.4 Frontend changes

**Net new:**
- `ComponentComments.vue` — paginated/filterable/sortable b-table (per Plan C, scope-extended for triage status + section + actions columns; supports group-by-section when `Rule` filter is active)
- `CommentTriageModal.vue` — triage form with similar-comments list, decision radio, response textarea, section context shown
- `CommentComposerModal.vue` — replaces today's free-form comment input; includes section selector dropdown + dedup banner
- `CommentDedupBanner.vue` (or composable) — "N existing [Section] comments on this rule" banner; filters to selected section
- `SectionCommentIcon.vue` — small `💬` icon + optional pending count badge, rendered next to each section header in the rule editor
- `CommentPeriodBanner.vue` — sticky-for-viewers, dismissable-for-triagers banner at top of Component page

**Modified:**
- `app/javascript/components/rules/forms/RuleFormGroup.vue` — add optional `comment-section` prop that renders `SectionCommentIcon` inline with the field label
- `app/javascript/components/rules/forms/UnifiedRuleForm.vue` (orchestrator) — compute `commentsBySection` from `rule.reviews`; pass `:pending-comments-for-section` to each child form-group
- `RuleEditorHeader.vue` — add `[💬+N General comment]` button (top-right) and `[💬 View all comments on this rule]` link (opens Comments panel pre-filtered)
- `RuleReviews.vue` — show triage status badge AND section badge inline on each comment; render responses (Reviews with `responding_to_review_id`) nested under their parent; new section filter dropdown at top of thread
- `RuleNavigator.vue` (component's rule list — left-sidebar navigator) — new comment-count badge alongside existing per-rule icon stack; new "Pending comments only" filter (via existing external-filters pattern wired through `RuleFilterBar.vue`)
- `ProjectComponent.vue` — render `CommentPeriodBanner` when an active period is configured
- `UpdateComponentDetailsModal.vue` (the actual edit-component-metadata form, opened from the sidebar-details slideover when admin) — add Public Comment Period fieldset (phase radio + start/end date inputs)
- `useRuleActions.js` — add `triageComment(reviewId, ...)`, `adjudicateComment(reviewId, ...)`, `withdrawComment(reviewId)`, `editOwnComment(reviewId, text)`, and `viewAllRuleComments(ruleId)` actions
- `AlertMixin.vue` — already handles `permission_denied` post-PR #717; no changes

### 3.5 New endpoints

All endpoints use **DISA-native vocabulary on the wire** (per §3.1.1). Frontend translates to friendly labels at render time via `triageVocabulary.js`.

```
GET  /components/:id/comments
       Query params:
         triage_status — pending | concur | concur_with_comment | non_concur
                        | duplicate | informational | needs_clarification
                        | withdrawn | all (default: pending)
         resolved      — true | false | all (default: all). Orthogonal axis to
                         triage_status; queries adjudicated_at IS NOT NULL.
         section       — title | severity | status | fixtext | check_content
                        | vuln_discussion | disa_metadata | vendor_comments
                        | artifact_description | xccdf_metadata | (null) | All
         rule_id       — narrows to one rule
         author_id     — narrows to one commenter
         q             — ILIKE on comment text (sanitized via sanitize_sql_like)
         group_by      — 'section' (meaningful when rule_id is set)
         page, per_page (per_page capped at 100)
       Returns: { rows: [...], pagination: { page, per_page, total } }
       Auth: viewer+ (everyone in the project can see all comments)
       Eager-load: includes(:user, :rule, :triage_set_by, :adjudicated_by) +
                   left_join responses count to avoid N+1.

GET  /users/:id/comments
       Lists current_user's top-level comments across all accessible projects
       (paginated, filterable by status / project). Backs the "My Comments"
       page (§2.9). Auth: must be current_user (no admin override — privacy).

PATCH /reviews/:id/triage
       Body: { triage_status: 'concur_with_comment',
               response_comment: '...' (optional; required if triage_status='non_concur'),
               duplicate_of_review_id: 142 (required iff triage_status='duplicate') }
       Updates parent triage_status + triage_set_by_id + triage_set_at. Creates
       child response Review (action='comment', responding_to_review_id, inherited
       section) when response_comment present. Idempotent re-triage allowed;
       audited gem captures prior state.
       Auth: author+ via authorize_author_project (after set_review +
       set_project_from_review). Returns 200 with { review, response_review|null }.

PATCH /reviews/:id/adjudicate
       Body: { resolution_comment: '...' (optional) }
       Sets adjudicated_at/adjudicated_by_id on parent. Optional response Review
       child created if resolution_comment present. Re-adjudicate is no-op (200).
       Validates parent has triage_status not in TERMINAL_TRIAGE_STATUSES (those
       are auto-adjudicated by the model and shouldn't be re-adjudicated).
       Auth: author+. Returns 200.

PATCH /reviews/:id/withdraw
       Body: { } (no payload required)
       Commenter-only — must satisfy current_user.id == review.user_id.
       Sets triage_status='withdrawn', adjudicated_at=now, adjudicated_by_id=current_user.id.
       Validates parent is in 'pending' or 'needs_clarification' (cannot withdraw
       a comment already triaged-and-responded to).
       Auth: viewer+ (membership) AND ownership check.
       Returns 200.

PUT  /reviews/:id
       Body: { comment: '...' }
       Edit own comment text — only when triage_status='pending' AND
       current_user.id == review.user_id. Audit trail captures prior text.
       Auth: viewer+ AND ownership AND status=pending.
       Returns 200.
```

Routes mirror the existing flat custom-route pattern (`routes.rb:67-70`).

**Strong parameters policy** (per AppSec finding):
- `Review.create` create permits ONLY `[:component_id, :action, :comment, :section, :responding_to_review_id]`.
- `triage` permits ONLY `[:triage_status, :response_comment, :duplicate_of_review_id]`.
- `adjudicate` permits ONLY `[:resolution_comment]`.
- `withdraw` permits no payload.
- `update` permits ONLY `[:comment]`.
- Lifecycle fields (`triage_set_by_id`, `triage_set_at`, `adjudicated_at`, `adjudicated_by_id`) are **server-set only**, never in user params.

**IDOR protection**: All four PATCH/PUT endpoints use the explicit chain `before_action :set_review` → `before_action :set_project_from_review` → `before_action :authorize_author_project` (or `authorize_self_for_review` for withdraw/update). Cross-project triage attempts return 403, not 404.

**Rate limiting** (Rack::Attack): `POST /rules/*/reviews` throttled to 10/min and 100/hour per `current_user.id` to prevent comment-spam abuse from a compromised viewer account. Comment text length cap reduced from 10,000 to 4,000 chars for `action=comment` posts.

### 3.5.1 Component schema additions (comment phase)

Single migration on `components`:

```ruby
add_column :components, :comment_phase, :string, default: 'draft', null: false
# values: draft | open | adjudication | final
add_column :components, :comment_period_starts_at, :datetime
add_column :components, :comment_period_ends_at, :datetime

add_index :components, :comment_phase
add_index :components, [:comment_period_starts_at, :comment_period_ends_at]
```

Notify booleans deferred to v2 along with the rest of the email infrastructure (per §3.6).

Helpers on `Component`:

```ruby
COMMENT_PHASES = %w[draft open adjudication final].freeze
validates :comment_phase, inclusion: { in: COMMENT_PHASES }

def accepting_new_comments?
  comment_phase == 'open'
end

def triaging_active?
  %w[open adjudication].include?(comment_phase)
end

def comment_period_days_remaining
  return nil unless comment_phase == 'open' && comment_period_ends_at
  ((comment_period_ends_at - Time.current) / 1.day).ceil
end
```

The banner in §2.7.1 reads `comment_phase` + `comment_period_days_remaining`. New comment posts (`POST /rules/:id/reviews` with `action=comment`) check `accepting_new_comments?`; if false, return 422 with friendly message. Triage/adjudicate endpoints check `triaging_active?`.

Phase transitions can happen automatically (cron-style — out of v1 scope, defer auto-advance to v2) or manually via UpdateComponentDetailsModal. v1 is manual-only.

### 3.6 Notifications — v1 in-app only; outbound email deferred to v2

**v1 ships with NO outbound email.** Reasons (from the Email/Deliverability panel review):

- CAN-SPAM compliance scaffolding (footer with postal address, RFC 8058 List-Unsubscribe headers, suppression list) is ~1-2 days of work on its own
- Bounce / complaint handling required to avoid Vulcan's mail domain getting greylisted at Microsoft 365 / Google Workspace
- Throttle/digest needed so a triage burst doesn't generate 50 emails per recipient
- Reply-to and content-leakage policy needs explicit design

Half-shipping email risks the domain reputation of every Vulcan tenant, not just yours.

**v1 commenter-feedback loop, in-app only:**

- **Per-rule review thread** (existing `RuleReviews.vue`) — already shows all comments + responses chronologically; gets new section/status badges (§2.6.4).
- **"My Comments" page** on the user profile (§2.9) — single source of triage status for a commenter across all their projects, with badge for new activity since last view.
- **"New activity" badge** on the user avatar/navbar — reads `User#comments_last_viewed_at` against `latest_activity_at` per comment.

**v2 scope (separate PR, ~1 week timeline):**

- New mailers (`comment_received`, `comment_triaged`, `comment_adjudicated`)
- `EmailSubscription` model with tokenized unsubscribe + List-Unsubscribe header
- Bounce/complaint webhook ingestion + suppression list
- Per-recipient digest window (default 15-min coalesce)
- Project-level `email_notifications_enabled` + per-user `email_on_comment_lifecycle` preferences
- HTML + text/plain template parts
- Reply-to policy (probably noreply with footer link to Vulcan, until inbound mail processing lands separately)

The schema for v1 deliberately omits the `notify_commenters_on_*` booleans — they'll be added in the v2 migration along with the rest of the email work, so the schema reflects what's actually implemented.

---

## 4. Bug Fixes (Pulled in From Copilot Review of PR #717)

The following fall out of the design above:

1. **Per-action role gate** — fixed by `ACTION_PERMISSIONS` map (Copilot finding #1, real bug).
2. **Inclusion validator on action** — already in PR #717. Keep.
3. **Structured 403 + admin contacts** — already in PR #717. Keep.
4. **Missing `component_id` in request specs** (Copilot findings #2, #3) — fix during implementation; align specs with actual client payload from `useRuleActions.js`.
5. **Failure message that doesn't interpolate role** (Copilot finding #4) — fix during implementation; tiny polish.
6. **`rescue_from` ordering** — already in PR #717. Keep. (Bonus fix not directly related to the comment work but valuable.)

---

## 5. Out of Scope / YAGNI

Deferred so v1 stays shippable:

- **Semantic/fuzzy dedup matching** (embeddings + similarity search). v1 uses the simple "N existing comments on this rule" banner. Real semantic search is a separate feature with its own infra (vector store, embedding pipeline).
- **Per-user email preferences UI**. v1 ships project-level toggle + sane default-on at the user level. User-pref page is v1.5.
- **Bulk triage actions** ("mark all 5 selected as duplicate of #142"). v1 is one-at-a-time. If volume justifies it, add later.
- **Public comment period as a first-class entity** (`PublicCommentPeriod` model with start/end dates, locked rules during the period, etc.). v1 treats "public comment" as a workflow convention enabled by viewer-can-comment; periodization is v2.
- **Anonymous commenting** or guest commenters. Commenters must have an account and a viewer membership.
- **Inline-diff suggestions** (GitHub-style "change line 3 to X" with one-click apply). v1 keeps suggestions in the comment text; the team applies manually.
- **A separate `commenter` role** (Plan B). Superseded.
- **A separate `comment_triages` table** (Approach 2 in the brainstorm). Single Review model wins on simplicity.

---

## 6. Open Questions

- **Q1 — `triage` action semantics:** when the triager posts a triage decision, should we always create a response Review (even if `response_comment` is blank) or only when there's text? *Recommendation: only when text is present, so the rule thread doesn't fill with empty placeholder rows.*
- **Q2 — Adjudicate without response:** can `adjudicate` be called with no comment text (silent close)? *Resolved: yes, `adjudicated_at` is set but no response Review created. Used for "we already addressed this in commit X, no follow-up needed."*
- **Q3 — Locked rules:** today, locked rules block all review actions including comments. Is that the right behavior during a public comment period? *Recommendation: yes for v1 — if a rule is locked, the public comment window on it is over. Revisit if Container SRG team has a different need.*
- **Q4 — Edit/delete commenter's own comment:** can John edit or retract his own comment after posting? *Recommendation: edit only before triage_status leaves `pending`; no delete (audit trail). Retraction handled by triager marking as `rejected` with explanation.*
- **Q5 — Where does the design doc live long-term?** Root-level matches existing `DESIGN-*.md` and `PLAN-*.md` pattern but those are gitignore-friendly local files. Should this one go to `docs/development/public-comment-workflow.md` for permanent reference? *Recommendation: yes after sign-off, with a CHANGELOG entry pointing at it.*

---

## 7. Acceptance — Definition of Done for This Design

This design is approved when:
- [ ] Aaron signs off on Section 3 (decisions made)
- [ ] Open questions in Section 6 are resolved (or explicitly deferred)
- [ ] PR #717 has comments responding to all four Copilot findings, with action items pointing back at this doc
- [ ] Implementation plan (next deliverable, via `superpowers:writing-plans`) decomposes Section 3 into ordered, TDD-driven tasks with effort estimates

### 7.1 Vocabulary-layering verification (must pass before merge)

These greps are the implementation guard-rails enforcing §3.1.1. Run them as part of the PR's CI and during code review:

```bash
# (a) DISA terms must NOT appear in user-facing templates, except:
#     - the canonical mapping file: triageVocabulary.js
#     - i18n locale file: config/locales/en.yml
#     - the triage modal radio labels (intentional pedagogical exception)
grep -rnE "concur|adjudicat|non.concur" \
  app/javascript/components app/views \
  | grep -v triageVocabulary.js \
  | grep -v locales/en.yml \
  | grep -v CommentTriageModal  # the one allowed exception
# Expected: zero matches. Each match is reviewed and either fixed or
# explicitly justified with an inline comment.

# (b) Friendly UI strings must NOT appear in DB / migrations / API serialization
grep -rnE "\"(accept|decline|closed)\"" \
  app/models app/controllers app/blueprints db/migrate
# Expected: zero matches. DB writes use the DISA-native key.

# (c) The two source-of-truth files agree on every triage_status value
ruby -e "
  require 'yaml'
  yml = YAML.load_file('config/locales/en.yml').dig('en', 'vulcan', 'triage', 'status')
  js  = File.read('app/javascript/constants/triageVocabulary.js')
  yml.keys.each { |k| raise \"missing #{k} in JS\" unless js.include?(\"'#{k}':\") }
  puts 'OK'
"
# Expected: prints 'OK'. Test ensures additions to one file are mirrored in the other.

# (d) CSS classes / DOM ids use stable DISA keys (not friendly labels)
grep -rnE "class=\"[^\"]*triage-status--(accept|decline|closed)" \
  app/javascript app/views
# Expected: zero matches. Use --concur, --non-concur, --adjudicated.

# (e) i18n coverage: every triage_status DB value has a corresponding label key
ruby -e "
  require 'yaml'
  expected = %w[pending concur concur_with_comment non_concur duplicate
                informational needs_clarification withdrawn]
  yml = YAML.load_file('config/locales/en.yml').dig('en', 'vulcan', 'triage', 'status')
  missing = expected - yml.keys
  raise \"missing labels: #{missing}\" if missing.any?
  puts 'OK'
"
```

If you are an agent implementing this design, run greps (a)–(d) before each commit. They are cheap, deterministic, and catch the most common drift between layers.

---

## 8. Bundling Decision for PR #717

PR #717 today bundles three things: (a) viewer-comments feature, (b) `VALID_ACTIONS` allowlist, (c) `rescue_from` ordering fix + structured 403.

**Decision:** keep the bundle. Splitting now would churn for marginal review benefit. The implementation plan will:
1. Apply the per-action role gate fix to PR #717 directly (closes Copilot #1)
2. Apply the spec fixes (Copilot #2, #3, #4) to PR #717 directly
3. Land #717 with the bug fixes
4. Open follow-up PR(s) for the lifecycle work (migration, triage endpoints, table UI, dedup banner)

This keeps each PR's review surface manageable while not blocking forward motion.
