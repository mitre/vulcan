<template>
  <span class="section-label">{{ display }}</span>
</template>

<script>
import { sectionLabel } from "../../constants/triageVocabulary";

export default {
  name: "SectionLabel",
  // Component kind from the page/panel root; default keeps tests and
  // isolated mounts green.
  inject: {
    injectedDocumentType: { default: "stig" },
  },
  props: {
    section: { type: String, default: null },
    commentableType: { type: String, default: null },
    placeholder: { type: Boolean, default: false },
  },
  computed: {
    display() {
      if (this.section === null || this.section === undefined || this.section === "") {
        if (this.placeholder) return "—";
        return this.commentableType === "Component"
          ? "Overall Component"
          : sectionLabel(null, this.injectedDocumentType);
      }
      return sectionLabel(this.section, this.injectedDocumentType);
    },
  },
};
</script>
