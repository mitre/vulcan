# PR Sequencing and Container SRG Launch Plan

Recorded 2026-08-11 from Aaron's ruling. This file is the one place that states
the merge order, what each stage contains, and the launch sequence. The board
labels are the mechanical truth for stage membership — this file explains them.

## The real goal

The larger team works the Container SRG project **in production** to finish the
Container SRG and get it approved. Everything stages around that:

- The Container SRG is already rebuilt inside Vulcan as a proper SRG-kind
  component on the Application Core SRG — dev **project 93 / component 122**
  ("Container Security Requirements Guide (Preview)", CNTR-00): 321
  requirements determined and ratified (31 Applicable / 290 Not Applicable /
  0 Not Yet Determined), public-review comments carried with provenance from
  the original component 46.
- After the release deploys, that component is **restored into prod from its
  JSON backup**, and the team authors, reviews, and adjudicates there.
- The companion human-facing deliverables (determination report, whitepaper,
  working-group deck) live in the private `mitre/container-srg-foundation`
  repo. That repo is a paper product of this effort — the system of record is
  Vulcan.

Anything not needed for the team to work that project correctly in prod slips
to a later PR or release.

## Merge order

### 1. CVE remediation — `fix/image-cve-refresh` → `master` (first)

Card `v2-g44e`, GitHub issue #743. Aaron's standing decision: a small
standalone effort against `master` so a **v2.3.8 patch** reaches the reporter
quickly — deliberately decoupled from the feature branch. Aaron cuts the
release. Worked in the `vulcan-cve-master` worktree.

After it merges, `feat/srg-authoring` takes a final master merge-up. Expect
Gemfile.lock / Dockerfile overlap: the feature branch already carries newer
pins for most of the flagged gems, so the merge-up is a best-of-breed
reconciliation, never a blind side-take.

### 2. The feature PR — `feat/srg-authoring`, PR #731 (the merge line)

Membership: **`bd list --label pr731`** — work cards only, epic containers
never carry the label. Staged 2026-08-11 to 23 open work cards, centered on
team-usable-prod:

- Docs epic capstone (.34.1.4 — the production image ships the docs build)
- The prod-import rehearsal (v2-0d2l.9 — backup component 122, restore into a
  scratch project, prove attribution and justifications survive)
- Kind-seam completion (33.x) — edit-safety on SRG components: spreadsheet
  guards, audit revert, picker routing, the enforcement cop, the final sweep
- Triage parity (32.x) — the team's comment-to-disposition workflow on
  SRG-kind components, ending in the full walkthrough proof
- Correctness and protection singles: structural array guards (.36),
  Rule→Requirement terminology (.37), kind-aware counts/search (.29),
  relocation landing lock (.42), the comments filter contract (.82), the
  skipped-test restore (k8jc)
- SRG authoring documentation the team onboards from (34.2, 34.4, 34.5)

Close-out is the locked merge checklist, run once at the end: full backend +
Vue suites, SonarCloud, Copilot review, security review, Will's review — then
the push and merge on Aaron's word.

### 3. Release, deploy, restore — the launch

1. Aaron cuts the release from merged master and deploys to prod.
2. **Restore the component-122 backup into prod** (the step v2-0d2l.9
   rehearsed; the final backup is cut at import time so it carries the
   then-current content).
3. The team works the project: authoring the container-authored requirement
   set (content ratified by Aaron — his open determination decisions are
   tracked in the foundation repo), review, adjudication, and the path to
   approval.

### 4. The follow-on PR — label `pr732` (after launch)

Membership: **`bd list --label pr732`** — 25 cards staged 2026-08-11. Branch
cut from merged master. Contents: XCCDF dual-version export (4y0w.2–.6 —
needed at approval time, not at launch), bulk-triage UX (05f.48/.79/.80),
reply threading (05f.60), v+1 intake (.44), component-chooser features
(.60/.61), the API journey walk (qce1.1), comment-system polish (the 05f
P2/P3 set), the payload-shrink optimization (uvoa.2), and the hierarchy
diagrams page (34.3).

Nothing here blocks the team; several items (bulk triage, XCCDF) become more
valuable once real prod usage informs them.

## Standing mechanics

- Stage membership is always the label query, re-derived — never a remembered
  count. Epic containers never carry stage labels.
- Post-merge docs cards (34.1.6, 34.1.11–.17) are unlabeled by design and
  follow at their own pace.
- This file is referenced from `.beads/session-handoff.md` and the board
  memories; when a stage changes, this file and the labels change together.
