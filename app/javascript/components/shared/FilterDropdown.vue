<template>
  <b-dropdown
    :text="currentLabel"
    :variant="variant"
    :size="size"
    :menu-class="menuClass"
    :toggle-attrs="{ 'aria-label': ariaLabel }"
    :class="dropdownClass"
    :style="rootStyle"
    boundary="viewport"
  >
    <b-dropdown-item-button
      v-for="option in options"
      :key="optionKey(option)"
      :active="option.value === value"
      @click="$emit('input', option.value)"
    >
      {{ option.text }}
    </b-dropdown-item-button>
  </b-dropdown>
</template>

<script>
/**
 * Generic filter dropdown used by ComponentComments, RuleReviews, UserComments.
 *
 * Why this exists: <b-form-select> wraps the browser-controlled native
 * <select> element, whose dropdown is browser-positioned and ignores Vue
 * boundary props. In slideovers and narrow panels the menu clips at
 * viewport edges (caught live on rule reviews slideover, Apr 29 2026).
 *
 * <b-dropdown> with boundary="viewport" + auto-flip stays inside the
 * visible window. This component centralizes that pattern so consumers
 * don't reinvent it.
 *
 * v-model emits "input" on selection, matching Vue 2 v-model conventions.
 * Null-valued options (e.g. section "(general)" → null) are supported.
 */
export default {
  name: "FilterDropdown",
  props: {
    value: {
      type: [String, Number, Boolean],
      default: null,
    },
    options: {
      type: Array,
      required: true,
      validator: (arr) => arr.every((o) => Object.hasOwn(o, "value") && "text" in o),
    },
    ariaLabel: { type: String, required: true },
    size: { type: String, default: "sm" },
    variant: { type: String, default: "outline-secondary" },
    placeholder: { type: String, default: "Select..." },
    maxWidthPx: { type: Number, default: null },
    dropdownClass: { type: [String, Array, Object], default: null },
    menuClass: { type: [String, Array, Object], default: null },
  },
  computed: {
    currentLabel() {
      const match = this.options.find((o) => o.value === this.value);
      return match ? match.text : this.placeholder;
    },
    rootStyle() {
      return this.maxWidthPx ? { maxWidth: `${this.maxWidthPx}px` } : null;
    },
  },
  methods: {
    optionKey(option) {
      // Stable Vue keys — null and undefined can't be used directly as :key
      if (option.value === null) return "__null__";
      if (option.value === undefined) return "__undefined__";
      return String(option.value);
    },
  },
};
</script>
