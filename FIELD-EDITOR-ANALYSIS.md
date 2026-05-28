# Field-by-Field Editor Analysis for Vulcan v2.3.0

**Created:** 2025-11-26
**Purpose:** Determine the RIGHT input type for each field based on actual use case

---

## Field Analysis by Type

### SELECTION FIELDS (Already Correct - Keep As-Is)

| Field | Current | Purpose | Keep As |
|-------|---------|---------|---------|
| `status` | `b-form-select` | Choose from predefined statuses | ✅ Dropdown |
| `rule_severity` | `b-form-select` | CAT I, II, III, etc. | ✅ Dropdown |
| `documentable` | `b-form-checkbox` | Boolean flag | ✅ Checkbox |
| `mitigations_available` | `b-form-checkbox` (switch) | Toggle mitigations section | ✅ Switch |
| `poam_available` | `b-form-checkbox` (switch) | Toggle POA&M section | ✅ Switch |

**Verdict:** These are perfect as-is. No changes needed.

---

### SINGLE-LINE TEXT FIELDS (Keep Simple)

| Field | Current | Typical Content | Recommendation |
|-------|---------|----------------|----------------|
| `version` | `b-form-input` | "r1", "v2", "1.0" | ✅ Keep input |
| `fix_id` | `b-form-input` | "F-12345" | ✅ Keep input |
| `fixtext_fixref` | `b-form-input` | Reference ID | ✅ Keep input |
| `ident` | `b-form-input` | "CCI-000123" | ✅ Keep input |
| `ident_system` | `b-form-input` | URL or system name | ✅ Keep input |
| `rule_weight` | `b-form-input` | Numeric value | ✅ Keep input |

**Verdict:** All single-line identifiers/refs. Keep as `b-form-input`.

---

### SHORT TEXT FIELDS (Auto-Expanding Textarea - Keep As-Is)

| Field | Current | Typical Content | Lines | Recommendation |
|-------|---------|----------------|-------|----------------|
| `title` | `b-form-textarea` | Control title (1-3 lines) | 1-3 | ✅ Keep textarea |
| `false_positives` | `b-form-textarea` | Short list of FP scenarios | 1-5 | ✅ Keep textarea |
| `false_negatives` | `b-form-textarea` | Short list of FN scenarios | 1-5 | ✅ Keep textarea |
| `third_party_tools` | `b-form-textarea` | Tool names/versions | 1-3 | ✅ Keep textarea |
| `responsibility` | `b-form-textarea` | Role/person responsible | 1-2 | ✅ Keep textarea |
| `ia_controls` | `b-form-textarea` | CCI list | 1-3 | ✅ Keep textarea |

**Verdict:** These are 1-5 line fields. Plain textarea is perfect. Don't overcomplicate.

---

### MEDIUM TEXT FIELDS (2-10 sentences - CONSIDER MARKDOWN)

| Field | Current | Typical Content | Lines | Recommendation |
|-------|---------|----------------|-------|----------------|
| `status_justification` | `b-form-textarea` | Why chose this status | 3-8 | ⚠️ **MAYBE** mavonEditor |
| `vendor_comments` | `b-form-textarea` | Internal notes | 2-10 | ⚠️ **MAYBE** mavonEditor |
| `artifact_description` | `b-form-textarea` | Evidence description | 3-10 | ⚠️ **MAYBE** mavonEditor |
| `severity_override_guidance` | `b-form-textarea` | Override reasoning | 3-8 | ⚠️ **MAYBE** mavonEditor |
| `mitigation_control` | `b-form-textarea` | Control mitigation details | 3-8 | ⚠️ **MAYBE** mavonEditor |
| `poam` | `b-form-textarea` | POA&M plan details | 5-15 | ⚠️ **MAYBE** mavonEditor |

**Verdict:** These COULD benefit from markdown (lists, emphasis), but users might not need it. **Make it optional** via component setting or just keep simple.

---

### LONG-FORM CONTENT (DEFINITELY NEEDS MARKDOWN EDITOR)

| Field | Current | Typical Content | Lines | Recommendation |
|-------|---------|----------------|-------|----------------|
| `vuln_discussion` | `b-form-textarea` | Detailed vulnerability explanation | 10-100+ | ✅ **MUST USE** mavonEditor |
| `mitigations` | `b-form-textarea` | Step-by-step mitigation guide | 10-50+ | ✅ **MUST USE** mavonEditor |
| `fixtext` | `b-form-textarea` | Detailed fix instructions | 10-50+ | ✅ **MUST USE** mavonEditor |
| `potential_impacts` | `b-form-textarea` | Impact analysis | 5-30 | ✅ **SHOULD USE** mavonEditor |

**Verdict:** These are the **PRIMARY TARGETS** for mavonEditor. Users write paragraphs, lists, code blocks.

---

### CODE/STRUCTURED CONTENT (NEEDS MONACO OR SPECIAL HANDLING)

| Field | Current | Typical Content | Lines | Recommendation |
|-------|---------|----------------|-------|----------------|
| `content` (CheckForm) | `b-form-textarea` | InSpec code or check instructions | 5-50+ | ✅ **USE MONACO** (code editor) |

**Verdict:** This is code. Monaco editor (markdown or ruby) would be perfect.

---

## Final Recommendations

### Tier 1: MUST Convert to mavonEditor (4 fields)

1. **`vuln_discussion`** (DisaRuleDescriptionForm)
   - **Why:** Long-form (10-100+ lines), needs formatting
   - **Benefit:** Lists, emphasis, code blocks, headings
   - **Status Display:** "Applicable - Configurable" + others

2. **`mitigations`** (DisaRuleDescriptionForm)
   - **Why:** Step-by-step instructions, needs lists
   - **Benefit:** Numbered lists, bullet points, code examples
   - **Status Display:** "Applicable - Does Not Meet" + "Applicable - Configurable"

3. **`fixtext`** (RuleForm)
   - **Why:** Detailed fix instructions (10-50+ lines)
   - **Benefit:** Step-by-step lists, code examples, warnings
   - **Status Display:** "Applicable - Configurable"

4. **`potential_impacts`** (DisaRuleDescriptionForm)
   - **Why:** Impact analysis with multiple scenarios
   - **Benefit:** Lists, emphasis, structured content
   - **Status Display:** "Applicable - Configurable"

### Tier 2: CONSIDER mavonEditor (Optional/Later) (6 fields)

5. `status_justification` - Short but could use lists
6. `vendor_comments` - Internal notes, could use formatting
7. `artifact_description` - Evidence descriptions
8. `severity_override_guidance` - Reasoning
9. `mitigation_control` - Control details
10. `poam` - POA&M plan

**Recommendation:** Keep these as plain textarea for now. Add mavonEditor in v2.3.1 IF users request it.

### Tier 3: Keep As Plain Textarea (6 fields)

11. `title` - Short, no need for formatting
12. `false_positives` - Short list
13. `false_negatives` - Short list
14. `third_party_tools` - Tool names
15. `responsibility` - Role name
16. `ia_controls` - CCI list

### Special: Code Editor (1 field)

17. **`content` (CheckForm)** - Use Monaco with markdown or ruby language

---

## Status-Driven Field Visibility

### Fields Shown by Status:

**"Applicable - Configurable":**
- ✅ vuln_discussion (mavonEditor)
- ✅ fixtext (mavonEditor)
- ✅ potential_impacts (mavonEditor)
- ✅ mitigations (mavonEditor)
- content/check (Monaco)
- status_justification (textarea)
- artifact_description (textarea)

**"Applicable - Does Not Meet":**
- ✅ mitigations (mavonEditor)
- ✅ poam (textarea or mavonEditor?)
- mitigation_control (textarea)
- status_justification (textarea)

**"Applicable - Inherently Meets":**
- artifact_description (textarea)
- status_justification (textarea)

**"Not Applicable":**
- artifact_description (textarea)
- status_justification (textarea)

**"Not Yet Determined":**
- vuln_discussion (DISABLED, read-only)
- title (DISABLED)

---

## Implementation Strategy

### Phase 1: Core Long-Form Fields (HIGH IMPACT)

**Convert to mavonEditor:**
1. vuln_discussion
2. mitigations
3. fixtext
4. potential_impacts

**Keep as Monaco:**
5. content (CheckForm) - code editor

**Effort:** 3-4 hours
**Impact:** HIGH - these are the fields users write the most in

### Phase 2: Medium Fields (OPTIONAL - v2.3.1)

**IF users request formatting:**
- status_justification
- vendor_comments
- artifact_description
- poam

**Effort:** 2-3 hours
**Impact:** MEDIUM - nice to have, not critical

### Phase 3: Keep Simple (DON'T CHANGE)

**All other fields stay as-is:**
- Single-line inputs: version, fix_id, ident, etc.
- Short textareas: title, false_positives, etc.
- Dropdowns: status, severity
- Checkboxes: documentable, mitigations_available

**Effort:** 0 hours
**Impact:** Keeps it simple, avoids over-engineering

---

## mavonEditor Configuration for Each Field

### vuln_discussion (Primary - Most Complex)

```vue
<mavon-editor
  v-model="description.vuln_discussion"
  :editable="!(disabled || rule.status == 'Not Yet Determined')"
  :toolbars="{
    bold: true, italic: true, header: true,
    underline: true, strikethrough: true,
    quote: true, ol: true, ul: true,
    link: true, code: true, table: true,
    fullscreen: true, undo: true, redo: true,
    preview: true, save: false
  }"
  :subfield="false"  <!-- Edit-only, preview on button click -->
  language="en"
  placeholder="Describe the vulnerability in detail..."
  default-open="edit"
  @change="$root.$emit('update:disaDescription', ...)"
/>
```

### mitigations (Numbered Lists Important)

```vue
<mavon-editor
  v-model="description.mitigations"
  :editable="!disabled"
  :toolbars="{
    bold: true, italic: true,
    ol: true, ul: true,  <!-- Lists most important -->
    code: true,
    fullscreen: true, undo: true, redo: true,
    preview: true
  }"
  :subfield="false"
  placeholder="Describe mitigation steps..."
  @change="$root.$emit('update:disaDescription', ...)"
/>
```

### fixtext (Step-by-Step Instructions)

```vue
<mavon-editor
  v-model="rule.fixtext"
  :editable="!disabled"
  :toolbars="{
    bold: true, italic: true,
    ol: true, ul: true,  <!-- Numbered steps -->
    code: true, quote: true,
    fullscreen: true, undo: true, redo: true,
    preview: true
  }"
  :subfield="false"
  placeholder="Describe how to fix the vulnerability..."
  @change="$root.$emit('update:rule', ...)"
/>
```

### content (CheckForm - Use Monaco Instead)

```vue
<monaco-editor
  :value="check.content"
  language="markdown"  <!-- or "ruby" for InSpec -->
  theme="vs-light"
  :options="{
    minimap: { enabled: false },
    lineNumbers: 'on',
    wordWrap: 'on'
  }"
  @input="$root.$emit('update:check', ...)"
/>
```

---

## UX Considerations

### Don't Overwhelm Users

**Problem:** If EVERY field is a rich editor, it's overwhelming.

**Solution:**
- **4 core fields** get mavonEditor (vuln_discussion, mitigations, fixtext, potential_impacts)
- **Everything else** stays simple textarea/input
- **Clear visual distinction** - mavonEditor has toolbar, textareas don't

### Progressive Disclosure

**Users can gradually adopt markdown:**
1. **Day 1:** Type plain text in mavonEditor (works fine)
2. **Week 1:** Learn to use bold/italic buttons
3. **Month 1:** Start using lists and code blocks
4. **Month 3:** Power users use fullscreen, tables, etc.

**No forcing users to learn markdown** - they can type plain text forever if they want.

### Toolbar Simplicity

**Don't show every button:**
- ❌ **DON'T SHOW:** Image upload, save, help, subfield toggle
- ✅ **DO SHOW:** Bold, italic, lists, code, fullscreen, preview, undo/redo

Keep toolbar minimal and focused on text formatting.

---

## Decision Tree

```
Is this field...

├─ A selection (dropdown/checkbox)?
│  └─ ✅ KEEP AS-IS (b-form-select, b-form-checkbox)
│
├─ A single-line identifier/reference?
│  └─ ✅ KEEP AS-IS (b-form-input)
│
├─ 1-5 lines of plain text?
│  └─ ✅ KEEP AS-IS (b-form-textarea, rows="1", max-rows="99")
│
├─ 10+ lines with formatting needs (lists, emphasis)?
│  └─ ✅ USE mavonEditor
│
├─ Code or structured content?
│  └─ ✅ USE Monaco
│
└─ Unsure?
   └─ ⚠️ START WITH PLAIN TEXTAREA, upgrade later if users request it
```

---

## Testing Checklist

### For Each mavonEditor Field:

- [ ] Displays correctly in all statuses
- [ ] Respects disabled state (Not Yet Determined, locked, etc.)
- [ ] Saves plain text correctly
- [ ] Saves markdown correctly
- [ ] Exports to spreadsheet with markdown preserved
- [ ] Exports to XCCDF with markdown converted to plain text
- [ ] Works with satisfied_by relationships
- [ ] Toolbar buttons work
- [ ] Preview renders markdown correctly
- [ ] Fullscreen mode works
- [ ] Undo/redo works
- [ ] Copy/paste from Word/Excel works

---

## Summary

**Convert to mavonEditor:** 4 fields
- vuln_discussion
- mitigations
- fixtext
- potential_impacts

**Use Monaco:** 1 field
- content (CheckForm)

**Keep as plain textarea/input:** 15+ fields
- Everything else

**Rationale:** Focus on high-impact long-form fields. Keep simple fields simple. Don't over-engineer.

**Estimated Time:** 3-4 hours for Phase 1 (core 4 fields)

---

**Status:** Ready for implementation
**Next Step:** Implement Phase 1 (4 mavonEditor fields) in v2.3.0
