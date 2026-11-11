<template>
  <div />
</template>

<script>
import { monaco } from "../../utils/monaco";

/**
 * A Monaco code editor, or a side-by-side diff editor when `diff` is set.
 *
 * `value` is the editor's text (the modified side of a diff); `original` is
 * the original side of a diff. Edits are emitted as `change` with the new
 * text. When `value` comes back from the parent unchanged (the parent echoing
 * an edit) the editor, its cursor and its undo history are left alone. When
 * it differs, the parent is showing a different document (another rule was
 * selected, or the text was regenerated): the content is replaced outright,
 * which resets the undo history so undo cannot bring the previous document
 * back, and the replacement is not reported as a `change`.
 */
export default {
  name: "MonacoEditor",
  props: {
    value: {
      type: String,
      default: "",
    },
    original: {
      type: String,
      default: "",
    },
    diff: {
      type: Boolean,
      default: false,
    },
    language: {
      type: String,
      default: "plaintext",
    },
    theme: {
      type: String,
      default: "vs",
    },
    options: {
      type: Object,
      default: () => ({}),
    },
  },
  watch: {
    value(value) {
      this.applyValue(this.diff ? this.editor.getModifiedEditor() : this.editor, value);
    },
    original(original) {
      if (this.diff) this.editor.getModel().original.setValue(original);
    },
    language(language) {
      this.models().forEach((model) => monaco.editor.setModelLanguage(model, language));
    },
    theme(theme) {
      monaco.editor.setTheme(theme);
    },
    options: {
      deep: true,
      handler(options) {
        this.editor.updateOptions(options);
      },
    },
  },
  mounted() {
    // Editor objects are kept off `data` so Vue does not make them reactive.
    const options = { ...this.options, theme: this.theme };
    if (this.diff) {
      this.editor = monaco.editor.createDiffEditor(this.$el, options);
      this.editor.setModel({
        original: monaco.editor.createModel(this.original, this.language),
        modified: monaco.editor.createModel(this.value, this.language),
      });
    } else {
      this.editor = monaco.editor.create(this.$el, {
        ...options,
        value: this.value,
        language: this.language,
      });
      this.editor.onDidChangeModelContent((event) => {
        // setValue flushes the model; that is applyValue replacing the
        // document, not the user editing it.
        if (event.isFlush) return;
        this.$emit("change", this.editor.getValue());
      });
    }
  },
  beforeDestroy() {
    // A plain editor owns the model it created from `value`; the diff editor's
    // two models were created here and are disposed here.
    const ownModels = this.diff ? this.models() : [];
    this.editor.dispose();
    ownModels.forEach((model) => model.dispose());
  },
  methods: {
    models() {
      if (!this.editor) return [];
      if (this.diff) {
        const { original, modified } = this.editor.getModel();
        return [original, modified];
      }
      return [this.editor.getModel()];
    },
    applyValue(editor, value) {
      if (value !== editor.getValue()) editor.setValue(value);
    },
  },
};
</script>
