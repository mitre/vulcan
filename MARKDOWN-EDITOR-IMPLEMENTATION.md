# Markdown Editor Implementation Plan for Vulcan

## Executive Summary

Add dual-mode markdown editing to Vulcan with user-selectable collaborative or solo modes. This allows teams to work together in real-time while giving solo authors full control and traditional undo/redo.

## User Choice Architecture

### Mode 1: Collaborative Editing (Tiptap + Y.js + ActionCable)
**Use Case:** Teams working on same component simultaneously
**Risk Level:** Low (with safeguards implemented)

### Mode 2: Solo Editing (mavonEditor)
**Use Case:** Solo authors or users wanting full undo/redo control
**Risk Level:** None (proven, mature)

---

## Option 1: Collaborative Mode (Tiptap)

### Overview
Real-time collaborative WYSIWYG markdown editor with Rails ActionCable backend.

### Tech Stack

**Frontend Dependencies:**
```bash
yarn add @tiptap/vue-2 @tiptap/starter-kit @tiptap/extension-collaboration @tiptap/extension-collaboration-cursor @y-rb/actioncable yjs @rails/actioncable
```

**Backend Dependencies:**
```ruby
# Gemfile
gem 'yrb-actioncable'
gem 'redis' # For ActionCable adapter (might already have)
```

### Key Features
- ✅ Multiple users edit simultaneously
- ✅ See other users' cursors (name + color)
- ✅ Conflict-free merging (CRDT)
- ✅ Offline-first (changes sync when back online)
- ✅ Works with existing Rails/ActionCable
- ✅ Markdown support via extensions

### Critical Safeguards

#### 1. Clear Undo Stack on Document Load
**Problem:** Undo can delete entire document if undo stack includes initial load
**Solution:** Custom extension to clear history after sync

```javascript
// Custom extension based on CyberCRI/projects-frontend
import { Extension } from '@tiptap/core'
import { yUndoPluginKey } from 'y-prosemirror'

const ClearHistoryOnLoad = Extension.create({
  name: 'clearHistoryOnLoad',

  onCreate() {
    const undoManager = yUndoPluginKey.getState(this.editor.state).undoManager
    undoManager.clear() // Clear undo stack on document load
  }
})
```

**Reference:** https://github.com/CyberCRI/projects-frontend/blob/main/src/components/base/form/TextEditor/tiptap-extensions/ClearHistoryWS.ts

#### 2. Auto-Save
**Implementation:** Auto-save to database every 30 seconds
**Benefit:** Limits data loss to 30 seconds max

#### 3. Version Snapshots
**Implementation:** Save snapshot before major edits (on "Save Control" click)
**Benefit:** Can restore from snapshots if needed

#### 4. Undo Validation
**Implementation:** Don't allow undo if it would delete >50% of content
**Benefit:** Extra safety net

### Architecture

```
┌─────────────────┐         ┌─────────────────┐
│   User A        │         │   User B        │
│ Tiptap Editor   │         │ Tiptap Editor   │
│  + Y.js Doc     │         │  + Y.js Doc     │
└────────┬────────┘         └────────┬────────┘
         │                           │
         │    WebSocket (ActionCable)│
         └──────────┬────────────────┘
                    │
         ┌──────────▼──────────┐
         │  Rails Backend      │
         │  SyncChannel        │
         │  (yrb-actioncable)  │
         └──────────┬──────────┘
                    │
         ┌──────────▼──────────┐
         │  PostgreSQL         │
         │  (rule.vuln_disc)   │
         └─────────────────────┘
```

### Backend Implementation

**1. Install yrb-actioncable gem:**
```ruby
# Gemfile
gem 'yrb-actioncable'
```

**2. Create SyncChannel:**
```ruby
# app/channels/sync_channel.rb
class SyncChannel < ApplicationCable::Channel
  include Yrb::Actioncable

  def subscribed
    # Reject if user doesn't have permission
    rule = Rule.find(params[:rule_id])
    component = rule.component

    reject unless can_edit?(current_user, component)

    stream_from "sync_#{params[:rule_id]}_#{params[:field]}"
  end

  def receive(message)
    # Broadcast Y.js updates to other connected clients
    ActionCable.server.broadcast(
      "sync_#{params[:rule_id]}_#{params[:field]}",
      message
    )
  end

  private

  def can_edit?(user, component)
    # Use existing Vulcan authorization logic
    component.all_users.include?(user)
  end
end
```

**3. Periodic Save to Database:**
```ruby
# app/jobs/collaborative_document_save_job.rb
class CollaborativeDocumentSaveJob < ApplicationJob
  queue_as :default

  def perform(rule_id, field, yjs_binary_data)
    rule = Rule.find(rule_id)

    # Convert Y.js binary to text
    doc = Y::Doc.new
    doc.apply_update(yjs_binary_data)
    text_content = doc.get_text(field).to_s

    # Save to database
    rule.update(field => text_content)
  end
end
```

### Frontend Implementation

**1. Tiptap Component for Collaborative Editing:**
```vue
<!-- app/javascript/components/rules/forms/CollaborativeMarkdownEditor.vue -->
<template>
  <div>
    <!-- User presence indicators -->
    <div class="collaborators mb-2">
      <b-badge
        v-for="user in connectedUsers"
        :key="user.id"
        :style="{ backgroundColor: user.color }"
        pill
        class="mr-1"
      >
        {{ user.name }}
      </b-badge>
    </div>

    <!-- Tiptap Editor -->
    <editor-content :editor="editor" />

    <!-- Auto-save indicator -->
    <small class="text-muted">
      <b-icon icon="cloud-check" v-if="!saving" />
      <b-spinner small v-if="saving" />
      {{ saving ? 'Saving...' : 'All changes saved' }}
    </small>
  </div>
</template>

<script>
import { Editor, EditorContent } from '@tiptap/vue-2'
import StarterKit from '@tiptap/starter-kit'
import Collaboration from '@tiptap/extension-collaboration'
import CollaborationCursor from '@tiptap/extension-collaboration-cursor'
import { WebsocketProvider } from '@y-rb/actioncable'
import { createConsumer } from '@rails/actioncable'
import * as Y from 'yjs'

export default {
  name: 'CollaborativeMarkdownEditor',
  components: { EditorContent },
  props: {
    rule: { type: Object, required: true },
    field: { type: String, required: true },
    currentUser: { type: Object, required: true }
  },
  data() {
    return {
      editor: null,
      ydoc: null,
      provider: null,
      connectedUsers: [],
      saving: false
    }
  },
  mounted() {
    // Initialize Y.js document
    this.ydoc = new Y.Doc()

    // Create ActionCable consumer
    const consumer = createConsumer()

    // Create WebSocket provider for Y.js
    this.provider = new WebsocketProvider(
      this.ydoc,
      consumer,
      'SyncChannel',
      {
        rule_id: this.rule.id,
        field: this.field
      }
    )

    // Initialize Tiptap editor
    this.editor = new Editor({
      extensions: [
        StarterKit.configure({
          history: false  // CRITICAL: Disable standard history
        }),
        Collaboration.configure({
          document: this.ydoc,
          field: this.field
        }),
        CollaborationCursor.configure({
          provider: this.provider,
          user: {
            name: this.currentUser.name,
            color: this.getUserColor(this.currentUser.id)
          }
        }),
        // Custom extension to clear undo stack on load
        this.ClearHistoryOnLoad
      ],
      content: this.rule[this.field] || '',
      onUpdate: () => {
        this.debouncedSave()
      }
    })

    // Track connected users
    this.provider.awareness.on('change', () => {
      this.connectedUsers = Array.from(
        this.provider.awareness.getStates().values()
      )
    })
  },
  beforeDestroy() {
    this.editor?.destroy()
    this.provider?.destroy()
  },
  methods: {
    ClearHistoryOnLoad: {
      name: 'clearHistoryOnLoad',
      onCreate() {
        const undoManager = yUndoPluginKey.getState(this.editor.state).undoManager
        undoManager.clear()
      }
    },

    getUserColor(userId) {
      // Generate consistent color per user
      const colors = ['#ff6b6b', '#4ecdc4', '#45b7d1', '#f7b731', '#5f27cd']
      return colors[userId % colors.length]
    },

    debouncedSave: _.debounce(function() {
      this.saving = true
      const content = this.editor.getHTML()

      // Save to backend
      axios.put(`/rules/${this.rule.id}`, {
        rule: { [this.field]: content }
      }).finally(() => {
        this.saving = false
      })
    }, 2000)
  }
}
</script>
```

### Known Issues & Mitigations

**Issue #1786 (Undo Deletes Document):**
- **Status:** Can occur if undo stack not cleared on load
- **Mitigation:** Always clear undo stack in onCreate
- **Tested By:** Multiple production apps (CyberCRI, etc.)

**Issue #4400 (Recent, still open):**
- **Status:** Edge cases with document loading timing
- **Mitigation:**
  - Clear undo after provider.on('synced') event
  - Disable undo button until first user edit
  - Show warning before large deletions

### Testing Requirements

**Before Production:**
1. Load existing document → Type → Undo → Verify only new text removed
2. Two users edit simultaneously → Both undo → Verify each undoes only their changes
3. User goes offline → Types → Comes back online → Verify sync works
4. Spam undo button → Should not delete pre-existing content
5. Load empty document → Type → Undo → Should work normally

### Resources
- **Rails + Tiptap Guide:** https://www.geekyhub.in/post/implementing-a-google-doc-notion-like-collborative-editor-in-rails-react-tiptap/
- **yrb-actioncable gem:** https://github.com/y-crdt/yrb-actioncable
- **ClearHistory extension:** https://github.com/CyberCRI/projects-frontend/blob/main/src/components/base/form/TextEditor/tiptap-extensions/ClearHistoryWS.ts
- **Tiptap Vue 2 docs:** https://tiptap.dev/docs/editor/getting-started/install/vue2
- **Y.js UndoManager:** https://docs.yjs.dev/api/undo-manager

---

## Option 2: Solo Mode (mavonEditor)

### Overview
Proven split-pane markdown editor with live preview. Zero collaboration complexity.

### Tech Stack

**Dependencies:**
```bash
yarn add mavon-editor
```

### Key Features
- ✅ Split-pane (edit markdown | preview HTML)
- ✅ Full toolbar (bold, italic, lists, tables, etc.)
- ✅ Traditional undo/redo (full history)
- ✅ Image upload support
- ✅ Keyboard shortcuts
- ✅ 6.5k stars, battle-tested
- ✅ Vue 2 native

### Implementation

```vue
<!-- app/javascript/components/rules/forms/SoloMarkdownEditor.vue -->
<template>
  <div>
    <mavon-editor
      v-model="content"
      :toolbars="toolbarConfig"
      :subfield="true"
      language="en"
      :editable="!disabled"
      @save="handleSave"
      @change="handleChange"
    />
  </div>
</template>

<script>
import { mavonEditor } from 'mavon-editor'
import 'mavon-editor/dist/css/index.css'

export default {
  name: 'SoloMarkdownEditor',
  components: { mavonEditor },
  props: {
    rule: { type: Object, required: true },
    field: { type: String, required: true },
    disabled: { type: Boolean, default: false }
  },
  data() {
    return {
      content: this.rule[this.field] || '',
      toolbarConfig: {
        bold: true,
        italic: true,
        header: true,
        underline: true,
        strikethrough: true,
        quote: true,
        ol: true,
        ul: true,
        link: true,
        code: true,
        table: true,
        fullscreen: true,
        undo: true,
        redo: true,
        save: true
      }
    }
  },
  methods: {
    handleSave(value, render) {
      // Ctrl+S triggers this
      this.$root.$emit('update:rule', {
        ...this.rule,
        [this.field]: value
      })
    },
    handleChange(value, render) {
      // Update on change (debounced)
      this.$root.$emit('update:rule', {
        ...this.rule,
        [this.field]: value
      })
    }
  }
}
</script>
```

### Resources
- **mavonEditor GitHub:** https://github.com/hinesboy/mavonEditor (6.5k stars)
- **Documentation:** See README.md in repo
- **Live Demo:** https://github.com/hinesboy/mavonEditor#example

---

## Implementation Plan

### Phase 1: Add Solo Mode (mavonEditor) - v2.3.1
**Estimated Time:** 4-6 hours
**Risk:** Low

**Steps:**
1. Install mavon-editor
2. Create SoloMarkdownEditor.vue component
3. Add markdown field type to RuleForm
4. Replace textareas with SoloMarkdownEditor for:
   - vuln_discussion
   - check content
   - fixtext
   - mitigations
5. Test save/load workflow
6. Write Vitest tests
7. User acceptance testing

**Testing:**
- Create control, add markdown → Save → Reload → Verify formatting preserved
- Test undo/redo extensively
- Test copy/paste from Word/Excel
- Test image upload (if enabled)
- Export to spreadsheet → Verify markdown renders correctly

### Phase 2: Add Collaborative Mode (Tiptap) - v2.3.2 or later
**Estimated Time:** 12-16 hours
**Risk:** Medium (needs extensive testing)

**Steps:**

**Backend (4-6 hours):**
1. Add yrb-actioncable gem
2. Create SyncChannel with authorization
3. Add collaborative_editing_enabled to components table
4. Periodic save job (save Y.js state to DB)
5. Redis configuration for ActionCable

**Frontend (6-8 hours):**
1. Install Tiptap packages
2. Create CollaborativeMarkdownEditor.vue
3. Implement ClearHistoryOnLoad extension
4. Add user presence indicators
5. Add auto-save with indicator
6. Add "Enable Collaborative Mode" setting

**Testing (2-3 hours):**
1. Multi-browser testing (Chrome + Firefox simultaneously)
2. Undo safety testing (extensive!)
3. Network interruption testing
4. Concurrent edit conflict testing
5. Load testing (10+ users on same document)

### Phase 3: User Choice UI
**Estimated Time:** 2-3 hours

**Component-Level Setting:**
```
Component Settings:
[ ] Enable Collaborative Editing for this component

When enabled:
✓ Multiple users can edit simultaneously
✓ See who else is editing
⚠️ Undo only affects your changes since opening
⚠️ Auto-saves every 30 seconds
```

**Per-Field Rendering:**
```javascript
// In RuleForm.vue or similar
<component
  :is="useCollaborativeEditor ? 'CollaborativeMarkdownEditor' : 'SoloMarkdownEditor'"
  :rule="rule"
  :field="fieldName"
/>
```

---

## Risk Analysis

### Collaborative Mode Risks

**Risk 1: Undo Bug Deletes Content**
- **Likelihood:** Low (with safeguards)
- **Impact:** Critical
- **Mitigation:**
  - Clear undo stack on load (required)
  - Auto-save every 30s
  - Version snapshots
  - Extensive testing before release
  - User warning/training

**Risk 2: Network Issues During Sync**
- **Likelihood:** Medium
- **Impact:** Low
- **Mitigation:**
  - Y.js handles offline editing automatically
  - Changes queue and sync when back online
  - Show connection status indicator

**Risk 3: Concurrent Save Conflicts**
- **Likelihood:** Low
- **Impact:** Low
- **Mitigation:**
  - Y.js CRDT handles conflicts automatically
  - No manual conflict resolution needed

### Solo Mode Risks

**Risk 1: User Forgets to Save**
- **Likelihood:** Medium
- **Impact:** Medium
- **Mitigation:**
  - Unsaved changes warning
  - Auto-save option
  - Ctrl+S reminder

**Risk 2: Locking Conflicts**
- **Likelihood:** Low
- **Impact:** Low
- **Mitigation:**
  - Use existing Vulcan locking system
  - "Control is locked" warning

---

## Recommendation

### For v2.3.1 (Next Release):
**Start with Solo Mode Only** (mavonEditor)
- Lower risk
- Faster implementation
- Gives users markdown editing immediately
- No infrastructure changes needed

### For v2.3.2:
**Add Collaborative Mode as Beta**
- Opt-in per component
- Extensive testing period
- Gather user feedback
- Monitor for undo issues

### For v2.4.0:
**Make Collaborative Mode Default** (if beta successful)
- Proven stable
- Users trained
- Safeguards validated

---

## Alternative: Simpler Approach

### Use Monaco with Markdown Language (Already Have It!)

**Pros:**
- Zero new dependencies
- Already using monaco-editor
- Just add markdown to language dropdown
- Consistent UX with InSpec editor

**Cons:**
- Not WYSIWYG (code editor)
- No live preview
- No collaboration

**Implementation:** 5 minutes
```vue
<!-- In InspecControlEditor.vue, markdown is already an option! -->
languages: [
  { value: 'ruby', label: 'Ruby' },
  { value: 'markdown', label: 'Markdown' },  // Already there!
  ...
]
```

Just use Monaco for markdown fields - it's already there!

---

## Decision Matrix

| Feature | Monaco (Current) | mavonEditor | Tiptap Collab |
|---------|-----------------|-------------|---------------|
| **Implementation Time** | 0 hours | 4-6 hours | 12-16 hours |
| **Risk** | None | Low | Medium |
| **Undo/Redo** | ✅ Safe | ✅ Safe | ⚠️ Needs safeguards |
| **WYSIWYG** | ❌ Code | ✅ Preview | ✅ True WYSIWYG |
| **Collaboration** | ❌ No | ❌ No | ✅ Yes |
| **Dependencies** | 0 (have it) | 1 package | 6+ packages |
| **Markdown Export** | ✅ Direct | ✅ Direct | ✅ Via extension |
| **User Cursors** | ❌ No | ❌ No | ✅ Yes |

---

## Recommended Phased Approach

### Immediate (Tonight if energy):
**Use Monaco** - It already has markdown! Just use it.

### v2.3.1:
**Add mavonEditor** - Better UX with split-pane preview

### v2.3.2+:
**Add Tiptap Collaborative** - After extensive testing

---

## Next Steps for Tomorrow

1. **Review this document**
2. **Decide on approach:**
   - Quick win: Use Monaco (already have it)
   - Better UX: Add mavonEditor
   - Full featured: Add Tiptap collaborative
3. **Create implementation branch**
4. **Start coding**

---

## Important Notes

- **All three options export clean markdown** for spreadsheets ✅
- **Solo mode is safer** for mission-critical content
- **Collaborative mode needs Redis** for ActionCable
- **Test undo extensively** before any production use
- **Users should choose their risk tolerance**

---

## Questions to Answer Tomorrow

1. Do we have Redis running? (Check for ActionCable)
2. What fields need markdown? (vuln_discussion, check, fixtext, mitigations?)
3. Component-level or global setting for collaborative mode?
4. Should collaborative mode require reviewer/admin permission?
5. How long to keep Y.js history before garbage collection?

---

**Created:** 2025-11-26
**Author:** Aaron Lippold
**Status:** Ready for implementation
