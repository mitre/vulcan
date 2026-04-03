# Field Requirements by Status

This page documents DISA's field requirements for each rule status, as defined in the Vendor STIG Process Guide V4R1. These requirements govern what content is expected in the DISA spreadsheet submission.

## Requirements Matrix

| Field | AC | AIM | ADNM | NA | Guide Section |
|-------|:---:|:---:|:----:|:---:|--------------|
| Requirement (Title) | Required | Required | Required | Required | 4.1.6 |
| VulnDiscussion | Required | Required | Required | **Blank** | 4.1.8 |
| Status | Required | Required | Required | Required | 4.1.9 |
| Check | Required | **Blank** | **Blank** | **Blank** | 4.1.11 |
| Fix | Required | **Blank** | **Blank** | **Blank** | 4.1.13 |
| Severity | Required | Required | Required | **Blank** | 4.1.14 |
| Mitigation | — | — | **Required** | — | 4.1.15 |
| Artifact Description | — | **Required** | — | — | 4.1.16 |
| Status Justification | — | **Required** | **Required** | **Required** | 4.1.17 |

::: info Legend
- **Required** — Vendor must populate this field
- **Blank** — Field must be left empty in vendor submission
- **—** — Field is not applicable for this status
:::

## Field Details

### Requirement (Title) — Section 4.1.6

The STIG-specific requirement text. Must be concise and actionable.

**Writing conventions:**
- Use "must" (not "should")
- Use "must be configured to" (not "must be capable of" or "must have the capability to")
- State what the product must do, not what it must not do

### VulnDiscussion — Section 4.1.8

Explains why the requirement exists and the risk if not implemented.

- Required for AC, AIM, and ADNM
- **Blank for NA** — "NA requirements do not require a VulnDiscussion"
- Must not restate the requirement
- Should reference specific risks and attack vectors
- Satisfaction text ("Satisfies: SRG-...") is appended here in XCCDF exports

### Status — Section 4.1.9

One of four values: Applicable - Configurable, Applicable - Inherently Meets, Applicable - Does Not Meet, or Not Applicable.

::: warning
"Not Yet Determined" is NOT a DISA-recognized status. It is a Vulcan workflow status only.
:::

### Check Content — Section 4.1.11

Step-by-step instructions for an assessor to verify compliance.

- **Required for AC only** — "Complete this cell only for rows where the status is Applicable - Configurable. Leave it blank for all other status types."
- Must use action verbs: verify, navigate, identify, type, obtain, determine, check, ask
- Must include a finding statement: "If [condition], this is a finding."
- Must not use "should", "shall", or "please"
- Must not restate the requirement

#### Check Content Structure (Section 4.1.11.1)

Checks should follow this pattern:

1. **Action** — What to do (verify, navigate to, check)
2. **Expected result** — What compliant state looks like
3. **Finding statement** — "If [noncompliant condition], this is a finding."

### Fix Text — Section 4.1.13

Step-by-step instructions to bring a noncompliant system into compliance.

- **Required for AC only** — "Complete this cell only for rows where the status is Applicable - Configurable. Leave it blank for all other status types."
- Must use action verbs: ensure, configure, set, select
- Use numbered steps for multi-step procedures
- Must not use "should", "shall", or "please"
- Must not restate the requirement

### Severity — Section 4.1.14

Risk categorization using CAT I / CAT II / CAT III.

| Category | Internal Value | Impact |
|----------|---------------|--------|
| CAT I | `high` | Direct and immediate threat to DoD assets |
| CAT II | `medium` | Potential to degrade security posture |
| CAT III | `low` | Degrades defense-in-depth measures |

- Required for AC, AIM, and ADNM
- **Blank for NA** — "NA requirements do not require a severity"
- For ADNM: severity must reflect risk **BEFORE any mitigation** — "The severity selection for requirements deemed Applicable - Does Not Meet must reflect the severity BEFORE any mitigation steps are taken by an organization."
- Vendor may adjust severity from SRG default with justification (Severity Override Guidance)

### Mitigation — Section 4.1.15

**Required for ADNM only.** Describes how the vulnerability can be mitigated despite the product's inability to meet the requirement.

Cross-STIG mitigation examples:
- "This requirement is fully mitigated by the Apache Server 2.4 Windows Server STIG. (AS24-W1-000280)"
- "This requirement is fully mitigated by the underlying operating system. (WN16-SO-000430)"

### Artifact Description — Section 4.1.16

**Required for AIM only.** Describes what evidence supports the claim that the product inherently meets the requirement.

DISA requires supporting documents for AIM claims:
1. **Published Manual** — Cited reference showing requirement is met by default and cannot be changed
2. **Test Report** — Independent verification with proper software version
3. **Letter of Attestation** — For AIM items without other supporting evidence (template available from DISA)

### Status Justification — Section 4.1.17

**Required for AIM, ADNM, and NA.** Explains why the selected status was chosen.

Must provide clear rationale:
- For AIM: Why the product inherently meets the requirement
- For ADNM: Why no technical means exist to meet the requirement
- For NA: Why the requirement doesn't apply to this product/technology

## DISA Spreadsheet Columns

The official DISA STIG template has exactly **17 columns** (Section 8, Table 8-1):

| # | Column | Prepopulated | Vendor Fills |
|---|--------|:---:|:---:|
| 1 | IA Control | Yes | — |
| 2 | CCI | Yes | — |
| 3 | SRGID | Yes | — |
| 4 | STIGID | — | DISA fills during finalization |
| 5 | SRG Requirement | Yes | — |
| 6 | Requirement | — | Yes |
| 7 | SRG VulDiscussion | Yes | — |
| 8 | VulDiscussion | — | Yes |
| 9 | Status | — | Yes |
| 10 | SRG Check | Yes | — |
| 11 | Check | — | Yes (AC only) |
| 12 | SRG Fix | Yes | — |
| 13 | Fix | — | Yes (AC only) |
| 14 | Severity | Prepopulated, vendor adjusts | Yes |
| 15 | Mitigation | — | Yes (ADNM only) |
| 16 | Artifact Description | — | Yes (AIM only) |
| 17 | Status Justification | — | Yes (AIM, ADNM, NA) |

::: tip
Fields marked as "prepopulated" come from the SRG and should not be changed by the vendor. The STIGID field is populated by DISA during finalization — vendors leave it blank.
:::

## Formatting Requirements

From Section 4 of the Process Guide:

> "In the spreadsheet, please do not use any enhanced formatting features such as bold, italics, strikethrough, different fonts, or smart (curly) quotes."

- Plain text only — no rich formatting
- Standard (straight) quotes only
- No special characters or Unicode formatting

## Vulcan Implementation Notes

### Current STATUS_FIELD_CONFIG Alignment

Vulcan's `ruleFieldConfig.js` implements field visibility per status. Cross-reference with this matrix:

| DISA Requirement | Vulcan Implementation | Status |
|---|---|---|
| Check/Fix blank for non-AC | Fields hidden for AIM, ADNM, NA | Correct |
| Severity blank for NA | Severity shown but disabled for NA | Needs review |
| VulnDiscussion blank for NA | Not currently enforced | Gap |
| Mitigation required for ADNM | Shown with toggle for ADNM | Correct |
| Artifact Description for AIM | Shown for AIM | Correct |
| Status Justification for AIM/ADNM/NA | Shown for all three | Correct |

### DISA Export vs Vendor Submission

Vulcan's current DISA Excel export adds boilerplate Check/Fix text for non-AC statuses (e.g., "The technology supports this requirement and cannot be configured to be out of compliance..."). Per the Process Guide, these fields should be **blank** in vendor submissions. DISA adds this text during finalization.

::: warning Current limitation
Users submitting to DISA should verify that Check/Fix fields are blank for non-AC statuses before submission, as Vulcan currently populates them with boilerplate text.
:::
