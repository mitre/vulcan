# DISA Vendor STIG Process

Overview of the DISA Security Technical Implementation Guide (STIG) development process and how Vulcan supports each stage.

## Process Timeline

The DISA Vendor STIG process follows a defined sequence:

```
Intent Form → DISA Approval → Questionnaire → SRG Template → Authoring → Review → Publication
```

### Step 0: Intent Form

The vendor submits a **Vendor STIG Intent Form** to DISA (`disa.stig_spt@mail.mil`) declaring intent to create a STIG. This form captures:

- Vendor and sponsor contact information
- Product name, version, and description
- Technology layers (OS, web server, database, cloud, virtual)
- DoD deployment scope and sponsor organization

DISA reviews internally and notifies the vendor whether to proceed.

**Source:** [U_Vendor_STIG_Intent_Form.pdf](attachments/U_Vendor_STIG_Intent_Form.pdf)

### Step 1: STIG Applicability Questionnaire

The vendor completes a questionnaire with ~50+ technology category checkboxes. DISA uses the answers to determine which SRGs (Security Requirements Guides) apply to the product.

A single product may require multiple SRGs. For example, a web application running on Linux with a PostgreSQL database would need:
- General Purpose OS SRG (GPOS)
- Web Server SRG
- Database SRG

Each SRG becomes a separate **Component** in Vulcan.

**Source:** STIG_Questionnaire-Released-Nov-2017.pdf (V4.3) — available from [DISA Vendor Process page](https://public.cyber.mil/stigs/) (requires CAC)

### Stage 1: SRG Template (2 weeks)

DISA provides the SRG spreadsheet template to the vendor. The vendor submits 10 requirements with a mix of all four statuses (AC, AIM, ADNM, NA) for DISA's initial review.

### Stage 2: Work-in-Progress (+30 days)

Vendor submits work-in-progress spreadsheet for DISA review.

### Stage 3: Work-in-Progress (+60 days)

Second work-in-progress submission.

### Stage 4: Initial Draft (+90 days)

Vendor submits completed initial draft.

### Review and Publication

After the vendor completes development:

1. **STIG Review** — DISA SME reviews completeness and rationale
2. **Transition** — Package handed to Technology SME
3. **STIG Simulation** — Technology SME validates Check/Fix on actual product
4. **Review of Vendor Documents** — Published Manual, Test Report, Letter of Attestation
5. **Style Guide Review** — DISA editorial review
6. **Decision Brief** — Presented to DISA Authorizing Official
7. **AO Approval** — STIG approved
8. **Publication** — Two outputs:
   - **Public STIG**: Only Applicable - Configurable rules (published on Cyber Exchange)
   - **Confidential package (CUI)**: NA, AIM, ADNM rules with compliance report (available to Authorizing Officials upon request)

**Source:** U_Vendor_STIG_Process_Guide_V4R1_20220815.pdf, Sections 3 and 5-6 — available from [DISA Vendor Process page](https://public.cyber.mil/stigs/) (requires CAC)

## Rule Statuses

DISA defines exactly four statuses for STIG requirements:

| Status | Code | Description |
|--------|------|-------------|
| Applicable - Configurable | AC | Product requires configuration to achieve compliance |
| Applicable - Inherently Meets | AIM | Product is compliant by default and cannot be reconfigured to noncompliant |
| Applicable - Does Not Meet | ADNM | No technical means to achieve compliance |
| Not Applicable | NA | Requirement addresses a capability the product does not support |

::: warning
"Not Yet Determined" (NYD) is a Vulcan workflow status, NOT a DISA-recognized status. NYD rules should not appear in exports submitted to DISA.
:::

## SRG-to-STIG Mapping

The relationship between SRG requirements and STIG rules is **one-to-many**: a single SRG requirement can map to multiple STIG rules/rows.

From the Process Guide (Section 4.2):
> "In some cases, multiple configuration settings may be needed to achieve compliance with a single requirement."

Each additional row copies the SRG fields (IA Control, CCI, SRG ID, SRG Requirement, SRG VulDiscussion, SRG Check, SRG Fix) verbatim from the original requirement.

### Satisfies Relationships

When one STIG rule covers multiple SRG requirements, the satisfaction relationship is documented in the **VulnDiscussion** field (e.g., "Satisfies: SRG-OS-000480-GPOS-00227, SRG-OS-000123-GPOS-00456").

Rules that are "satisfied by" another rule are excluded from the public STIG XCCDF but included in the DISA spreadsheet submission.

### CCI-000366: Security Best Practices

For security features that don't align with any SRG requirement, use CCI-000366 to include vendor-recommended configuration settings as security best practices (Section 4.2.1).

## How Vulcan Maps to the Process

| DISA Concept | Vulcan Concept |
|---|---|
| Product being STIGged | Project |
| Technology layer (OS, Web, DB) | Component |
| SRG requirement | SRG Rule |
| STIG rule/row in spreadsheet | Rule |
| Vendor submission (spreadsheet) | DISA Excel export |
| Published STIG (XCCDF) | XCCDF export |

## Reference Documents

| Document | Version | Description |
|---|---|---|
| Vendor STIG Process Guide | V4R1 (2022-08-15) | Full process lifecycle, field requirements, review stages |
| STIG Applicability Questionnaire | V4.3 (2017-11) | Determines which SRGs apply to a product |
| Vendor STIG Intent Form | Current | Initial declaration of intent to create a STIG |

These documents are available from DISA and stored in the project's `downloads/` directory for reference.
