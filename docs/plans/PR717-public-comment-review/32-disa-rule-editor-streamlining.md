# Task 32: DISA-compliant rule editor streamlining

**Status:** placed at end of task list — likely a follow-up phase, not PR-717. Captures
streamlining opportunities surfaced by the DISA Vendor STIG Process Guide v4r1 that go
beyond the inheritance flow handled in Task 31.

**Applies universally** — every STIG type benefits. Not application-specific or
container-specific.

**Depends on:** Task 31 (defines the inheritance side of the field contract). Task 32
extends the same status-driven approach to all four statuses for every rule edit.

**Estimate:** ~4-6 hr Claude-pace, splittable across multiple sub-tasks.

## Why this task exists

Today the rule editor shows the same set of fields regardless of selected status. DISA's
process prescribes a rigid contract per status (§4.1.11, §4.1.13, §4.1.14, §4.1.15,
§4.1.16, §4.1.17). Authors have to memorize the rules or re-read the PDF every time.
DISA review (§5) catches these mistakes after the fact.

**The fix is:** make the status selection drive the field contract by construction —
fields appear/disappear/become required as the author picks the status. Author can't
produce a non-DISA-compliant rule because the form won't let them.

## The status-driven field contract (§4.1.11–4.1.17)

| Status | Required fields | Hidden / blank fields |
|---|---|---|
| **Applicable – Configurable** | Check, Fix, Severity, VulDiscussion | (no Status Justification needed) |
| **Applicable – Inherently Meets** | Artifact Description, Status Justification, Severity, VulDiscussion | Check BLANK, Fix BLANK |
| **Applicable – Does Not Meet** | Mitigation, Status Justification, Severity (pre-mitigation), VulDiscussion | Check BLANK, Fix BLANK |
| **Not Applicable** | Status Justification | Check BLANK, Fix BLANK, Severity NOT REQUIRED, VulDiscussion NOT REQUIRED |

## Streamlining items in scope

### A. Status-driven field show/hide/require contract

Apply the table above to every rule edit. Form fields appear, disappear, and become
required based on the selected status. Validators on Rule mirror the contract so
backend rejects malformed saves regardless of UI state.

### B. Public-publish vs CUI badge (§6)

> "STIG (Applicable – Configurable requirements) … is publicly available on the Cyber
> Exchange website. STIG requirements (Not Applicable, Applicable – Inherently Meets,
> or Applicable – Does Not Meet) … are made available to Authorizing Officials upon
> request because the data is considered Controlled Unclassified Information (CUI)."

Each rule shows a badge:
- **"Will publish"** (green) — `Applicable – Configurable`
- **"CUI only"** (yellow) — IM / DNM / NA

Especially valuable for PR-717 commenters: a commenter wondering "will my comment
make it into the released STIG?" gets a clear visual answer per rule.

### C. "Add Best-Practice Rule" button (§4.2.1)

> "If the vendor recommends specific configuration settings as a security best
> practice, use CCI-000366 to include that information."

Button on the rule list: **"Add Best-Practice Rule"** → opens a rule creation form
with `CCI-000366` prefilled, no SRG link required, status defaulted to `Applicable –
Configurable`. The author writes Requirement / Check / Fix and saves.

### D. CCI-driven inheritance candidate suggestions (§4.1.2)

> "The Control Correlation Identifier (CCI) enables DOD organizations to trace STIG
> compliance to IA controls specified by NIST."

When an author marks a rule as inherited (Task 31), the picker queries for rules
with the same CCI across other components and projects, surfacing them at the top
of the candidate list. Two rules sharing a CCI address the same NIST 800-53 control
— that's a strong signal of inheritance compatibility.

### E. Requirement / Check / Fix text linters

DISA prescribes specific verb choices and forbids others:

**§4.1.6 Requirement:**
- Use "must" not "should" / "shall" / "please"
- Use "must be configured to" not "must be capable of"

**§4.1.11.1 Check Writing Style:**
- Use action verbs (verify, navigate, identify, type, obtain)
- Don't use "should" / "shall" / "please"
- Include a "finding" statement: `"If…, this is a finding."`

**§4.1.13.1 Fix Writing Style:**
- Use action verbs (ensure, configure, set, select)
- Don't use "should" / "shall" / "please"
- No "finding" statement in the Fix

Implement as soft warnings in the rule editor: yellow flag on offending text with a
tooltip linking to the relevant PDF section. Doesn't block save; nudges toward
DISA-compliant phrasing.

### F. Stage-1 readiness widget (§3.2)

> "Within two weeks, the vendor returns the STIG template to DISA with 10 requirements
> completed. This must be a mix of all statuses: Applicable – Configurable, Applicable
> – Inherently Meets, Applicable – Does Not Meet, and Not Applicable."

A small widget on the component page during early authoring: "Stage 1 readiness — you
have X Configurable / Y IM / Z DNM / W NA across N completed requirements (target: 10
with mix of all)." Helps authors understand DISA's expectation that the first 10 should
demonstrate all four disposition types.

### G. Letter-of-Attestation prompt (§5.4.3)

> "A Letter of Attestation is required for any items that have a status of Applicable –
> Inherently Meets but for which supporting evidence is not documented."

When status = IM and Artifact Description is empty (or only contains attestation
language), surface a prompt: "Letter of Attestation required — see DISA §5.4.3."

### H. Severity-hide for NA (§4.1.14)

> "Requirements evaluated to be Not Applicable do not require a severity."

Severity field hidden/disabled when status = NA. Removes a meaningless input.

### I. SRG-prepopulated fields visibly read-only (§4.1)

Fields marked with asterisks (\*) in the doc come from the parent SRG and must not be
edited: IA Control, CCI, SRGID, SRG Requirement, SRG VulDiscussion, SRG Check, SRG Fix.

Render these visibly read-only with "From parent SRG" tooltip. (Vulcan likely already
does this for some fields — verify against current rule editor.)

## TDD breakdown (when this lands)

| # | Sub-task | Est | Notes |
|---|---|---|---|
| A1 | Per-status field contract validators on Rule model | 30m | Backend authoritative; UI mirrors |
| A2 | Rule editor form: status-driven show/hide/require | 60m | Touches every rule form |
| B  | Public/CUI badge on rule list, editor, commenter view | 30m | Cross-cuts |
| C  | Best-practice rule pattern + CCI-000366 | 30m | New button + form |
| D  | CCI candidate suggestions in inheritance picker (Task 31) | 60m | Requires CCI index |
| E  | Text linters on Requirement/Check/Fix | 45m | Soft warnings, not blocking |
| F  | Stage-1 readiness widget | 30m | Nice-to-have |
| G  | Letter-of-Attestation prompt | 15m | Tiny |
| H  | Severity hide for NA | 10m | Tiny |
| I  | SRG-prepop read-only audit + fix | 30m | Verify current state first |

**Total ~5 hr Claude-pace** if all done at once. Cuttable: F, G are nice-to-have. D
requires a CCI index that doesn't exist yet — could be its own task.

## Acceptance criteria

- [ ] Rule with status=Configurable + blank Check is invalid
- [ ] Rule with status=Configurable + blank Fix is invalid
- [ ] Rule with status=IM + blank Artifact Description is invalid
- [ ] Rule with status=DNM + blank Mitigation is invalid
- [ ] Rule with status=DNM + blank Status Justification is invalid
- [ ] Rule with status=NA + blank Status Justification is invalid
- [ ] Rule with status=NA does not display Severity field
- [ ] UI hides Check/Fix when status != Configurable
- [ ] Public/CUI badge renders correctly per status across rule list, editor, commenter view
- [ ] Best-Practice Rule button creates a CCI-000366 rule
- [ ] Inheritance picker surfaces same-CCI candidates first
- [ ] Linter warnings appear for "should/shall/please/capable of" text
- [ ] Stage-1 widget renders correct counts
- [ ] LoA prompt appears for IM with no evidence
- [ ] SRG-prepop fields are visibly read-only with tooltip

## Reference

- DISA Vendor STIG Process Guide v4r1
  (`downloads/U_Vendor_STIG_Process_Guide_V4R1_20220815.pdf`)
- §3.2 (Stage 1 readiness — mix of statuses)
- §4.1 (SRG-prepopulated fields)
- §4.1.2 (CCI traceability)
- §4.1.6 (Requirement verb rules)
- §4.1.11 + §4.1.11.1 (Check, blank-when-non-Configurable + writing style)
- §4.1.13 + §4.1.13.1 (Fix, same)
- §4.1.14 (Severity, hide when NA, pre-mitigation when DNM)
- §4.1.15 (Mitigation, summary statement templates)
- §4.1.16 (Artifact Description, IM-required)
- §4.1.17 (Status Justification, per-status guidance)
- §4.2.1 (Best-practice rules with CCI-000366)
- §5.4.3 (Letter of Attestation for IM-without-evidence)
- §6 (Public vs CUI publication split)
