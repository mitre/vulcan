<template>
  <div class="triage-rule-sidebar">
    <h6 data-testid="sidebar-header" class="px-2 pt-0 pb-1 border-bottom mb-0 font-weight-bold">
      {{ totalPending }} of {{ comments.length }} pending
    </h6>
    <div class="px-2 py-1 d-flex align-items-center">
      <input
        v-model="searchText"
        type="text"
        class="form-control form-control-sm flex-grow-1"
        placeholder="Filter rules..."
        data-testid="sidebar-search"
      />
      <b-button
        v-b-tooltip.hover
        size="sm"
        variant="link"
        class="p-0 ml-2 text-muted flex-shrink-0"
        :title="allGroupsExpanded ? 'Collapse all groups' : 'Expand all groups'"
        data-testid="toggle-sidebar-groups"
        @click="toggleAllGroups"
      >
        <b-icon :icon="allGroupsExpanded ? 'arrows-collapse' : 'arrows-expand'" />
      </b-button>
    </div>
    <hr class="my-1" />
    <div
      ref="sidebarList"
      data-testid="sidebar-list"
      class="sidebar-list"
      role="listbox"
      aria-label="Comments by rule"
      tabindex="0"
      @keydown="handleKeydown"
    >
      <template v-for="(item, idx) in flatItems">
        <div
          v-if="item.type === 'group'"
          :key="'hdr-' + item.group.key"
          data-testid="sidebar-rule-header"
          class="sidebar-rule-header px-2 py-1 border-bottom small d-flex align-items-center"
          :class="{
            'sidebar-rule--active': isActiveGroup(item.group),
            'sidebar-focused': focusedIndex === idx,
          }"
          role="option"
          :aria-selected="String(isActiveGroup(item.group))"
          tabindex="-1"
          @click="toggleGroup(item.group)"
          @keydown.enter="selectGroup(item.group)"
          @keydown.space.prevent="toggleGroup(item.group)"
        >
          <strong
            v-b-tooltip.hover
            :title="item.group.ruleName"
            class="flex-grow-1 text-truncate"
            >{{ item.group.ruleName }}</strong
          >
          <span
            v-b-tooltip.hover
            :title="`${item.group.pendingCount} pending / ${item.group.comments.length} total`"
            class="badge badge-pill ml-1"
            :class="item.group.pendingCount > 0 ? 'badge-warning' : 'badge-secondary'"
          >
            {{ item.group.pendingCount }}/{{ item.group.comments.length }}
          </span>
        </div>
        <div
          v-else
          :key="item.comment.id"
          data-testid="sidebar-comment-item"
          class="sidebar-comment-item px-3 py-1 small d-flex align-items-center border-bottom"
          :class="{
            'sidebar-comment--active': item.comment.id === normalizedCurrentId,
            'sidebar-focused': focusedIndex === idx,
          }"
          role="option"
          :aria-selected="String(item.comment.id === normalizedCurrentId)"
          tabindex="-1"
          @click="$emit('select', item.comment.id)"
          @keydown.enter="$emit('select', item.comment.id)"
          @keydown.space.prevent="$emit('select', item.comment.id)"
        >
          <span class="text-muted mr-1">#{{ item.comment.id }}</span>
          <span v-if="item.comment.parent_rule_displayed_name" class="text-muted text-truncate">
            · {{ item.comment.rule_displayed_name }}
          </span>
          <span v-else-if="item.comment.section" class="text-muted text-truncate">
            · {{ item.comment.section }}
          </span>
        </div>
      </template>
    </div>
  </div>
</template>

<script>
export default {
  name: "TriageRuleSidebar",
  props: {
    comments: { type: Array, required: true },
    currentId: { type: [Number, String], default: null },
  },
  data() {
    return {
      searchText: "",
      focusedIndex: -1,
      expandedGroups: {},
    };
  },
  computed: {
    normalizedCurrentId() {
      return this.currentId != null ? Number(this.currentId) : null;
    },
    totalPending() {
      return this.comments.filter((c) => c.triage_status === "pending").length;
    },
    ruleGroups() {
      const groups = [];
      const seen = new Map();
      for (const c of this.comments) {
        const key = c.group_rule_displayed_name || c.rule_displayed_name || "(component)";
        if (!seen.has(key)) {
          const group = {
            key,
            ruleName: key,
            comments: [],
            pendingCount: 0,
          };
          seen.set(key, group);
          groups.push(group);
        }
        const g = seen.get(key);
        g.comments.push(c);
        if (c.triage_status === "pending") g.pendingCount++;
      }
      return groups.sort((a, b) => {
        const aComp = a.key === "(component)";
        const bComp = b.key === "(component)";
        if (aComp && !bComp) return -1;
        if (!aComp && bComp) return 1;
        return a.ruleName.localeCompare(b.ruleName, undefined, { numeric: true });
      });
    },
    filteredGroups() {
      if (!this.searchText) return this.ruleGroups;
      const q = this.searchText.toLowerCase();
      return this.ruleGroups.filter((g) => g.ruleName.toLowerCase().includes(q));
    },
    activeGroupKey() {
      if (this.normalizedCurrentId == null) return null;
      const comment = this.comments.find((c) => c.id === this.normalizedCurrentId);
      if (!comment) return null;
      return comment.group_rule_displayed_name || comment.rule_displayed_name || "(component)";
    },
    flatItems() {
      const items = [];
      for (const group of this.filteredGroups) {
        items.push({ type: "group", group });
        if (this.isActiveGroup(group)) {
          for (const c of group.comments) {
            items.push({ type: "comment", comment: c, group });
          }
        }
      }
      return items;
    },
    allGroupsExpanded() {
      return this.filteredGroups.every((g) => this.expandedGroups[g.key] === true);
    },
  },
  watch: {
    activeGroupKey: {
      immediate: true,
      handler(newKey) {
        if (newKey && !this.expandedGroups[newKey]) {
          this.$set(this.expandedGroups, newKey, true);
        }
      },
    },
    normalizedCurrentId(id) {
      if (id == null) return;
      const idx = this.flatItems.findIndex(
        (item) => item.type === "comment" && item.comment.id === id,
      );
      if (idx >= 0) this.focusedIndex = idx;
    },
  },
  methods: {
    isActiveGroup(group) {
      return this.expandedGroups[group.key] === true;
    },
    toggleAllGroups() {
      const expand = !this.allGroupsExpanded;
      for (const g of this.filteredGroups) {
        this.$set(this.expandedGroups, g.key, expand);
      }
    },
    toggleGroup(group) {
      if (this.expandedGroups[group.key]) {
        this.$set(this.expandedGroups, group.key, false);
      } else {
        for (const g of this.filteredGroups) {
          this.$set(this.expandedGroups, g.key, false);
        }
        this.$set(this.expandedGroups, group.key, true);
        this.$emit("select", group.comments[0].id);
      }
    },
    selectGroup(group) {
      this.$set(this.expandedGroups, group.key, true);
      this.$emit("select", group.comments[0].id);
    },
    handleKeydown(event) {
      const items = this.flatItems;
      if (!items.length) return;

      if (event.key === "ArrowDown" || event.key === "ArrowUp") {
        event.preventDefault();
        if (event.key === "ArrowDown") {
          this.focusedIndex = this.focusedIndex < items.length - 1 ? this.focusedIndex + 1 : 0;
        } else {
          this.focusedIndex = this.focusedIndex > 0 ? this.focusedIndex - 1 : items.length - 1;
        }
        this.$nextTick(() => this.scrollFocusedIntoView());
      } else if (event.key === "Enter") {
        event.preventDefault();
        if (this.focusedIndex >= 0 && this.focusedIndex < items.length) {
          const item = items[this.focusedIndex];
          if (item.type === "group") {
            this.selectGroup(item.group);
          } else {
            this.$emit("select", item.comment.id);
          }
        }
      } else if (event.key === " ") {
        event.preventDefault();
        if (this.focusedIndex >= 0 && this.focusedIndex < items.length) {
          const item = items[this.focusedIndex];
          if (item.type === "group") {
            this.toggleGroup(item.group);
          } else {
            this.$emit("select", item.comment.id);
          }
        }
      }
    },
    scrollFocusedIntoView() {
      const el = this.$refs.sidebarList?.querySelector(".sidebar-focused");
      if (el && el.scrollIntoView) {
        el.scrollIntoView({ block: "nearest" });
      }
    },
  },
};
</script>

<style scoped>
.triage-rule-sidebar {
  display: flex;
  flex-direction: column;
  height: 100%;
}

.sidebar-list {
  flex: 1;
  overflow-y: auto;
  min-height: 0;
}

.sidebar-rule-header {
  cursor: pointer;
  user-select: none;
}

.sidebar-rule-header:hover,
.sidebar-rule-header.sidebar-focused {
  background-color: var(--vulcan-hover-bg);
  outline: none;
}

.sidebar-rule--active {
  background-color: var(--vulcan-active-tint);
  border-left: 3px solid var(--primary);
}

.sidebar-rule--active:hover,
.sidebar-rule--active.sidebar-focused {
  background-color: var(--vulcan-active-tint-hover);
}

.sidebar-comment-item {
  cursor: pointer;
  padding-left: 1.25rem;
}

.sidebar-comment-item:hover,
.sidebar-comment-item:focus,
.sidebar-comment-item.sidebar-focused {
  background-color: var(--vulcan-hover-bg);
  outline: none;
}

.sidebar-comment--active {
  background-color: var(--primary) !important;
  color: white !important;
}

.sidebar-comment--active .text-muted {
  color: #fff !important;
}

.sidebar-comment--active:hover,
.sidebar-comment--active:focus,
.sidebar-comment--active.sidebar-focused {
  background-color: var(--vulcan-primary-dark) !important;
}
</style>
