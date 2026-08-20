<template>
  <div class="filter-group" :class="{ 'filter-group-disabled': disabled }">
    <div class="filter-group-header">
      <strong>{{ title }}</strong>
      <span v-if="!disabled" class="reset-link" @click="$emit('reset')">reset</span>
    </div>
    <div class="filter-group-body">
      <div v-for="item in items" :key="item.key" class="filter-item d-flex align-items-center">
        <b-form-checkbox
          :id="`filter-${instanceId}-${item.key}`"
          :checked="item.checked"
          :disabled="disabled || !!item.disabled"
          :aria-describedby="item.disabledReason ? reasonId(item) : null"
          switch
          size="sm"
          @change="onToggleChange(item.key, $event)"
        >
          <!-- Optional status color dot — reuses the single-source-of-truth
               .status-dot[data-status] palette (rule-status-tints.css) so the
               filter toggle carries the same color as the sidebar/badge for
               that status. Decorative only: aria-hidden, the label conveys the
               status to assistive tech (WCAG 1.4.1). -->
          <span
            v-if="item.dot"
            class="status-dot mr-1"
            :data-status="item.dot"
            aria-hidden="true"
          />{{ item.label }}<template v-if="item.count !== undefined"> ({{ item.count }})</template>
        </b-form-checkbox>
        <!-- The info icon carries the reason for SIGHTED users and is
             aria-hidden, so an aria-label on it would never be announced.
             The same text therefore lives in a visually-hidden element that
             the control points at with aria-describedby — otherwise a screen
             reader reports a disabled switch and never says why. -->
        <InfoTooltip v-if="item.disabledReason" :text="item.disabledReason" />
        <span v-if="item.disabledReason" :id="reasonId(item)" class="sr-only">
          {{ item.disabledReason }}
        </span>
      </div>
    </div>
  </div>
</template>

<script>
import InfoTooltip from "./InfoTooltip.vue";

export default {
  name: "FilterGroup",
  components: { InfoTooltip },
  props: {
    title: {
      type: String,
      required: true,
    },
    items: {
      type: Array,
      required: true,
      // items: [{ key: string, label: string, count?: number, checked: boolean,
      //           dot?: string /* status value → colored .status-dot */,
      //           disabled?: boolean, disabledReason?: string }]
    },
    disabled: {
      type: Boolean,
      default: false,
    },
  },
  data() {
    return {
      instanceId: crypto.randomUUID().slice(0, 8),
    };
  },
  methods: {
    reasonId(item) {
      return `filter-${this.instanceId}-${item.key}-reason`;
    },
    onToggleChange(key, checked) {
      const updatedItems = this.items.map((item) => {
        if (item.key === key) {
          return { ...item, checked };
        }
        return item;
      });
      this.$emit("update:items", updatedItems);
    },
  },
};
</script>

<style scoped>
.filter-group {
  min-width: 200px;
  border: 1px solid var(--vulcan-gray-400);
  border-radius: 0.375rem;
  background-color: var(--vulcan-component-bg, #fff);
  box-shadow: var(--vulcan-shadow-subtle);
}

.filter-group-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  font-size: 0.875rem;
  background-color: var(--vulcan-component-bg-alt, var(--vulcan-gray-100));
  border-bottom: 1px solid var(--vulcan-gray-400);
  padding: 0.5rem 0.75rem;
  border-radius: 0.375rem 0.375rem 0 0;
}

.filter-group-body {
  font-size: 0.8125rem;
  padding: 0.5rem 0.75rem;
}

.filter-item {
  padding: 0.125rem 0;
}

.reset-link {
  font-size: 0.75rem;
  color: var(--vulcan-primary);
  cursor: pointer;
}

.reset-link:hover {
  text-decoration: underline;
}

/* Disabled state — same surface as active panels, subtly dimmed */
.filter-group-disabled {
  opacity: 0.75;
}

.filter-group-disabled .filter-group-header {
  color: var(--vulcan-secondary);
}

.filter-group-disabled .filter-group-body {
  pointer-events: none;
  color: var(--vulcan-secondary);
}

/* Grey out switch toggles when disabled */
.filter-group-disabled :deep(.custom-switch .custom-control-label::before) {
  background-color: var(--vulcan-gray-300);
  border-color: var(--vulcan-gray-500);
}

.filter-group-disabled :deep(.custom-switch .custom-control-label::after) {
  background-color: var(--vulcan-gray-500);
}

.filter-group-disabled :deep(.custom-control-label) {
  color: var(--vulcan-secondary);
}
</style>
