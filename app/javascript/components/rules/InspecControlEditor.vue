<template>
  <div>
    <b-input-group size="sm" class="my-2">
      <b-input-group-prepend>
        <b-input-group-text class="rounded-0">Language</b-input-group-text>
      </b-input-group-prepend>
      <b-form-select
        id="language"
        class="form-select-sm"
        :value="monacoEditorOptions.language"
        @change="(value) => updateSettings('language', value)"
      >
        <option v-for="(option, idx) in options.languages" :key="idx" :value="option.value">
          {{ option.label }}
        </option>
      </b-form-select>
      <b-input-group-prepend>
        <b-input-group-text class="rounded-0">Theme</b-input-group-text>
      </b-input-group-prepend>
      <b-form-select
        id="theme"
        class="form-select-sm"
        :value="monacoEditorOptions.theme"
        @change="(value) => updateSettings('theme', value)"
      >
        <option v-for="(option, idx) in options.themes" :key="idx" :value="option.value">
          {{ option.label }}
        </option>
      </b-form-select>
      <b-button size="sm" squared @click="copyText">
        Copy
        <i class="mdi mdi-clipboard-text" aria-hidden="true" />
      </b-button>
    </b-input-group>
    <MonacoEditor
      id="inspec_control_body"
      :key="editorKey"
      :value="value"
      :options="monacoEditorOptions"
      width="auto"
      height="800"
      :language="monacoEditorOptions.language"
      :editor-mounted="colorize"
      @input="$root.$emit('update:rule', { ...rule, [field]: $event })"
    />
  </div>
</template>

<script>
import MonacoEditor from "monaco-editor-vue";

export default {
  name: "InspecControlEditor",
  components: { MonacoEditor },
  props: {
    rule: {
      type: Object,
      required: true,
    },
    field: {
      type: String,
      required: true,
    },
    readOnly: {
      type: Boolean,
      default: false,
    },
  },
  data: function () {
    return {
      value: this.rule[this.field],
      editorKey: 0,
      monacoEditorOptions: {
        automaticLayout: true,
        readOnly: this.readOnly,
        // semanticHighlighting: {
        //   enabled: true,
        // },
        language: "ruby",
        tabSize: 2,
        theme: "vs-dark",
      },
      options: {
        themes: [
          { value: "vs", label: "Visual Studio" },
          { value: "vs-dark", label: "Visual Studio Dark" },
          { value: "hc-black", label: "High Contrast Dark" },
        ],
        languages: [
          { value: "javascript", label: "JavaScript" },
          { value: "python", label: "Python" },
          { value: "ruby", label: "Ruby" },
        ],
      },
    };
  },
  watch: {
    rule: function (rule) {
      if (this.readOnly) {
        this.value = rule[this.field];
      }
    },
  },
  methods: {
    copyText: function () {
      navigator.clipboard.writeText(this.value);
      this.$bvToast.toast("Copied to clipboard", {
        title: "Copy",
        variant: "success",
        solid: true,
      });
    },
    updateSettings: function (setting, value) {
      this.monacoEditorOptions[setting] = value;
      this.editorKey += 1;
    },
    colorize: function (editor, monaco) {
      // monaco.editor.colorizeElement(document.getElementById(this.field));
    },
  },
};
</script>

<style scoped>
.form-select-sm {
  height: 2rem;
}
</style>
