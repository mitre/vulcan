<template>
  <span class="section-label">{{ display }}</span>
</template>

<script>
import { sectionLabel } from "@/constants/triageVocabulary";

export default {
  name: "SectionLabel",
  props: {
    section: { type: String, default: null },
    placeholder: { type: Boolean, default: false },
  },
  computed: {
    display() {
      if (this.section === null || this.section === undefined || this.section === "") {
        return this.placeholder ? "—" : "(general)";
      }
      return sectionLabel(this.section);
    },
  },
};
</script>
