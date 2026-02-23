# Input Length Limits

All text fields in Vulcan enforce maximum lengths to prevent abuse and protect downstream consumers (Excel export, API responses, PDF generation).

## BaseRule Fields (base_rules table)

| Field | Type | Max Length | Rationale |
|---|---|---|---|
| `rule_id` | string | 255 | Identifier |
| `rule_weight` | string | 255 | Numeric string |
| `version` | string | 255 | Version identifier |
| `ident_system` | string | 255 | URI |
| `fixtext_fixref` | string | 255 | Reference ID |
| `fix_id` | string | 255 | Reference ID |
| `srg_id` | string | 255 | Identifier |
| `vuln_id` | string | 255 | Identifier |
| `legacy_ids` | string | 255 | Comma-separated IDs |
| `ident` | string | 2,048 | Comma-joined CCI list (real STIGs have 310+ chars) |
| `title` | text | 1,000 | Rule title |
| `status_justification` | text | 1,000 | Brief justification |
| `fixtext` | text | 10,000 | Fix instructions |
| `artifact_description` | text | 10,000 | Artifact details |
| `vendor_comments` | text | 10,000 | Vendor notes |
| `inspec_control_body` | text | 50,000 | InSpec Ruby code |
| `inspec_control_file` | text | 50,000 | InSpec file content |

**Not length-validated** (constrained by inclusion validation):
- `rule_severity` — only `low`, `medium`, `high`, or empty string
- `status` — only values in `RuleConstants::STATUSES`

## DisaRuleDescription Fields (disa_rule_descriptions table)

| Field | Max Length | Rationale |
|---|---|---|
| `vuln_discussion` | 10,000 | DISA vulnerability discussion |
| `false_positives` | 10,000 | False positive notes |
| `false_negatives` | 10,000 | False negative notes |
| `mitigations` | 10,000 | Mitigation description |
| `severity_override_guidance` | 10,000 | Override guidance |
| `potential_impacts` | 10,000 | Impact description |
| `third_party_tools` | 10,000 | Tool references |
| `mitigation_control` | 10,000 | Control description |
| `responsibility` | 10,000 | Responsibility assignment |
| `ia_controls` | 10,000 | IA control references |
| `poam` | 10,000 | Plan of Action & Milestones |

## Check Fields (checks table)

| Field | Max Length | Rationale |
|---|---|---|
| `system` | 255 | Check system identifier |
| `content_ref_name` | 255 | Reference name |
| `content_ref_href` | 255 | Reference URL |
| `content` | 10,000 | Check content (verification steps) |

## Component Fields (components table)

| Field | Max Length | Rationale |
|---|---|---|
| `name` | 255 | Component name |
| `prefix` | 10 | STIG ID prefix |
| `title` | 500 | Component title |
| `description` | 5,000 | Component description |

## Project Fields (projects table)

| Field | Max Length | Rationale |
|---|---|---|
| `name` | 255 | Project name |
| `description` | 5,000 | Project description |

## Upload Limits

| Endpoint | Max Size | Allowed Types |
|---|---|---|
| STIG upload (XML) | 50 MB | `.xml` |
| SRG upload (XML) | 50 MB | `.xml` |
| Spreadsheet import | 50 MB | `.xlsx`, `.csv` |
| JSON Archive import | 100 MB | `.zip` |

## Error Behavior

When a length validation fails:
- **Direct model save**: `ActiveRecord::RecordInvalid` with message like "Title is too long (maximum is 1000 characters)"
- **STIG/SRG XML import**: Error includes rule ID and specific field: "3 rules failed to import: SV-12345: Title is too long (maximum is 1000 characters)"
- **Spreadsheet import**: Validation errors surface per-rule in the preview modal
- **API responses**: 422 with `errors.full_messages` array

## Design Decisions

- Limits based on analysis of real DISA STIG/SRG content (RHEL 9 V2R7: max ident=310, vuln_discussion=2905, check_content=2367, fixtext=1756)
- `ident` gets 2,048 (not 255) because it's a comma-joined CCI list that grows with rule scope
- InSpec fields get 50,000 because generated control code can be substantial
- All limits use `allow_nil: true` to avoid breaking existing nil-valued records
