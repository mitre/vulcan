# Rule Form Business Rules

This document defines the field visibility, editability, and dynamic behavior rules for the Rule Editor form. These rules are implemented in `app/javascript/composables/ruleFieldConfig.js` and enforced by the `useRuleFormFields` composable.

## Status-Based Field Visibility

Each rule has a **status** that determines which fields are visible and editable. There are five statuses:

### Applicable - Configurable

The product requires configuration to achieve compliance. This is the primary authoring workflow.

**Basic Mode:**

| Field | Visible | Editable |
|-------|---------|----------|
| Status | Yes | Yes |
| Severity | Yes | Yes |
| Title | Yes | Yes |
| Fix | Yes | Yes |
| Vulnerability Discussion | Yes | Yes |
| Check | Yes | Yes |
| Vendor Comments | Yes | Yes |
| IA Control | Yes | Read-only |
| CCI | Yes | Read-only |

**Advanced Mode adds:**

| Field | Section |
|-------|---------|
| Status Justification | Rule |
| Version | Rule |
| Rule Weight | Rule |
| Artifact Description | Rule |
| Fix ID | Rule |
| Fix Text Reference | Rule |
| Identity | Rule |
| Identity System | Rule |
| Documentable | DISA (collapsible) |
| False Positives | DISA (collapsible) |
| False Negatives | DISA (collapsible) |
| Mitigations Available | DISA (collapsible) |
| Mitigations | DISA (collapsible) |
| POA&M Available | DISA (collapsible) |
| POA&M | DISA (collapsible) |
| Potential Impacts | DISA (collapsible) |
| Third Party Tools | DISA (collapsible) |
| Mitigation Control | DISA (collapsible) |
| Responsibility | DISA (collapsible) |
| IA Controls (DISA) | DISA (collapsible) |

Advanced mode renders DISA and Checks in **collapsible sections** with headings.

### Not Yet Determined

The rule has not been evaluated yet. Fields show SRG boilerplate content as read-only context to help the author determine applicability.

| Field | Visible | Editable |
|-------|---------|----------|
| Status | Yes | Yes |
| Severity | Yes | Disabled |
| Title | Yes | Disabled |
| Fix | Yes | Disabled |
| Vulnerability Discussion | Yes | Disabled |
| Check | Yes | Disabled |
| IA Control | Yes | Read-only |
| CCI | Yes | Read-only |

Advanced mode does **not** add additional fields. Fields remain inline (no collapsible sections).

### Applicable - Inherently Meets

The product is compliant in its initial state and cannot be reconfigured to a noncompliant state.

| Field | Visible | Editable |
|-------|---------|----------|
| Status | Yes | Yes |
| Severity | Yes | Yes |
| Status Justification | Yes | Yes |
| Artifact Description | Yes | Yes |
| Vendor Comments | Yes | Yes |
| IA Control | Yes | Read-only |
| CCI | Yes | Read-only |

No DISA or Check fields. Advanced mode does not add fields.

### Applicable - Does Not Meet

There are no technical means to achieve compliance.

**Basic Mode:**

| Field | Visible | Editable |
|-------|---------|----------|
| Status | Yes | Yes |
| Severity | Yes | Yes |
| Status Justification | Yes | Yes |
| Vendor Comments | Yes | Yes |
| Mitigations Available | Yes | Yes |
| Mitigations | When Mitigations Available ON | Yes |
| Mitigation Control | When Mitigations Available ON | Yes |
| POA&M Available | When Mitigations Available OFF | Yes |
| POA&M | When POA&M Available ON (and Mitigations OFF) | Yes |
| IA Control | Yes | Read-only |
| CCI | Yes | Read-only |

**Advanced Mode adds** (in collapsible DISA section):

Documentable, False Positives, False Negatives, Potential Impacts, Third Party Tools, Responsibility, IA Controls (DISA).

### Not Applicable

The requirement addresses a capability or use case the product does not support.

| Field | Visible | Editable |
|-------|---------|----------|
| Status | Yes | Yes |
| Severity | Yes | Disabled |
| Status Justification | Yes | Yes |
| Artifact Description | Yes | Yes |
| Vendor Comments | Yes | Yes |
| IA Control | Yes | Read-only |
| CCI | Yes | Read-only |

No DISA or Check fields. Advanced mode does not add fields.

## Dynamic Behaviors

### Severity Override Guidance

When the author changes the severity from the SRG default value, a **Severity Override Guidance** field appears between the Severity and Title fields. This field is required to explain why the severity was changed.

- **Appears when**: `rule.rule_severity !== rule.srg_rule_attributes.rule_severity`
- **Applicable statuses**: Configurable, Inherently Meets, Does Not Meet
- **Not shown for**: Not Applicable, Not Yet Determined (severity is disabled on these)
- **Data binding**: `rule.disa_rule_descriptions_attributes[0].severity_override_guidance`

### Satisfied By

When a rule is satisfied by another rule (`rule.satisfied_by.length > 0`):

- The effective status is forced to **Configurable** regardless of the actual status
- The Configurable field set is used
- **Only `title` and `fixtext` are disabled** (content comes from the satisfying rule)
- The rest of the form remains editable (severity, vendor_comments, etc.)
- The entire form is **NOT** disabled

### Collapsible Sections

In advanced mode, DISA and Checks fields are rendered in collapsible sections **only when the status has advanced field additions**:

- **Configurable**: Collapsible sections (has 12+ advanced DISA fields)
- **Does Not Meet**: Collapsible sections (has 7 advanced DISA fields)
- **NYD, Inherently Meets, Not Applicable**: Fields stay inline (no advanced additions)

### IA Control and CCI

These reference fields are **always visible** for all statuses and both modes. They are read-only and display the NIST control family (e.g., "AC-2") and Common Control Indicator (e.g., "CCI-000015") mapped to the requirement.

### Mitigations / POA&M Toggle Pattern

The `Mitigations Available` and `POA&M Available` fields are mutually exclusive (XOR) toggle switches with cascading visibility:

**Mitigations Available toggle:**
- Always visible when in the displayed field list
- When ON: shows `Mitigations` textarea and `Mitigation Control` field
- When ON: hides `POA&M Available` toggle (and its dependent `POA&M` textarea)

**POA&M Available toggle:**
- Only visible when `Mitigations Available` is OFF
- When ON: shows `POA&M` textarea

**Conditional fields:**
| Field | Shows when |
|-------|-----------|
| Mitigations | `mitigations_available` is ON |
| Mitigation Control | `mitigations_available` is ON |
| POA&M Available toggle | `mitigations_available` is OFF |
| POA&M | `poam_available` is ON AND `mitigations_available` is OFF |

**Always-visible fields** (not toggle-dependent):
Potential Impacts, Third Party Tools, Responsibility, IA Controls, Severity Override Guidance

This XOR pattern ensures a rule has either a mitigation OR a POA&M, never both simultaneously. If data inconsistency occurs (both flags true), the mitigations path takes precedence and POA&M fields are hidden.

## Form-Level Disabled States

The entire form is disabled when any of these conditions are true:

- `rule.locked === true` (rule has been locked by an admin)
- `rule.review_requestor_id !== null` (rule is under review)
- `readOnly === true` (viewer-only access)

## Advanced Fields Toggle

The Advanced Fields toggle is a component-level setting (not per-rule). When enabled:

1. A confirmation dialog warns that most users do not need advanced fields
2. The setting is persisted to the server via PATCH
3. The toggle state is tracked locally (not via prop mutation) for Vue 2 slot reactivity

## Configuration Source

All field visibility rules are defined in a single configuration object in `app/javascript/composables/ruleFieldConfig.js`. The `useRuleFormFields` composable reads this config and applies dynamic logic (severity override, satisfied_by).

```
STATUS_FIELD_CONFIG[status].rule  → { displayed, disabled, advancedDisplayed, advancedDisabled }
STATUS_FIELD_CONFIG[status].disa  → { displayed, disabled, advancedDisplayed, advancedDisabled }
STATUS_FIELD_CONFIG[status].check → { displayed, disabled }
```
