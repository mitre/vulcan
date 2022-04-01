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
        @change="(value) => updateLanguage(value)"
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
        @change="(value) => updateTheme(value)"
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
      class="editor"
      :language="monacoEditorOptions.language"
      @change="$root.$emit('update:rule', { ...rule, [field]: $event })"
    />
  </div>
</template>

<script>
import MonacoEditor from "vue-monaco";

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
      value: this.rule[this.field] || "",
      editorKey: 0,
      monacoEditorOptions: {
        automaticLayout: true,
        readOnly: this.readOnly,
        language: this.rule[`${this.field}_lang`] || "ruby",
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
          { value: "ruby", label: "Ruby" },
          { value: "markdown", label: "Markdown" },
          { value: "json", label: "JSON" },
          { value: "yaml", label: "YAML" },
        ],
      },
    };
  },
  watch: {
    rule: function (rule) {
      this.value = rule[this.field] || "";
      this.monacoEditorOptions.language = this.rule[`${this.field}_lang`] || "ruby";
    },
  },
  mounted: function () {
    // Load saved theme
    const savedTheme = localStorage.getItem("monacoEditorTheme");
    if (savedTheme) {
      this.monacoEditorOptions.theme = savedTheme;
      this.editorKey += 1;
    }
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
    updateLanguage: function (value) {
      this.monacoEditorOptions.language = value;
      this.editorKey += 1;
      const updatedRule = this.rule;
      updatedRule[`${this.field}_lang`] = value;
      this.$root.$emit("update:rule", updatedRule);
    },
    updateTheme: function (value) {
      this.monacoEditorOptions.theme = value;
      this.editorKey += 1;
      localStorage.setItem("monacoEditorTheme", value);
    },
  },
};
</script>

<style scoped>
.form-select-sm {
  height: 2rem;
}
.editor {
  width: auto;
  height: 800px;
}
</style>

<style>
.suggest-widget {
  border: none !important;
}
</style>
