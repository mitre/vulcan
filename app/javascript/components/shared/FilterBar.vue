<template>
  <div class="filter-bar d-flex flex-wrap justify-content-between">
    <!-- Status Group -->
    <FilterGroup
      v-if="showStatus"
      title="Status"
      :items="statusItems"
      :disabled="disabledStatus"
      @update:items="onGroupUpdate"
      @reset="onStatusReset"
    />

    <!-- Display Group -->
    <FilterGroup
      v-if="showDisplay"
      title="Display"
      :items="displayItems"
      :disabled="disabledDisplay"
      @update:items="onGroupUpdate"
      @reset="onDisplayReset"
    />

    <!-- Review Group (last - toggles on/off between modes) -->
    <FilterGroup
      v-if="showReview"
      title="Review"
      :items="reviewItems"
      :disabled="disabledReview"
      @update:items="onGroupUpdate"
      @reset="onReviewReset"
    />
  </div>
</template>

<script>
import FilterGroup from "./FilterGroup.vue";
import { getDefaultFilters } from "../../composables/useRuleFilters";
import { groupEntries, appliesToKind } from "../../constants/ruleFilterRegistry";

export default {
  name: "FilterBar",
  components: { FilterGroup },
  props: {
    filters: {
      type: Object,
      required: true,
    },
    counts: {
      type: Object,
      default: () => ({}),
    },
    showStatus: {
      type: Boolean,
      default: true,
    },
    showReview: {
      type: Boolean,
      default: true,
    },
    showDisplay: {
      type: Boolean,
      default: true,
    },
    disabledStatus: {
      type: Boolean,
      default: false,
    },
    disabledReview: {
      type: Boolean,
      default: false,
    },
    disabledDisplay: {
      type: Boolean,
      default: false,
    },
    // The page's document kind. Entries the registry limits to another kind
    // render disabled with the registry's reason rather than silently doing
    // nothing.
    documentType: {
      type: String,
      default: "stig",
    },
  },
  computed: {
    // Derived from the vocabulary-keyed statusFilters map — the bar renders
    // whatever statuses the page's kind provides, in vocabulary order.
    statusItems() {
      const statusCounts = this.counts.statusCounts || {};
      return Object.entries(this.filters.statusFilters).map(([status, checked]) => ({
        key: status,
        label: status,
        count: statusCounts[status],
        checked,
      }));
    },
    // Review counts are keyed by a short name on the counts payload; the
    // registry owns the key, label and applicability.
    reviewItems() {
      const countFor = {
        nurFilterChecked: this.counts.nur,
        urFilterChecked: this.counts.ur,
        lckFilterChecked: this.counts.lck,
      };
      return groupEntries("review").map((entry) =>
        this.itemFor(entry, { count: countFor[entry.key] }),
      );
    },
    displayItems() {
      return groupEntries("display").map((entry) => this.itemFor(entry));
    },
  },
  methods: {
    // One place turns a registry entry into a rendered item, so key, label
    // and applicability are never restated per group. A toggle that cannot
    // act on this document kind renders disabled and SAYS SO — silently
    // inert controls are how a toggle looks functional while doing nothing.
    itemFor(entry, extra = {}) {
      const usable = appliesToKind(entry.key, this.documentType);
      return {
        key: entry.key,
        label: entry.label,
        // Show the EFFECTIVE value: an entry this kind cannot act on is off
        // no matter what is stored, because rendering it on would claim an
        // effect that provably is not happening.
        checked: usable && this.filters[entry.key],
        disabled: !usable,
        // The reason is the registry's to state — it knows WHY an entry is
        // limited to a kind. Composing it here would put kind-specific
        // wording back into the component.
        ...(usable ? {} : { disabledReason: entry.unavailableReason }),
        ...extra,
      };
    },
    // An item key is either a status value (statusFilters key) or a
    // kind-free named key — status values can never collide with the
    // named keys, so routing by membership is safe.
    emitUpdatedFilters(updates) {
      const statusUpdates = {};
      const namedUpdates = {};
      Object.entries(updates).forEach(([key, value]) => {
        if (key in this.filters.statusFilters) {
          statusUpdates[key] = value;
        } else {
          namedUpdates[key] = value;
        }
      });
      const newFilters = {
        ...this.filters,
        ...namedUpdates,
        statusFilters: { ...this.filters.statusFilters, ...statusUpdates },
      };
      this.$emit("update:filters", newFilters);
    },
    onGroupUpdate(items) {
      const updates = {};
      items.forEach((item) => {
        // A group re-emits its WHOLE item array on any single toggle, and a
        // disabled item renders its EFFECTIVE value rather than the stored
        // one. Writing that back would persist a value the user cannot even
        // operate, silently overwriting what they chose on another kind.
        if (item.disabled) return;
        updates[item.key] = item.checked;
      });
      this.emitUpdatedFilters(updates);
    },
    onStatusReset() {
      const updates = {};
      Object.keys(this.filters.statusFilters).forEach((status) => {
        updates[status] = false;
      });
      this.emitUpdatedFilters(updates);
    },
    // Which keys a group resets is the registry's list, not a copy of it —
    // a copy is how a new toggle ends up silently un-resettable.
    resetGroup(groupKey) {
      const defaults = getDefaultFilters(Object.keys(this.filters.statusFilters));
      const updates = {};
      groupEntries(groupKey).forEach((entry) => {
        updates[entry.key] = defaults[entry.key];
      });
      this.emitUpdatedFilters(updates);
    },
    onReviewReset() {
      this.resetGroup("review");
    },
    onDisplayReset() {
      this.resetGroup("display");
    },
  },
};
</script>

<style scoped>
.filter-bar {
  gap: 0.75rem;
  align-items: stretch; /* Unify heights */
  background-color: var(--vulcan-gray-100);
  border: 1px solid var(--vulcan-gray-300);
  border-radius: 0.375rem;
  padding: 0.75rem;
}

.filter-bar > * {
  flex: 1; /* Equal width distribution */
}

@media (max-width: 767.98px) {
  .filter-bar {
    flex-direction: column;
  }

  .filter-bar > * {
    width: 100%;
    flex: none;
  }
}
</style>
