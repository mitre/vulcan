<template>
  <div>
    <Rules
      :project="project"
      :component="component"
      :rules="rules"
      :statuses="statuses"
      :severities="severities"
      :severities_map="severities_map"
      :effective_permissions="effective_permissions"
      :current_user_id="current_user_id"
      :rule="selected_rule"
    />
  </div>
</template>

<script>
import Rules from "./Rules.vue";

export default {
  name: "Rule",
  components: { Rules },
  props: {
    effective_permissions: {
      type: String,
      required: true,
    },
    current_user_id: {
      type: Number,
      required: true,
    },
    project: {
      type: Object,
      required: true,
    },
    component: {
      type: Object,
      required: true,
    },
    rules: {
      type: Array,
      required: true,
    },
    selected_rule: {
      type: Object,
      required: true,
    },
    statuses: {
      type: Array,
      required: true,
    },
    severities: {
      type: Array,
      required: true,
    },
    severities_map: {
      type: Object,
      required: true,
    },
  },
};
</script>
<style scoped></style>
