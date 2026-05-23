<template>
  <div class="triage-queue-nav d-flex align-items-center" role="navigation">
    <template v-if="comments.length > 0">
      <span v-b-tooltip.hover title="Previous rule" class="mr-1">
        <b-button
          data-testid="prev-rule"
          size="sm"
          variant="outline-secondary"
          :disabled="!hasPrevRule"
          aria-label="Previous rule"
          @click="goPrevRule"
        >
          <b-icon icon="skip-start-fill" />
        </b-button>
      </span>
      <span v-b-tooltip.hover title="Previous comment" class="mr-2">
        <b-button
          data-testid="prev-comment"
          size="sm"
          variant="outline-secondary"
          :disabled="!hasPrev"
          aria-label="Previous comment"
          @click="goPrev"
        >
          <b-icon icon="chevron-left" />
        </b-button>
      </span>

      <span class="small mr-2">
        Rule <strong>{{ currentRuleIndex + 1 }}</strong> of
        <strong>{{ ruleGroups.length }}</strong>
        — Comment <strong>{{ currentCommentInRule + 1 }}</strong> of
        <strong>{{ currentRuleGroup ? currentRuleGroup.comments.length : 0 }}</strong>
      </span>

      <span v-b-tooltip.hover title="Next comment" class="mr-1">
        <b-button
          data-testid="next-comment"
          size="sm"
          variant="outline-secondary"
          :disabled="!hasNext"
          aria-label="Next comment"
          @click="goNext"
        >
          <b-icon icon="chevron-right" />
        </b-button>
      </span>
      <span v-b-tooltip.hover title="Next rule" class="mr-3">
        <b-button
          data-testid="next-rule"
          size="sm"
          variant="outline-secondary"
          :disabled="!hasNextRule"
          aria-label="Next rule"
          @click="goNextRule"
        >
          <b-icon icon="skip-end-fill" />
        </b-button>
      </span>

      <span class="small text-muted mr-3">{{ pendingCount }} pending</span>

      <div v-click-outside="closeBrowse" class="position-relative">
        <b-button
          data-testid="browse-toggle"
          size="sm"
          :variant="browseOpen ? 'secondary' : 'outline-secondary'"
          @click="toggleBrowse"
        >
          <b-icon :icon="browseOpen ? 'x' : 'list-ul'" /> Browse
        </b-button>
        <div
          v-if="browseOpen"
          data-testid="browse-panel"
          class="browse-panel position-absolute border rounded shadow bg-white"
        >
          <div class="p-2 border-bottom">
            <b-form-input
              v-model="browseFilter"
              data-testid="browse-search"
              size="sm"
              placeholder="Filter by rule or comment..."
              autofocus
            />
          </div>
          <div
            ref="browseList"
            class="browse-panel__list"
            role="listbox"
            tabindex="0"
            @keydown="handleBrowseKeydown"
          >
            <template v-for="group in filteredBrowseGroups">
              <div
                :key="'hdr-' + group.ruleId"
                data-testid="browse-rule-header"
                class="px-3 py-1 bg-light border-bottom small font-weight-bold"
              >
                {{ group.ruleName }} ({{ group.comments.length }})
              </div>
              <div
                v-for="comment in group.comments"
                :key="comment.id"
                data-testid="browse-item"
                class="browse-item px-3 py-1 small d-flex align-items-center cursor-pointer"
                :class="[
                  triageBgClass(comment.triage_status),
                  {
                    active: comment.id === normalizedCurrentId,
                    'browse-focused': browseFocusIndex === flatIndexOf(comment.id),
                  },
                ]"
                role="button"
                tabindex="0"
                @click="onBrowseSelect(comment.id)"
                @keydown.enter="onBrowseSelect(comment.id)"
              >
                <span class="flex-grow-1">
                  #{{ comment.id }}
                  <span v-if="comment.section" class="text-muted"
                    >· {{ sectionLabel(comment.section) }}</span
                  >
                </span>
                <TriageStatusBadge
                  :status="comment.triage_status"
                  :adjudicated-at="comment.adjudicated_at"
                />
              </div>
            </template>
          </div>
        </div>
      </div>
    </template>

    <span v-else class="small text-muted">No comments</span>
  </div>
</template>

<script>
import TriageStatusBadge from "../shared/TriageStatusBadge.vue";
import { SECTION_LABELS } from "../../constants/triageVocabulary";
import { triageBgClass } from "../../utils/triageBgClass";

export default {
  name: "TriageQueueNav",
  directives: {
    clickOutside: {
      bind(el, binding) {
        el._clickOutside = (e) => {
          if (!el.contains(e.target)) binding.value();
        };
        document.addEventListener("click", el._clickOutside);
      },
      unbind(el) {
        document.removeEventListener("click", el._clickOutside);
      },
    },
  },
  components: { TriageStatusBadge },
  props: {
    comments: { type: Array, required: true },
    currentId: { type: [Number, String], default: null },
  },
  data() {
    return {
      browseOpen: false,
      browseFilter: "",
      browseFocusIndex: -1,
    };
  },
  computed: {
    normalizedCurrentId() {
      return this.currentId != null ? Number(this.currentId) : null;
    },
    ruleGroups() {
      const groups = [];
      const seen = new Map();
      for (const c of this.comments) {
        const key = c.group_rule_displayed_name || c.rule_displayed_name || "(component)";
        if (!seen.has(key)) {
          const group = {
            ruleId: key,
            ruleName: key,
            comments: [],
          };
          seen.set(key, group);
          groups.push(group);
        }
        seen.get(key).comments.push(c);
      }
      return groups.sort((a, b) => {
        const aComp = a.ruleId === "(component)";
        const bComp = b.ruleId === "(component)";
        if (aComp && !bComp) return -1;
        if (!aComp && bComp) return 1;
        if (aComp && bComp) return 0;
        return a.ruleName.localeCompare(b.ruleName, undefined, { numeric: true });
      });
    },
    currentPosition() {
      for (let gi = 0; gi < this.ruleGroups.length; gi++) {
        const group = this.ruleGroups[gi];
        for (let ci = 0; ci < group.comments.length; ci++) {
          if (group.comments[ci].id === this.normalizedCurrentId) {
            return { ruleIndex: gi, commentIndex: ci };
          }
        }
      }
      return { ruleIndex: -1, commentIndex: -1 };
    },
    currentRuleIndex() {
      return this.currentPosition.ruleIndex;
    },
    currentCommentInRule() {
      return this.currentPosition.commentIndex;
    },
    currentRuleGroup() {
      return this.ruleGroups[this.currentRuleIndex] || null;
    },
    flatIndex() {
      let idx = 0;
      for (let gi = 0; gi < this.ruleGroups.length; gi++) {
        for (let ci = 0; ci < this.ruleGroups[gi].comments.length; ci++) {
          if (this.ruleGroups[gi].comments[ci].id === this.normalizedCurrentId) return idx;
          idx++;
        }
      }
      return -1;
    },
    hasPrev() {
      return this.flatIndex > 0;
    },
    hasNext() {
      return this.flatIndex >= 0 && this.flatIndex < this.comments.length - 1;
    },
    hasPrevRule() {
      return this.currentRuleIndex > 0;
    },
    hasNextRule() {
      return this.currentRuleIndex >= 0 && this.currentRuleIndex < this.ruleGroups.length - 1;
    },
    pendingCount() {
      return this.comments.filter((c) => c.triage_status === "pending").length;
    },
    filteredBrowseGroups() {
      if (!this.browseFilter) return this.ruleGroups;
      const q = this.browseFilter.toLowerCase();
      return this.ruleGroups
        .map((g) => ({
          ...g,
          comments: g.comments.filter(
            (c) =>
              g.ruleName.toLowerCase().includes(q) ||
              (c.section && c.section.toLowerCase().includes(q)) ||
              String(c.id).includes(q),
          ),
        }))
        .filter((g) => g.comments.length > 0);
    },
  },
  methods: {
    triageBgClass,
    flatComment(offset) {
      const target = this.flatIndex + offset;
      if (target < 0 || target >= this.comments.length) return null;
      let idx = 0;
      for (const group of this.ruleGroups) {
        for (const c of group.comments) {
          if (idx === target) return c.id;
          idx++;
        }
      }
      return null;
    },
    goPrev() {
      const id = this.flatComment(-1);
      if (id !== null) this.$emit("select", id);
    },
    goNext() {
      const id = this.flatComment(1);
      if (id !== null) this.$emit("select", id);
    },
    goPrevRule() {
      if (!this.hasPrevRule) return;
      const prevGroup = this.ruleGroups[this.currentRuleIndex - 1];
      this.$emit("select", prevGroup.comments[0].id);
    },
    goNextRule() {
      if (!this.hasNextRule) return;
      const nextGroup = this.ruleGroups[this.currentRuleIndex + 1];
      this.$emit("select", nextGroup.comments[0].id);
    },
    sectionLabel(key) {
      return SECTION_LABELS[key] || key;
    },
    toggleBrowse() {
      this.browseOpen = !this.browseOpen;
      if (this.browseOpen) {
        this.browseFocusIndex = this.flatIndexOf(this.normalizedCurrentId);
        this.$nextTick(() => {
          const active = this.$refs.browseList?.querySelector(".browse-item.active");
          if (active) active.scrollIntoView({ block: "nearest" });
        });
      }
    },
    closeBrowse() {
      this.browseOpen = false;
    },
    onBrowseSelect(id) {
      this.$emit("select", id);
      this.browseOpen = false;
      this.browseFocusIndex = -1;
    },
    flatIndexOf(commentId) {
      let idx = 0;
      for (const g of this.filteredBrowseGroups) {
        for (const c of g.comments) {
          if (c.id === commentId) return idx;
          idx++;
        }
      }
      return -1;
    },
    flatBrowseComments() {
      const flat = [];
      for (const g of this.filteredBrowseGroups) {
        for (const c of g.comments) flat.push(c);
      }
      return flat;
    },
    handleBrowseKeydown(event) {
      const items = this.flatBrowseComments();
      if (!items.length) return;

      if (event.key === "ArrowDown" || event.key === "ArrowUp") {
        event.preventDefault();
        if (event.key === "ArrowDown") {
          this.browseFocusIndex =
            this.browseFocusIndex < items.length - 1 ? this.browseFocusIndex + 1 : 0;
        } else {
          this.browseFocusIndex =
            this.browseFocusIndex > 0 ? this.browseFocusIndex - 1 : items.length - 1;
        }
        this.$nextTick(() => {
          const el = this.$refs.browseList?.querySelectorAll("[data-testid='browse-item']")[
            this.browseFocusIndex
          ];
          if (el) el.scrollIntoView({ block: "nearest" });
        });
      } else if (event.key === "Enter" || event.key === " ") {
        event.preventDefault();
        if (this.browseFocusIndex >= 0 && this.browseFocusIndex < items.length) {
          this.onBrowseSelect(items[this.browseFocusIndex].id);
        }
      } else if (event.key === "Escape") {
        this.browseOpen = false;
      }
    },
  },
};
</script>

<style scoped>
.browse-panel {
  right: 0;
  top: 100%;
  z-index: 1050;
  width: 300px;
  margin-top: 4px;
}

.browse-panel__list {
  max-height: 400px;
  overflow-y: auto;
}

.browse-item:hover,
.browse-item:focus,
.browse-item.browse-focused {
  background-color: rgba(0, 0, 0, 0.06);
  outline: none;
}

.browse-item.active {
  background-color: var(--primary) !important;
  color: white !important;
}

.browse-item.active .text-muted {
  color: rgba(255, 255, 255, 0.75) !important;
}

.browse-item.active:hover,
.browse-item.active:focus,
.browse-item.active.browse-focused {
  background-color: #0056b3 !important;
}

.cursor-pointer {
  cursor: pointer;
}
</style>
