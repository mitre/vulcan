<template>
  <div v-if="parentRules && parentRules.length > 0" class="satisfied-by-indicator">
    <div class="satisfied-by-indicator__banner">
      <div class="satisfied-by-indicator__header">
        <svg
          xmlns="http://www.w3.org/2000/svg"
          width="14"
          height="14"
          fill="currentColor"
          viewBox="0 0 16 16"
          class="satisfied-by-indicator__icon"
        >
          <path
            d="M4.715 6.542 3.343 7.914a3 3 0 1 0 4.243 4.243l1.828-1.829A3 3 0 0 0 8.586 5.5L8 6.086a1 1 0 0 0-.154.199 2 2 0 0 1 .861 3.337L6.88 11.45a2 2 0 1 1-2.83-2.83l.793-.792a4 4 0 0 1-.128-1.287z"
          />
          <path
            d="M6.586 4.672A3 3 0 0 0 7.414 9.5l.775-.776a2 2 0 0 1-.896-3.346L9.12 3.55a2 2 0 1 1 2.83 2.83l-.793.792c.112.42.155.855.128 1.287l1.372-1.372a3 3 0 1 0-4.243-4.243z"
          />
        </svg>
        <span class="satisfied-by-indicator__label">
          Satisfied by
          <template v-for="(parent, idx) in parentRules">
            <strong :key="parent.id" class="satisfied-by-indicator__parent-name">
              {{ parent.component_prefix || componentPrefix }}-{{ parent.rule_id }}
            </strong>
            <span v-if="idx < parentRules.length - 1" :key="'sep-' + parent.id">, </span>
          </template>
        </span>
      </div>

      <div class="satisfied-by-indicator__body">
        <slot />
      </div>

      <div class="satisfied-by-indicator__actions">
        <slot name="actions">
          <button
            v-for="parent in parentRules"
            :key="'nav-' + parent.id"
            class="btn btn-sm btn-outline-info satisfied-by-indicator__go-btn"
            data-testid="go-to-parent"
            @click="goToParent(parent.id)"
          >
            Go to {{ parent.component_prefix || componentPrefix }}-{{ parent.rule_id }} →
          </button>
        </slot>
      </div>
    </div>
  </div>
</template>

<script>
import { useRuleSelectionStore } from "../../stores/ruleSelection";

export default {
  name: "SatisfiedByIndicator",
  props: {
    parentRules: {
      type: Array,
      default: () => [],
    },
    componentPrefix: {
      type: String,
      default: "",
    },
  },
  setup() {
    const ruleStore = useRuleSelectionStore();
    return { ruleStore };
  },
  methods: {
    goToParent(parentId) {
      this.ruleStore.selectRule(parentId);
    },
  },
};
</script>

<style scoped>
.satisfied-by-indicator {
  container-type: inline-size;
  container-name: satisfied-by;
  margin-bottom: 0.5rem;
}

.satisfied-by-indicator__banner {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 0.5rem;
  padding: 0.5rem 0.75rem;
  border-radius: 0.25rem;
  border-left: 3px solid var(--vulcan-info, #17a2b8);
  background: var(--vulcan-tertiary-bg, #e9ecef);
  color: var(--vulcan-body-color, #212529);
}

.satisfied-by-indicator__icon {
  flex-shrink: 0;
  color: var(--vulcan-info, #17a2b8);
}

.satisfied-by-indicator__header {
  display: flex;
  align-items: center;
  gap: 0.375rem;
  font-size: 0.875rem;
}

.satisfied-by-indicator__label {
  color: var(--vulcan-secondary-color, rgba(33, 37, 41, 0.75));
}

.satisfied-by-indicator__parent-name {
  color: var(--vulcan-emphasis-color, #212529);
}

.satisfied-by-indicator__body {
  font-size: 0.8125rem;
  color: var(--vulcan-secondary-color, rgba(33, 37, 41, 0.75));
}

.satisfied-by-indicator__go-btn {
  font-size: 0.75rem;
  padding: 0.125rem 0.5rem;
  white-space: nowrap;
}

/* Narrow container (sidebar): badge-only mode */
@container satisfied-by (max-width: 250px) {
  .satisfied-by-indicator__banner {
    padding: 0.25rem 0.5rem;
    border-left-width: 2px;
    gap: 0.25rem;
  }

  .satisfied-by-indicator__body,
  .satisfied-by-indicator__actions {
    display: none;
  }

  .satisfied-by-indicator__label {
    font-size: 0.75rem;
  }
}

/* Medium container (triage pane): compact card */
@container satisfied-by (min-width: 251px) and (max-width: 500px) {
  .satisfied-by-indicator__body {
    display: none;
  }

  .satisfied-by-indicator__banner {
    flex-wrap: nowrap;
    justify-content: space-between;
  }
}

/* Wide container (editor): full banner — all content visible (default) */
</style>
