<template>
  <div class="triage-queue-nav d-flex align-items-center" role="navigation">
    <template v-if="comments.length > 0">
      <b-button
        data-testid="prev-rule"
        size="sm"
        variant="outline-secondary"
        :disabled="!hasPrevRule"
        aria-label="Previous rule"
        class="mr-1"
        @click="goPrevRule"
      >
        <b-icon icon="chevron-bar-left" />
      </b-button>
      <b-button
        data-testid="prev-comment"
        size="sm"
        variant="outline-secondary"
        :disabled="!hasPrev"
        aria-label="Previous comment"
        class="mr-2"
        @click="goPrev"
      >
        <b-icon icon="chevron-left" />
      </b-button>

      <span class="small mr-2">
        Rule <strong>{{ currentRuleIndex + 1 }}</strong> of
        <strong>{{ ruleGroups.length }}</strong>
        — Comment <strong>{{ currentCommentInRule + 1 }}</strong> of
        <strong>{{ currentRuleGroup ? currentRuleGroup.comments.length : 0 }}</strong>
      </span>

      <b-button
        data-testid="next-comment"
        size="sm"
        variant="outline-secondary"
        :disabled="!hasNext"
        aria-label="Next comment"
        class="mr-1"
        @click="goNext"
      >
        <b-icon icon="chevron-right" />
      </b-button>
      <b-button
        data-testid="next-rule"
        size="sm"
        variant="outline-secondary"
        :disabled="!hasNextRule"
        aria-label="Next rule"
        class="mr-3"
        @click="goNextRule"
      >
        <b-icon icon="chevron-bar-right" />
      </b-button>

      <span class="small text-muted mr-3">{{ pendingCount }} pending</span>

      <b-dropdown
        data-testid="queue-dropdown"
        size="sm"
        variant="outline-secondary"
        text="Jump to..."
        no-caret
        class="queue-dropdown"
      >
        <template v-for="group in ruleGroups">
          <b-dropdown-header :key="'hdr-' + group.ruleId" data-testid="queue-dropdown-rule-header">
            <strong>{{ group.ruleName }}</strong> ({{ group.comments.length }})
          </b-dropdown-header>
          <b-dropdown-item
            v-for="comment in group.comments"
            :key="comment.id"
            data-testid="queue-dropdown-item"
            :active="comment.id === currentId"
            @click="$emit('select', comment.id)"
          >
            <span class="small ml-2">
              #{{ comment.id }}
              <span v-if="comment.section" class="text-muted">· {{ comment.section }}</span>
            </span>
            <TriageStatusBadge
              :status="comment.triage_status"
              :adjudicated-at="comment.adjudicated_at"
              class="ml-2"
            />
          </b-dropdown-item>
        </template>
      </b-dropdown>
    </template>

    <span v-else class="small text-muted">No comments</span>
  </div>
</template>

<script>
import TriageStatusBadge from "../shared/TriageStatusBadge.vue";

export default {
  name: "TriageQueueNav",
  components: { TriageStatusBadge },
  props: {
    comments: { type: Array, required: true },
    currentId: { type: [Number, String], default: null },
  },
  computed: {
    ruleGroups() {
      const groups = [];
      const seen = new Map();
      for (const c of this.comments) {
        const key = c.rule_id || `component-${c.id}`;
        if (!seen.has(key)) {
          const group = {
            ruleId: key,
            ruleName: c.rule_displayed_name || "(component)",
            comments: [],
          };
          seen.set(key, group);
          groups.push(group);
        }
        seen.get(key).comments.push(c);
      }
      return groups;
    },
    currentPosition() {
      for (let gi = 0; gi < this.ruleGroups.length; gi++) {
        const group = this.ruleGroups[gi];
        for (let ci = 0; ci < group.comments.length; ci++) {
          if (group.comments[ci].id === this.currentId) {
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
          if (this.ruleGroups[gi].comments[ci].id === this.currentId) return idx;
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
  },
  methods: {
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
  },
};
</script>

<style scoped>
.queue-dropdown :deep(.dropdown-menu) {
  max-height: 300px;
  overflow-y: auto;
}
</style>
