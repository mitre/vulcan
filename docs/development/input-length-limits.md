# Input Length Limits

All text fields in Vulcan enforce configurable maximum lengths via `Settings.input_limits`.
Limits are set in `config/vulcan.default.yml` with environment variable overrides so
administrators can tune per deployment.

## Configuration

Limits are grouped by category. Each has a `VULCAN_LIMIT_*` environment variable:

| Setting Key | Env Var | Default | Description |
|---|---|---|---|
| `short_string` | `VULCAN_LIMIT_SHORT_STRING` | 255 | IDs, version strings, reference fields |
| `ident` | `VULCAN_LIMIT_IDENT` | 2,048 | Comma-joined CCI list (real max: 310) |
| `title` | `VULCAN_LIMIT_TITLE` | 500 | Rule titles (real max: 436) |
| `medium_text` | `VULCAN_LIMIT_MEDIUM_TEXT` | 1,000 | Status justification, brief text |
| `long_text` | `VULCAN_LIMIT_LONG_TEXT` | 10,000 | Descriptions, check content, fixtext (real max: 6,330) |
| `inspec_code` | `VULCAN_LIMIT_INSPEC_CODE` | 50,000 | InSpec control bodies (user-authored) |
| `component_name` | `VULCAN_LIMIT_COMPONENT_NAME` | 255 | Component name |
| `component_prefix` | `VULCAN_LIMIT_COMPONENT_PREFIX` | 10 | STIG ID prefix (e.g., ABCD-01) |
| `component_title` | `VULCAN_LIMIT_COMPONENT_TITLE` | 500 | Component title |
| `component_description` | `VULCAN_LIMIT_COMPONENT_DESCRIPTION` | 5,000 | Component description |
| `project_name` | `VULCAN_LIMIT_PROJECT_NAME` | 255 | Project name |
| `project_description` | `VULCAN_LIMIT_PROJECT_DESCRIPTION` | 5,000 | Project description |
| `user_name` | `VULCAN_LIMIT_USER_NAME` | 255 | User display name |
| `user_email` | `VULCAN_LIMIT_USER_EMAIL` | 255 | User email address |
| `review_comment` | `VULCAN_LIMIT_REVIEW_COMMENT` | 10,000 | Review comments |
| `benchmark_name` | `VULCAN_LIMIT_BENCHMARK_NAME` | 500 | SRG/STIG display name |
| `benchmark_title` | `VULCAN_LIMIT_BENCHMARK_TITLE` | 500 | SRG/STIG title |
| `benchmark_description` | `VULCAN_LIMIT_BENCHMARK_DESCRIPTION` | 10,000 | STIG description |

## Field-to-Setting Mapping

### BaseRule (base_rules table)

| Field | Setting | Default |
|---|---|---|
| `rule_id`, `rule_weight`, `version`, `ident_system`, `fixtext_fixref`, `fix_id`, `srg_id`, `vuln_id`, `legacy_ids` | `short_string` | 255 |
| `inspec_control_body_lang`, `inspec_control_file_lang` | `short_string` | 255 |
| `ident` | `ident` | 2,048 |
| `title` | `title` | 500 |
| `status_justification` | `medium_text` | 1,000 |
| `fixtext`, `artifact_description`, `vendor_comments` | `long_text` | 10,000 |
| `inspec_control_body`, `inspec_control_file` | `inspec_code` | 50,000 |
| `rule_severity` | N/A — constrained by inclusion validation (low/medium/high) |
| `status` | N/A — constrained by inclusion validation |

### DisaRuleDescription (disa_rule_descriptions table)

| Field | Setting | Default |
|---|---|---|
| `vuln_discussion`, `false_positives`, `false_negatives`, `mitigations`, `severity_override_guidance`, `potential_impacts`, `third_party_tools`, `mitigation_control`, `responsibility`, `ia_controls`, `poam` | `long_text` | 10,000 |

### Check (checks table)

| Field | Setting | Default |
|---|---|---|
| `system`, `content_ref_name`, `content_ref_href` | `short_string` | 255 |
| `content` | `long_text` | 10,000 |

### Component (components table)

| Field | Setting | Default |
|---|---|---|
| `name` | `component_name` | 255 |
| `prefix` | `component_prefix` | 10 |
| `title` | `component_title` | 500 |
| `description` | `component_description` | 5,000 |
| `admin_name`, `admin_email` | `short_string` | 255 |

### Project (projects table)

| Field | Setting | Default |
|---|---|---|
| `name` | `project_name` | 255 |
| `description` | `project_description` | 5,000 |
| `admin_name`, `admin_email` | `short_string` | 255 |

### User (users table)

| Field | Setting | Default |
|---|---|---|
| `name` | `user_name` | 255 |
| `email` | `user_email` | 255 |

### SecurityRequirementsGuide (security_requirements_guides table)

| Field | Setting | Default |
|---|---|---|
| `srg_id`, `version` | `short_string` | 255 |
| `title` | `benchmark_title` | 500 |
| `name` | `benchmark_name` | 500 |

### Stig (stigs table)

| Field | Setting | Default |
|---|---|---|
| `stig_id`, `version` | `short_string` | 255 |
| `title` | `benchmark_title` | 500 |
| `name` | `benchmark_name` | 500 |
| `description` | `benchmark_description` | 10,000 |

### Review (reviews table)

| Field | Setting | Default |
|---|---|---|
| `action` | `short_string` | 255 |
| `comment` | `review_comment` | 10,000 |

## Real DISA Data Analysis

Defaults based on analysis of 1,785 rules across 8 benchmarks (4 STIGs + 4 SRGs):

| Field | Actual Max | P99 | Default Limit | Headroom |
|---|---|---|---|---|
| check.content | 6,330 | 1,888 | 10,000 | 37% |
| vuln_discussion | 3,813 | 2,125 | 10,000 | 62% |
| fixtext | 3,448 | 1,153 | 10,000 | 66% |
| title | 436 | 255 | 500 | 13% |
| ident | 310 | 70 | 2,048 | 85% |
| version | 25 | 25 | 255 | 90% |
| rule_id | 22 | 22 | 255 | 91% |

## Error Behavior

When a length validation fails:
- **Direct model save**: `ActiveRecord::RecordInvalid` with message like "Title is too long (maximum is 500 characters)"
- **STIG/SRG XML import**: Error includes rule ID and specific field: "3 rules failed to import: SV-12345: Title is too long (maximum is 500 characters)"
- **Spreadsheet import**: Validation errors surface per-rule in the preview modal
- **API responses**: 422 with `errors.full_messages` array

## Upload Limits

| Endpoint | Max Size | Allowed Types |
|---|---|---|
| STIG upload (XML) | 50 MB | `.xml` |
| SRG upload (XML) | 50 MB | `.xml` |
| Spreadsheet import | 50 MB | `.xlsx`, `.csv` |
| JSON Archive import | 100 MB | `.zip` |
