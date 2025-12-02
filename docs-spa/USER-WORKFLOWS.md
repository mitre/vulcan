# User Workflows & UX Design

## Document Purpose
Captures user workflow insights from Session 19 discovery. Use this to guide UX decisions as we complete the Vue 3 migration and plan future features.

---

## User Roles & Primary Tasks

| Role | Primary Task | Frequency |
|------|--------------|-----------|
| **Author** | Edit requirements one-by-one | Daily, bulk of work |
| **Reviewer** | Review → Approve/Request Changes | As needed |
| **Admin** | Team management, releases | Occasional |

---

## Entry Points

**Typical flow (80-90% of users):**
```
Login → Their Project → Their Component → Requirements Editor
```

**Power users / DISA managers:**
- May want cross-project status visibility
- Need to see pending reviews/approvals across projects

---

## Author Workflow

### Key Insights
1. **One requirement at a time** - 95% use case
2. **Reuse and adapt** is CENTRAL - Related Requirements is a power feature
3. Users usually know where they left off
4. May need to know about pending reviews/requests from team

### Reference STIGs Feature (Future)

When creating/configuring a component, attach "Reference STIGs" - similar STIGs that should be prioritized in Related Requirements searches.

**Configuration:**
- Set during component creation
- Editable anytime from component settings
- Ordered list (position = priority)
- Typically 2-5 references

**Smart Suggestions:**
- Same product family (RHEL 10 → suggest RHEL 9, 8)
- Most current version/release wins (V2R1 > V1R2)
- 80-90% accuracy target - user can override

**Priority in Related Requirements:**
```
1. Primary Reference (e.g., RHEL 9 for RHEL 10 work)
2. Secondary References (e.g., RHEL 8, Ubuntu)
3. Other matches (general OS, less relevant)
```

---

## Reviewer Workflow

### Key Insights
1. Need a **list of pending reviews** on dashboard for quick access
2. Review one at a time (not batch)
3. Need requirement context + related examples
4. Flow: Click → Review → Back → Click → Review → Back

---

## Admin Workflow

### Key Insights
1. Team management is infrequent (team is usually stable)
2. **Join requests** should surface prominently (don't get lost)
3. Component settings (metadata, additional questions) - one-time setup
4. Release triggered when reviewer has locked all requirements
5. Admin "pushes the button" for release

---

## Cross-Component Work

### Key Insights
1. Comparing requirements across STIGs is **core functionality**
2. "View Related Requirements" enables reuse and adaptation
3. 100s of vetted, peer-reviewed examples exist - leverage them
4. Progress visibility at component level is important

---

## Pain Points (Current UI)

| Issue | Notes |
|-------|-------|
| Project join requests | Hard to find, can get lost |
| Component progress/status | Not visible enough |
| Notifications | Reviews, changes, requests should surface everywhere |

---

## Proposed Page Structure

```
/projects                      → Project list (with notifications badge)

/projects/:id                  → Project dashboard
                                  - Components list with progress
                                  - Team members
                                  - Join requests

/components/:id                → Component workspace (THE main work surface)
                                  - Requirements editor (Table/Focus modes)
                                  - Settings accessible via sidebar/modal
                                  - Reference STIGs configuration
                                  - Progress indicator visible
```

**Key Decision:** `/components/:id` IS the editor, not a landing page. Users go there to work.

---

## Notifications to Surface

**On Dashboard/Landing:**
- Review requests (for reviewers)
- Change requests (for authors)
- Join requests (for admins)
- Quick link to active component

**Everywhere:**
- Badge indicators for pending items
- Easy navigation back to notification source

---

## Design Principles

1. **Reuse and Adapt** - Make related requirements easily accessible
2. **One at a time** - Optimize for focused single-requirement work
3. **Don't lose requests** - Surface notifications prominently
4. **Progress visibility** - Show component completion status
5. **Minimal clicks** - Direct paths to common actions

---

## Implementation Notes

### Immediate (Vue 3 Migration)
- `/components/:id` becomes the requirements editor
- Old ProjectComponent.vue functionality moves to settings panel/modal
- Focus on completing current migration before new features

### Future (Post-Migration)
- Reference STIGs feature (requires DB changes)
- Dashboard with cross-project notifications
- Smart suggestions for reference STIG selection
- Progress indicators throughout

---

*Document created: Session 19, 2025-11-29*
*Based on user workflow discovery conversation*
