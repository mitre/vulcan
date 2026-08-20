# PR #731 Expert Review Report — 2026-05-23

## Reviewing Agents
1. Vue Architecture + DRY (completed)
2. Security + Rails (completed — clean)
3. Test Coverage + Quality (completed)
4. CSS + Accessibility (completed)

## Bug
1. RuleContextPanel.vue:218 — `indexOf ?? 999` nullish coalescing doesn't catch -1

## Dead Code
2. RuleContextPanel.vue:173-174 — Props sectionComments, activeCommentId unused
3. TriageQueueNav.vue:240 — Computed pendingCount unused
4. ComponentTriagePage.vue:72 — Computed isAdmin unused
5. ComponentTriagePage.vue:62 — Prop currentUserId unused
6. ComponentComments.vue:504 — Method onSearchResultSelected superseded
7. TriageSplitView.vue:270 — Prop adminPanelOpen never read
8. TriageRuleSidebar.vue.broken-grouping-attempt — stale file

## DRY
9. Rule-grouping logic duplicated 3x (Sidebar, Nav, ByRule)
10. Active-item CSS duplicated (Sidebar, Nav)

## Performance
11. TriageQueueNav.vue:108 — flatIndexOf in v-for = O(n²)
12. TriageQueueNav.vue:322 — flatBrowseComments should be computed

## WCAG
13. Sidebar/Nav active text rgba(255,255,255,0.75) on primary = 2.1:1 FAILS AA
14. RuleContextPanel opacity:0.7 + text-muted on preview = 3.2:1 FAILS AA
15. TriageQueueNav browse items role="button" inside role="listbox" = invalid ARIA

## Accessibility
16. RuleContextPanel collapsible sections missing aria-label
17. TriageQueueNav position counter needs aria-live="polite"
18. Sidebar + Nav listboxes missing aria-label

## Code Quality
19. CommentsByRule collapsed data stores expanded state (inverted)
20. TriageSplitView calc(100vh-320px) magic number
21. TriageQueueNav z-index:1050 conflicts with modal layer
22. 3 files hardcode #0056b3

## Test Gaps
23. RuleContextPanel spec passes Set not Array for commentedSections
24. TriageSplitView doSave response_comment/duplicate untested
25. TriageSplitView admin move-to-rule/restore untested
26. ComponentComments viewParentComments/exitSplitMode/etc untested
27. TriageQueueNav browse keyboard nav untested
28. TriageRuleSidebar collapse/empty array untested
