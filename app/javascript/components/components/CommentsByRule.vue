<template>
  <div class="comments-by-rule">
    <div v-if="rows.length === 0" class="text-center text-muted py-4">
      <b-icon icon="chat-left-text" font-scale="2" class="mb-2" />
      <p>No comments match these filters.</p>
    </div>

    <div v-for="group in ruleGroups" :key="group.ruleName" class="mb-3">
      <div
        data-testid="rule-group-header"
        class="d-flex align-items-center p-2 bg-light rounded cursor-pointer"
        role="button"
        tabindex="0"
        @click="toggleRule(group.ruleName)"
        @keydown.enter="toggleRule(group.ruleName)"
        @keydown.space.prevent="toggleRule(group.ruleName)"
      >
        <b-icon
          :icon="isExpanded(group.ruleName) ? 'chevron-down' : 'chevron-right'"
          class="mr-2"
        />
        <strong>{{ group.ruleName }}</strong>
        <b-badge variant="secondary" pill class="ml-2">
          {{ group.pendingCount }} pending / {{ group.comments.length }} total
        </b-badge>
      </div>

      <div v-show="isExpanded(group.ruleName)" data-testid="rule-group-content" class="ml-3 mt-2">
        <div v-for="section in group.sections" :key="section.key" class="mb-2">
          <div data-testid="section-group-header" class="small text-muted font-weight-bold mb-1">
            {{ section.label }}
            <b-badge variant="light" pill class="ml-1">{{ section.comments.length }}</b-badge>
          </div>

          <div
            v-for="comment in section.comments"
            :key="comment.id"
            data-testid="comment-entry"
            class="border-left pl-3 py-2 mb-1"
            :class="triageBgClass(comment.triage_status)"
          >
            <div class="d-flex justify-content-between align-items-baseline">
              <div>
                <strong>{{ comment.author_name }}</strong>
                <small class="text-muted ml-2">{{ friendlyDateTime(comment.created_at) }}</small>
              </div>
              <TriageStatusBadge
                v-if="comment.triage_status"
                :status="comment.triage_status"
                :adjudicated-at="comment.adjudicated_at"
                :duplicate-of-id="comment.duplicate_of_review_id"
              />
            </div>
            <p class="mb-1 mt-1">{{ comment.comment }}</p>
            <div class="d-flex align-items-center">
              <ReactionButtons
                v-if="comment.reactions"
                :review-id="comment.id"
                :reactions="comment.reactions"
                @toggle="(kind) => toggleCommentReaction(comment, kind)"
              />
              <CommentThread
                v-if="comment.responses_count > 0"
                :parent-review-id="comment.id"
                :responses-count="comment.responses_count"
                :can-reply="false"
                class="ml-2"
              />
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import DateFormatMixin from "../../mixins/DateFormatMixin.vue";
import ReactionToggleMixin from "../../mixins/ReactionToggleMixin.vue";
import TriageStatusBadge from "../shared/TriageStatusBadge.vue";
import ReactionButtons from "../shared/ReactionButtons.vue";
import CommentThread from "../shared/CommentThread.vue";
import { SECTION_LABELS } from "../../constants/triageVocabulary";
import { triageBgClass as getTriageBgClass } from "../../utils/triageBgClass";

export default {
  name: "CommentsByRule",
  components: { TriageStatusBadge, ReactionButtons, CommentThread },
  mixins: [DateFormatMixin, ReactionToggleMixin],
  props: {
    rows: { type: Array, required: true },
  },
  data() {
    return {
      collapsed: {},
    };
  },
  computed: {
    ruleGroups() {
      const groups = {};
      this.rows.forEach((row) => {
        const name = row.rule_displayed_name || "(unknown)";
        if (!groups[name]) {
          groups[name] = { ruleName: name, ruleId: row.rule_id, comments: [], sectionMap: {} };
        }
        groups[name].comments.push(row);
        const sectionKey = row.section || "(general)";
        if (!groups[name].sectionMap[sectionKey]) {
          groups[name].sectionMap[sectionKey] = [];
        }
        groups[name].sectionMap[sectionKey].push(row);
      });

      return Object.values(groups)
        .sort((a, b) => {
          const aComp = a.ruleId === null || a.ruleId === undefined;
          const bComp = b.ruleId === null || b.ruleId === undefined;
          if (aComp && !bComp) return -1;
          if (!aComp && bComp) return 1;
          if (aComp && bComp) return 0;
          return a.ruleName.localeCompare(b.ruleName, undefined, { numeric: true });
        })
        .map((g) => ({
          ...g,
          pendingCount: g.comments.filter((c) => c.triage_status === "pending").length,
          sections: Object.entries(g.sectionMap).map(([key, comments]) => ({
            key,
            label: key === "(general)" ? "Overall Requirement" : SECTION_LABELS[key] || key,
            comments,
          })),
        }));
    },
  },
  methods: {
    isExpanded(ruleName) {
      return this.collapsed[ruleName] === true;
    },
    toggleRule(ruleName) {
      this.$set(this.collapsed, ruleName, !this.isExpanded(ruleName));
    },
    triageBgClass(status) {
      return getTriageBgClass(status);
    },
    toggleCommentReaction(comment, kind) {
      const prev = { ...comment.reactions };
      this.submitReactionToggle({
        reviewId: comment.id,
        prev,
        kind,
        apply: (reactions) => {
          this.$emit("reaction-updated", { id: comment.id, reactions });
        },
      });
    },
  },
};
</script>

<style scoped>
.cursor-pointer {
  cursor: pointer;
}

/* triage-bg--* tint classes are in styles/triage-tints.css (global) */
</style>
