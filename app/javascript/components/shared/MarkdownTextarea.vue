<!-- eslint-disable vue/no-v-html -->
<template>
  <div class="markdown-textarea">
    <!-- Read-only preview (shown when disabled) -->
    <div
      v-if="disabled"
      class="markdown-preview form-control bg-light"
      :class="containerClass"
      :style="previewStyle"
      v-html="renderedContent"
    />

    <!-- EasyMDE editor (shown when editable) -->
    <div v-else class="easymde-wrapper" :class="containerClass">
      <textarea :id="id" ref="textarea" />
    </div>
  </div>
</template>

<script>
import EasyMDE from "easymde";
import "easymde/dist/easymde.min.css";
import { marked } from "marked";
import DOMPurify from "dompurify";
import { highlightCode } from "../../utilities/syntaxHighlighter";

// Configure marked with custom code block renderer for syntax highlighting
const renderer = new marked.Renderer();
renderer.code = function (code, language) {
  const codeText = typeof code === "object" ? code.text : code;
  const lang = typeof code === "object" ? code.lang : language;
  return highlightCode(codeText || "", lang || "text");
};

export default {
  name: "MarkdownTextarea",
  props: {
    id: {
      type: String,
      default: "",
    },
    value: {
      type: String,
      default: "",
    },
    placeholder: {
      type: String,
      default: "",
    },
    disabled: {
      type: Boolean,
      default: false,
    },
    rows: {
      type: [Number, String],
      default: 1,
    },
    maxRows: {
      type: [Number, String],
      default: 99,
    },
    inputClass: {
      type: [String, Array, Object],
      default: "",
    },
    containerClass: {
      type: [String, Array, Object],
      default: "",
    },
  },
  data() {
    return {
      easyMDE: null,
    };
  },
  computed: {
    renderedContent() {
      if (!this.value) {
        return '<span class="text-muted font-italic">No content</span>';
      }
      const html = marked.parse(this.value, { breaks: false, renderer });
      return DOMPurify.sanitize(html);
    },
    previewStyle() {
      return {
        minHeight: `${(Number.parseInt(this.rows) || 1) * 1.5 + 1.5}rem`,
        height: "auto",
        overflow: "auto",
      };
    },
    minHeight() {
      // Calculate min height based on rows prop
      const rowHeight = 24; // approximate line height in pixels
      return `${(Number.parseInt(this.rows) || 3) * rowHeight}px`;
    },
  },
  watch: {
    value(newValue) {
      // Sync external value changes to EasyMDE
      if (this.easyMDE && this.easyMDE.value() !== newValue) {
        this.easyMDE.value(newValue || "");
      }
    },
    disabled(newDisabled) {
      // Reinitialize when switching between disabled/enabled
      if (newDisabled) {
        this.destroyEasyMDE();
      } else {
        this.$nextTick(() => {
          this.initEasyMDE();
        });
      }
    },
  },
  mounted() {
    if (!this.disabled) {
      this.initEasyMDE();
    }
  },
  beforeDestroy() {
    this.destroyEasyMDE();
  },
  methods: {
    initEasyMDE() {
      if (this.easyMDE) {
        this.destroyEasyMDE();
      }

      // Wait for DOM to be ready
      this.$nextTick(() => {
        if (!this.$refs.textarea) return;

        this.easyMDE = new EasyMDE({
          element: this.$refs.textarea,
          initialValue: this.value || "",
          placeholder: this.placeholder || "Write markdown here...",
          spellChecker: false,
          status: false,
          minHeight: this.minHeight,
          autofocus: false,
          // Toolbar optimized for security documentation
          toolbar: [
            "bold",
            "italic",
            "heading",
            "|",
            "code",
            "quote",
            "|",
            "unordered-list",
            "ordered-list",
            "|",
            "link",
            "table",
            "horizontal-rule",
            "|",
            "undo",
            "redo",
            "|",
            "preview",
            "guide",
          ],
          // Disable fullscreen modes - they break out of the app container
          sideBySideFullscreen: false,
          // Use our custom renderer with Shiki highlighting
          previewRender: function (plainText) {
            const html = marked.parse(plainText, { breaks: false, renderer });
            return DOMPurify.sanitize(html);
          },
          renderingConfig: {
            singleLineBreaks: false,
          },
        });

        // Apply toolbar styles via JS to bypass CSS specificity issues
        this.applyToolbarStyles();

        // Emit changes to parent
        this.easyMDE.codemirror.on("change", () => {
          const newValue = this.easyMDE.value();
          if (newValue !== this.value) {
            this.$emit("input", newValue);
          }
        });
      });
    },
    destroyEasyMDE() {
      if (this.easyMDE) {
        this.easyMDE.toTextArea();
        this.easyMDE = null;
      }
    },
    applyToolbarStyles() {
      // Apply styles directly via JavaScript to bypass CSS specificity issues
      // EasyMDE creates elements dynamically which can bypass Vue scoped styles
      const wrapper = this.$el;
      if (!wrapper) return;

      const toolbar = wrapper.querySelector(".editor-toolbar");
      if (toolbar) {
        // Force single-line toolbar with horizontal scroll if needed
        toolbar.style.whiteSpace = "nowrap";
        toolbar.style.overflowX = "auto";
        toolbar.style.display = "block";
        toolbar.style.padding = "4px 5px";
        toolbar.style.background = "#f8f9fa";

        // Compact button sizing
        const buttons = toolbar.querySelectorAll("button");
        buttons.forEach((btn) => {
          btn.style.width = "26px";
          btn.style.height = "26px";
          btn.style.minWidth = "26px";
          btn.style.margin = "0 1px";
          btn.style.padding = "0";
        });

        // Compact separators
        const separators = toolbar.querySelectorAll("i.separator");
        separators.forEach((sep) => {
          sep.style.margin = "0 3px";
        });
      }
    },
  },
};
</script>

<style scoped>
/* Read-only preview styles */
.markdown-preview {
  line-height: 1.5;
  word-wrap: break-word;
}

.markdown-preview :deep(p) {
  margin-bottom: 0.5rem;
}

.markdown-preview :deep(p:last-child) {
  margin-bottom: 0;
}

.markdown-preview :deep(ul),
.markdown-preview :deep(ol) {
  margin-bottom: 0.5rem;
  padding-left: 1.5rem;
}

.markdown-preview :deep(code) {
  background-color: rgba(0, 0, 0, 0.05);
  padding: 0.125rem 0.25rem;
  border-radius: 0.25rem;
  font-size: 0.875em;
}

.markdown-preview :deep(pre) {
  background-color: rgba(0, 0, 0, 0.05);
  padding: 0.5rem;
  border-radius: 0.25rem;
  overflow-x: auto;
  margin-bottom: 0.5rem;
  white-space: pre-wrap;
}

.markdown-preview :deep(pre code) {
  background-color: transparent;
  padding: 0;
}

/* Shiki syntax highlighting styles */
.markdown-preview :deep(.shiki) {
  background-color: #f6f8fa !important;
  padding: 0.75rem;
  border-radius: 0.375rem;
  overflow-x: auto;
  margin-bottom: 0.5rem;
  font-size: 0.875rem;
  line-height: 1.5;
  white-space: pre-wrap;
}

.markdown-preview :deep(.shiki code) {
  background-color: transparent;
  padding: 0;
  font-family:
    ui-monospace, SFMono-Regular, "SF Mono", Menlo, Consolas, "Liberation Mono", monospace;
}

.markdown-preview :deep(blockquote) {
  border-left: 3px solid #dee2e6;
  padding-left: 0.75rem;
  margin-left: 0;
  margin-bottom: 0.5rem;
  color: #6c757d;
}

.markdown-preview :deep(a) {
  color: #007bff;
  text-decoration: none;
}

.markdown-preview :deep(a:hover) {
  text-decoration: underline;
}

.markdown-preview :deep(h1),
.markdown-preview :deep(h2),
.markdown-preview :deep(h3),
.markdown-preview :deep(h4),
.markdown-preview :deep(h5),
.markdown-preview :deep(h6) {
  margin-top: 0.5rem;
  margin-bottom: 0.5rem;
  font-weight: 600;
}

.markdown-preview :deep(table) {
  border-collapse: collapse;
  width: 100%;
  margin-bottom: 0.5rem;
}

.markdown-preview :deep(th),
.markdown-preview :deep(td) {
  border: 1px solid #dee2e6;
  padding: 0.25rem 0.5rem;
}

.markdown-preview :deep(th) {
  background-color: rgba(0, 0, 0, 0.03);
}

/* EasyMDE customizations */
/* Note: Toolbar button sizing is handled via JavaScript in applyToolbarStyles() */
/* to bypass CSS specificity issues with EasyMDE's dynamically created elements */

.easymde-wrapper :deep(.CodeMirror) {
  border: 1px solid #ced4da;
  border-radius: 0 0 0.25rem 0.25rem;
  font-size: 0.875rem;
  font-family: ui-monospace, SFMono-Regular, "SF Mono", Menlo, Consolas, monospace;
  min-height: 80px;
}

.easymde-wrapper :deep(.CodeMirror-focused) {
  border-color: #80bdff;
  box-shadow: 0 0 0 0.2rem rgba(0, 123, 255, 0.25);
}

.easymde-wrapper :deep(.editor-toolbar) {
  border: 1px solid #ced4da;
  border-bottom: none;
  border-radius: 0.25rem 0.25rem 0 0;
}

.easymde-wrapper :deep(.editor-toolbar button i) {
  font-size: 14px;
}

/* Hide the before/after pseudo elements that EasyMDE uses for fullscreen gradients */
.easymde-wrapper :deep(.editor-toolbar::before),
.easymde-wrapper :deep(.editor-toolbar::after) {
  display: none !important;
}

.easymde-wrapper :deep(.editor-preview),
.easymde-wrapper :deep(.editor-preview-side) {
  padding: 0.75rem;
  background: #fff;
}

/* Constrain fullscreen/side-by-side to component */
.easymde-wrapper :deep(.EasyMDEContainer.sided--no-fullscreen) {
  position: relative;
}

.easymde-wrapper :deep(.editor-preview-side) {
  position: absolute;
  top: 0;
  right: 0;
  bottom: 0;
  left: 50%;
  border-left: 1px solid #ced4da;
}

/* Disable true fullscreen - keep within container */
.easymde-wrapper :deep(.CodeMirror-fullscreen),
.easymde-wrapper :deep(.editor-preview-active-side) {
  position: absolute !important;
  z-index: 10;
}

/* Shiki styles in EasyMDE preview */
.easymde-wrapper :deep(.editor-preview .shiki),
.easymde-wrapper :deep(.editor-preview-side .shiki) {
  background-color: #f6f8fa !important;
  padding: 0.75rem;
  border-radius: 0.375rem;
  overflow-x: auto;
  margin-bottom: 0.5rem;
  font-size: 0.875rem;
  line-height: 1.5;
}

.easymde-wrapper :deep(.editor-preview .shiki code),
.easymde-wrapper :deep(.editor-preview-side .shiki code) {
  background-color: transparent;
  padding: 0;
  font-family:
    ui-monospace, SFMono-Regular, "SF Mono", Menlo, Consolas, "Liberation Mono", monospace;
}

/* Make preview code blocks look consistent */
.easymde-wrapper :deep(.editor-preview pre),
.easymde-wrapper :deep(.editor-preview-side pre) {
  background-color: #f6f8fa;
  padding: 0.75rem;
  border-radius: 0.375rem;
  overflow-x: auto;
}
</style>
