<template>
  <div class="triage-rule-sidebar">
    <div data-testid="sidebar-header" class="px-2 py-1 border-bottom small font-weight-bold">
      {{ totalPending }} pending of {{ comments.length }} total
    </div>
    <div class="px-2 py-1 border-bottom">
      <input
        v-model="searchText"
        type="text"
        class="form-control form-control-sm"
        placeholder="Filter rules..."
        data-testid="sidebar-search"
      />
    </div>
    <div
      ref="sidebarList"
      data-testid="sidebar-list"
      class="sidebar-list"
      role="listbox"
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
          @click="selectGroup(item.group)"
          @keydown.enter="selectGroup(item.group)"
          @keydown.space.prevent="selectGroup(item.group)"
        >
          <strong class="flex-grow-1 text-truncate">{{ item.group.ruleName }}</strong>
          <span class="badge badge-pill badge-secondary ml-1">
            {{ item.group.pendingCount }} pending / {{ item.group.comments.length }} total
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
          <span v-if="item.comment.section" class="text-muted text-truncate">
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
        const key = c.rule_id || "component";
        if (!seen.has(key)) {
          const group = {
            key,
            ruleName: c.rule_displayed_name || "(component)",
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
        const aComp = a.key === "component";
        const bComp = b.key === "component";
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
      return comment ? comment.rule_id || "component" : null;
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
  },
  methods: {
    isActiveGroup(group) {
      return group.key === this.activeGroupKey;
    },
    selectGroup(group) {
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
      } else if (event.key === "Enter" || event.key === " ") {
        event.preventDefault();
        if (this.focusedIndex >= 0 && this.focusedIndex < items.length) {
          const item = items[this.focusedIndex];
          if (item.type === "group") {
            this.selectGroup(item.group);
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
.sidebar-list {
  max-height: calc(100vh - 200px);
  overflow-y: auto;
}

.sidebar-rule-header {
  cursor: pointer;
  user-select: none;
}

.sidebar-rule-header:hover,
.sidebar-rule-header.sidebar-focused {
  background-color: rgba(0, 0, 0, 0.06);
  outline: none;
}

.sidebar-rule--active {
  background-color: rgba(0, 123, 255, 0.08);
  border-left: 3px solid var(--primary);
}

.sidebar-rule--active:hover,
.sidebar-rule--active.sidebar-focused {
  background-color: rgba(0, 123, 255, 0.15);
}

.sidebar-comment-item {
  cursor: pointer;
  padding-left: 1.25rem;
}

.sidebar-comment-item:hover,
.sidebar-comment-item:focus,
.sidebar-comment-item.sidebar-focused {
  background-color: rgba(0, 0, 0, 0.06);
  outline: none;
}

.sidebar-comment--active {
  background-color: var(--primary) !important;
  color: white !important;
}

.sidebar-comment--active .text-muted {
  color: rgba(255, 255, 255, 0.75) !important;
}

.sidebar-comment--active:hover,
.sidebar-comment--active:focus,
.sidebar-comment--active.sidebar-focused {
  background-color: #0056b3 !important;
}
</style>
