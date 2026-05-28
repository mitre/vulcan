# Markdown Editor Analysis for Vulcan v2.3.0+

**Created:** 2025-11-26
**Purpose:** Analyze current control editing workflow and determine best markdown editor approach

---

## Current Workflow Analysis

### Architecture Overview

Vulcan uses a **nested form component hierarchy** for editing controls:

```
RuleEditorHeader (actions, save, delete, review)
  ↓
BasicRuleForm OR AdvancedRuleForm (parent container)
  ↓
RuleForm (main fields: status, title, artifact_description, fixtext, vendor_comments)
  ↓
DisaRuleDescriptionForm (embedded: vuln_discussion, mitigations, etc.)
  ↓
CheckForm (embedded: check content)
```

### Fields Using `b-form-textarea`

**Large text fields that need markdown editing:**

1. **RuleForm.vue:**
   - `status_justification` - Why this status was chosen
   - `title` - Control title (uses textarea for multi-line)
   - `artifact_description` - Evidence/artifacts
   - `fixtext` - How to fix the vulnerability
   - `vendor_comments` - Internal notes

2. **DisaRuleDescriptionForm.vue (11 text fields):**
   - `vuln_discussion` ⭐ **PRIMARY** - Long-form vulnerability description
   - `false_positives` - Known false positive cases
   - `false_negatives` - Known false negative cases
   - `mitigations` ⭐ **PRIMARY** - Mitigation strategies
   - `poam` - Plan of Action & Milestones
   - `severity_override_guidance` - Override reasoning
   - `potential_impacts` - Impact analysis
   - `third_party_tools` - External tool requirements
   - `mitigation_control` - Control mitigation details
   - `responsibility` - Who is responsible
   - `ia_controls` - Information Assurance controls

3. **CheckForm.vue:**
   - `content` ⭐ **PRIMARY** - Check/validation code

### Current UI Pattern

All text fields use **Bootstrap-Vue `b-form-textarea`**:
```vue
<b-form-textarea
  :id="field-id"
  :value="field.value"
  :disabled="disabled"
  rows="1"
  max-rows="99"
  @input="$root.$emit('update:field', ...)"
/>
```

**Features:**
- Auto-expanding (starts at 1 row, grows to 99 rows)
- Plain text editing
- No formatting support
- No preview
- Event-based updates via `$root.$emit`

### Pain Points

1. **No formatting** - Users can't add emphasis, lists, code blocks
2. **No preview** - Can't see how markdown will render
3. **Large content** - Some fields (vuln_discussion) can be 500+ lines
4. **Copy/paste** - Formatting from Word/Excel gets lost
5. **No collaboration** - Multiple users can't edit simultaneously

---

## Comparison: Three Editor Options

### Option 1: Monaco (Already Have It)

**What It Is:** VSCode's editor engine (already using for InSpec code)

**Implementation:**
```vue
<monaco-editor
  :value="rule.vuln_discussion"
  language="markdown"
  theme="vs-light"
  :options="{ minimap: { enabled: false }, lineNumbers: 'off', wordWrap: 'on' }"
  @input="$root.$emit('update:disaDescription', ...)"
/>
```

**Pros:**
- ✅ **Zero dependencies** - Already installed
- ✅ **Zero implementation time** - Just change component
- ✅ **Consistent UX** - Users know it from InSpec editor
- ✅ **Markdown syntax highlighting** - Built-in
- ✅ **Safe undo/redo** - Proven reliable
- ✅ **Code-friendly** - Great for check content
- ✅ **Large file performance** - Handles 500+ lines easily

**Cons:**
- ❌ **No live preview** - Code editor, not WYSIWYG
- ❌ **No toolbar** - Must know markdown syntax
- ❌ **No collaboration** - Solo editing only
- ❌ **Feels "technical"** - May intimidate non-technical users

**Best For:**
- Check content (InSpec code)
- Technical users comfortable with markdown
- Quick win (can implement tonight)

---

### Option 2: mavonEditor (Split-Pane Preview)

**What It Is:** Vue 2 markdown editor with live preview (6.5k stars)

**Implementation:**
```vue
<mavon-editor
  v-model="rule.vuln_discussion"
  :toolbars="toolbarConfig"
  :subfield="true"
  language="en"
  :editable="!disabled"
  @save="handleSave"
  @change="$root.$emit('update:disaDescription', ...)"
/>
```

**Pros:**
- ✅ **Split-pane** - Edit markdown | See preview
- ✅ **Toolbar** - Bold, italic, lists, tables, etc.
- ✅ **Live preview** - See formatting immediately
- ✅ **Traditional undo/redo** - Full history, safe
- ✅ **User-friendly** - Non-technical users can use toolbar
- ✅ **Keyboard shortcuts** - Ctrl+B, Ctrl+I, etc.
- ✅ **Battle-tested** - 6.5k stars, mature project
- ✅ **Vue 2 native** - No compatibility issues

**Cons:**
- ⚠️ **One dependency** - mavon-editor package
- ⚠️ **No collaboration** - Solo editing only
- ⚠️ **Extra CSS** - Need to import stylesheet
- ⚠️ **4-6 hours** - Implementation + testing

**Best For:**
- Vuln discussion (long-form content)
- Mitigations (structured content)
- Non-technical users
- Better UX than Monaco

---

### Option 3: Tiptap (Collaborative WYSIWYG)

**What It Is:** Google Docs-style collaborative editor with Y.js CRDT

**Implementation:**
```vue
<collaborative-markdown-editor
  :rule="rule"
  :field="'vuln_discussion'"
  :current-user="currentUser"
  :collaborative-enabled="component.collaborative_editing_enabled"
/>
```

**Pros:**
- ✅ **True WYSIWYG** - Like Google Docs
- ✅ **Real-time collaboration** - Multiple users edit simultaneously
- ✅ **User cursors** - See who's editing where
- ✅ **Conflict-free** - CRDT merging (Y.js)
- ✅ **Offline-first** - Changes sync when reconnected
- ✅ **Rich formatting** - Bold, italic, lists, tables inline
- ✅ **Modern UX** - Best user experience

**Cons:**
- ❌ **Complex setup** - 6+ dependencies (Tiptap, Y.js, ActionCable integration)
- ❌ **Backend changes** - Need SyncChannel, Redis for ActionCable
- ❌ **Undo bug risk** - Issue #1786/#4400 (can delete document if not handled carefully)
- ❌ **12-16 hours** - Full implementation + testing
- ⚠️ **Medium risk** - Requires extensive safeguards:
  - Clear undo stack on document load (required!)
  - Auto-save every 30 seconds
  - Version snapshots
  - Thorough testing

**Best For:**
- Teams collaborating on same component
- High-value components with multiple authors
- Modern, Google Docs-like experience
- v2.3.2+ (not immediate need)

---

## Integration Strategy Analysis

### Challenge: 20 Text Fields Across 3 Components

We have **20 textarea fields** spread across:
- RuleForm (5 fields)
- DisaRuleDescriptionForm (11 fields)
- CheckForm (1 field)
- AdditionalAnswerForm (1 field)
- RuleDescriptionForm (1 field)

### Approach 1: Replace All Textareas (NOT RECOMMENDED)

Replace every `b-form-textarea` with markdown editor.

**Pros:**
- Consistent experience
- All fields get markdown

**Cons:**
- ❌ **Overkill** - Fields like `title` don't need markdown
- ❌ **Performance** - 20 Monaco/mavonEditor instances = slow
- ❌ **UX confusion** - Users don't want markdown for simple fields

**Verdict:** ❌ Too heavy-handed

---

### Approach 2: Selective Replacement (RECOMMENDED)

Only replace **high-value fields** that benefit from markdown.

**Fields to Convert:**

**Tier 1 - Must Convert (3 fields):**
1. `vuln_discussion` (DisaRuleDescriptionForm) - Long-form content, needs formatting
2. `mitigations` (DisaRuleDescriptionForm) - Structured lists, needs formatting
3. `content` (CheckForm) - InSpec code, benefits from syntax highlighting

**Tier 2 - Should Convert (4 fields):**
4. `fixtext` (RuleForm) - Step-by-step instructions, benefits from lists
5. `potential_impacts` (DisaRuleDescriptionForm) - Impact analysis, needs structure
6. `status_justification` (RuleForm) - Reasoning, benefits from formatting
7. `artifact_description` (RuleForm) - Evidence description, needs formatting

**Tier 3 - Keep as Plain Text (13 fields):**
- `title` - Short, single-line
- `vendor_comments` - Internal notes (can be plain)
- `false_positives/negatives` - Short lists
- `poam` - Structured data (could be form fields)
- Others - Low benefit from markdown

**Implementation:**
```vue
<!-- In DisaRuleDescriptionForm.vue -->
<template v-if="fields.displayed.includes('vuln_discussion')">
  <b-form-group>
    <label>Vulnerability Discussion</label>

    <!-- OPTION 1: Monaco (Quick Win) -->
    <monaco-editor
      v-if="useMarkdownEditor"
      :value="description.vuln_discussion"
      language="markdown"
      :options="markdownEditorOptions"
      @input="handleUpdate"
    />

    <!-- OPTION 2: mavonEditor (Better UX) -->
    <mavon-editor
      v-else-if="useRichMarkdownEditor"
      v-model="description.vuln_discussion"
      :toolbars="toolbarConfig"
      :subfield="true"
      @change="handleUpdate"
    />

    <!-- Fallback: Original textarea -->
    <b-form-textarea
      v-else
      :value="description.vuln_discussion"
      rows="1"
      max-rows="99"
      @input="handleUpdate"
    />
  </b-form-group>
</template>
```

**Pros:**
- ✅ **Targeted** - Only fields that benefit
- ✅ **Performance** - Only 3-7 editor instances
- ✅ **Gradual** - Can roll out field by field
- ✅ **Flexible** - Can mix editors (Monaco for code, mavonEditor for text)

**Cons:**
- ⚠️ **Inconsistent UX** - Some fields have editor, some don't
- ⚠️ **More code** - Need conditional rendering

**Verdict:** ✅ **This is the way**

---

### Approach 3: Component-Level Toggle (ALTERNATIVE)

Add setting: "Enable Markdown Editor for this Component"

**UI:**
```
Component Settings:
[ ] Enable Rich Text Editing (Markdown)

When enabled, large text fields will use a markdown editor with:
- Syntax highlighting
- Live preview
- Formatting toolbar
```

**Pros:**
- ✅ **User choice** - Teams decide what they need
- ✅ **Gradual adoption** - Opt-in per component
- ✅ **Easy rollback** - Can disable if issues

**Cons:**
- ⚠️ **Database migration** - Need `components.markdown_editing_enabled`
- ⚠️ **Settings UI** - Need component settings page
- ⚠️ **More complexity** - Another setting to manage

**Verdict:** ⚠️ **Good for collaborative mode, overkill for solo**

---

## Recommended Phased Approach

### Phase 1: Monaco Quick Win (Tonight - 30 minutes)

**Goal:** Get markdown editing immediately with zero risk

**Tasks:**
1. Create `MarkdownTextarea.vue` wrapper component
2. Replace 3 Tier 1 fields:
   - `vuln_discussion` → Monaco markdown
   - `mitigations` → Monaco markdown
   - `content` (CheckForm) → Monaco markdown
3. Test save/load workflow
4. Verify exports to spreadsheet work

**Code:**
```vue
<!-- app/javascript/components/shared/MarkdownTextarea.vue -->
<template>
  <monaco-editor
    :value="value"
    language="markdown"
    theme="vs-light"
    :options="{
      minimap: { enabled: false },
      lineNumbers: 'off',
      wordWrap: 'on',
      scrollBeyondLastLine: false,
      readOnly: disabled
    }"
    :style="{ height: computedHeight }"
    @input="$emit('input', $event)"
  />
</template>

<script>
import MonacoEditor from 'monaco-editor-vue'
export default {
  components: { MonacoEditor },
  props: {
    value: String,
    disabled: Boolean,
    minHeight: { type: String, default: '200px' }
  },
  computed: {
    computedHeight() {
      const lines = (this.value || '').split('\n').length
      return Math.max(200, Math.min(lines * 19, 800)) + 'px'
    }
  }
}
</script>
```

**Risk:** Very low
**Time:** 30 minutes
**Benefit:** Immediate markdown support

---

### Phase 2: mavonEditor Better UX (v2.3.1 - 4-6 hours)

**Goal:** Improve UX with split-pane preview and toolbar

**Tasks:**
1. `yarn add mavon-editor`
2. Create `RichMarkdownEditor.vue` component
3. Replace same 3 Tier 1 fields with mavonEditor
4. Add optional: 4 Tier 2 fields
5. Add Vitest tests for editor component
6. User acceptance testing

**Code:**
```vue
<!-- app/javascript/components/shared/RichMarkdownEditor.vue -->
<template>
  <mavon-editor
    :value="value"
    :toolbars="toolbarConfig"
    :subfield="true"
    language="en"
    :editable="!disabled"
    :placeholder="placeholder"
    @save="$emit('save', $event)"
    @change="$emit('input', $event)"
  />
</template>

<script>
import { mavonEditor } from 'mavon-editor'
import 'mavon-editor/dist/css/index.css'

export default {
  components: { mavonEditor },
  props: {
    value: String,
    disabled: Boolean,
    placeholder: String
  },
  data() {
    return {
      toolbarConfig: {
        bold: true, italic: true, header: true,
        underline: true, strikethrough: true,
        quote: true, ol: true, ul: true,
        link: true, code: true, table: true,
        fullscreen: true, undo: true, redo: true,
        save: true, preview: true
      }
    }
  }
}
</script>
```

**Risk:** Low
**Time:** 4-6 hours
**Benefit:** Much better UX, user-friendly

---

### Phase 3: Tiptap Collaborative (v2.3.2+ - 12-16 hours)

**Goal:** Add optional real-time collaboration for teams

**Tasks:**

**Backend (4-6 hours):**
1. Add `gem 'yrb-actioncable'` + Redis config
2. Create `SyncChannel` with authorization
3. Add `components.collaborative_editing_enabled` column
4. Periodic save job (Y.js state → DB)
5. Component settings UI

**Frontend (6-8 hours):**
1. Install Tiptap packages
2. Create `CollaborativeMarkdownEditor.vue`
3. Implement `ClearHistoryOnLoad` extension (undo safety)
4. Add user presence indicators
5. Add auto-save with indicator
6. Add "Enable Collaborative Editing" toggle

**Testing (2-3 hours):**
1. Multi-browser testing (Chrome + Firefox)
2. **Undo safety testing** (critical!)
3. Network interruption testing
4. Concurrent edit conflict testing

**Risk:** Medium (undo bug requires careful handling)
**Time:** 12-16 hours
**Benefit:** Real-time collaboration, modern UX

---

## Decision Matrix

| Factor | Monaco (Now) | mavonEditor (v2.3.1) | Tiptap (v2.3.2+) |
|--------|--------------|----------------------|------------------|
| **Implementation Time** | 30 min | 4-6 hours | 12-16 hours |
| **Risk Level** | Very Low | Low | Medium |
| **Dependencies** | 0 (have it) | 1 package | 6+ packages |
| **User Experience** | Good | Great | Excellent |
| **Learning Curve** | Low | Very Low | Low |
| **Undo/Redo Safety** | ✅ Safe | ✅ Safe | ⚠️ Needs safeguards |
| **Collaboration** | ❌ No | ❌ No | ✅ Yes |
| **Live Preview** | ❌ No | ✅ Split-pane | ✅ True WYSIWYG |
| **Toolbar** | ❌ No | ✅ Yes | ✅ Yes |
| **Large Files** | ✅ Excellent | ✅ Good | ✅ Good |
| **Code Highlighting** | ✅ Excellent | ⚠️ Basic | ⚠️ Via extension |
| **Markdown Export** | ✅ Direct | ✅ Direct | ✅ Via extension |
| **Backend Changes** | ❌ None | ❌ None | ✅ Major (ActionCable) |

---

## My Recommendation

### ✅ **Start with Approach 2 + Phase 1 (Monaco Quick Win)**

**Why:**
1. **Zero risk** - Already have Monaco, proven stable
2. **30 minutes** - Can do tonight before pushing v2.3.0
3. **Immediate value** - Users get markdown editing right away
4. **No dependencies** - No new packages to maintain
5. **Code-friendly** - Perfect for InSpec check content

**Fields to Convert (Phase 1):**
- `vuln_discussion` (DisaRuleDescriptionForm)
- `mitigations` (DisaRuleDescriptionForm)
- `content` (CheckForm)

### ⭐ **Then Upgrade to Phase 2 (mavonEditor in v2.3.1)**

**Why:**
1. **Better UX** - Split-pane preview, toolbar
2. **User-friendly** - Non-technical users can use it
3. **Still low risk** - Mature package, no backend changes
4. **Worth the time** - 4-6 hours for much better experience

### 🚀 **Consider Phase 3 (Tiptap in v2.3.2+) IF:**
- Users request real-time collaboration
- Teams actually work on same component simultaneously
- Willing to invest 12-16 hours + testing
- Willing to accept medium risk with safeguards

---

## Implementation Checklist

### Phase 1 - Tonight (30 min):
- [ ] Create `MarkdownTextarea.vue` wrapper
- [ ] Replace `vuln_discussion` with Monaco
- [ ] Replace `mitigations` with Monaco
- [ ] Replace `content` (CheckForm) with Monaco
- [ ] Test save/load workflow
- [ ] Test exports to spreadsheet
- [ ] Yarn build + browser refresh
- [ ] Manual smoke test

### Phase 2 - v2.3.1 (4-6 hours):
- [ ] `yarn add mavon-editor`
- [ ] Create `RichMarkdownEditor.vue`
- [ ] Replace 3 Tier 1 fields with mavonEditor
- [ ] Consider adding 4 Tier 2 fields
- [ ] Write Vitest tests
- [ ] User acceptance testing
- [ ] Documentation update

### Phase 3 - v2.3.2+ (12-16 hours):
- [ ] Backend: yrb-actioncable gem
- [ ] Backend: SyncChannel + authorization
- [ ] Backend: Redis ActionCable config
- [ ] Backend: Database migration
- [ ] Frontend: Tiptap packages
- [ ] Frontend: CollaborativeMarkdownEditor component
- [ ] Frontend: ClearHistoryOnLoad extension
- [ ] Frontend: User presence UI
- [ ] Frontend: Auto-save indicator
- [ ] Frontend: Component setting toggle
- [ ] Testing: Multi-browser undo safety
- [ ] Testing: Network interruption
- [ ] Testing: Concurrent edits
- [ ] Beta testing period (2 weeks minimum)

---

## Questions to Answer

1. **Do we have Redis running?** (Required for Tiptap collaborative)
   - Check: `redis-cli ping` or docker-compose.yml

2. **Which fields MUST have markdown?** (Prioritize Phase 1)
   - Confirmed: vuln_discussion, mitigations, content (check)
   - Consider: fixtext, potential_impacts, status_justification

3. **Do users actually need collaboration?** (Phase 3 decision)
   - Ask field users: "Do multiple people work on same component simultaneously?"
   - If yes → Phase 3
   - If no → Stop at Phase 2

4. **Should markdown be opt-in or automatic?** (UX decision)
   - Recommendation: Automatic for Tier 1 fields
   - Optional: Add component-level toggle for Phase 3

5. **How to handle existing content?** (Migration)
   - No migration needed - markdown editors handle plain text fine
   - Users can gradually add formatting

---

## Risk Mitigation

### Monaco (Phase 1):
- ✅ Zero risk - already using it
- ✅ No new dependencies
- ✅ Rollback: Just change component back

### mavonEditor (Phase 2):
- ✅ Low risk - mature package
- ✅ One dependency
- ✅ Rollback: Keep Monaco as fallback
- ⚠️ Test: Copy/paste from Word/Excel
- ⚠️ Test: Large content (500+ lines)

### Tiptap (Phase 3):
- ⚠️ **Critical:** Implement ClearHistoryOnLoad
- ⚠️ **Critical:** Test undo extensively
- ⚠️ Auto-save every 30 seconds
- ⚠️ Version snapshots before major edits
- ⚠️ Undo validation (don't delete >50% content)
- ⚠️ 2-week beta testing minimum
- ⚠️ Opt-in, not forced
- ✅ Rollback: Disable collaborative_editing_enabled

---

## Success Metrics

### Phase 1 (Monaco):
- ✅ All 3 fields render correctly
- ✅ Save/load preserves markdown
- ✅ Export to spreadsheet works
- ✅ No performance issues
- ✅ Users can add markdown syntax

### Phase 2 (mavonEditor):
- ✅ Live preview works correctly
- ✅ Toolbar buttons function properly
- ✅ Copy/paste preserves formatting
- ✅ Users prefer it over Monaco
- ✅ No complaints about UX

### Phase 3 (Tiptap):
- ✅ Multiple users can edit simultaneously
- ✅ Cursor positions shown correctly
- ✅ No conflicts during concurrent editing
- ✅ **Undo NEVER deletes pre-existing content**
- ✅ Auto-save works reliably
- ✅ Network interruption handles gracefully
- ✅ Zero data loss incidents

---

## Final Recommendation

### **Do This:**

1. **Tonight:** Implement Phase 1 (Monaco) - 30 minutes
   - Quick win, zero risk
   - Users get markdown immediately
   - Can push v2.3.0 with markdown support

2. **v2.3.1:** Upgrade to Phase 2 (mavonEditor) - 4-6 hours
   - Much better UX
   - Still low risk
   - Worth the investment

3. **v2.3.2+:** Evaluate Phase 3 (Tiptap) - TBD
   - Only if users actually need collaboration
   - Only if willing to invest 12-16 hours
   - Only after extensive testing

### **Don't Do This:**

❌ Replace all 20 textareas - Overkill
❌ Jump to Tiptap first - Too risky
❌ Skip Monaco → go straight to mavonEditor - Lose quick win
❌ Force collaboration on everyone - Make it opt-in

---

**Status:** Ready for implementation decision
**Next Step:** Implement Phase 1 (Monaco) tonight OR wait for v2.3.1 (mavonEditor)
**User Question:** Do you want markdown editing now (Monaco, 30 min) or better UX later (mavonEditor, 4-6 hours)?
