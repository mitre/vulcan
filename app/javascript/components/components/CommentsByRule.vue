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
            <small v-if="comment.parent_rule_displayed_name" class="text-muted d-block mb-1">
              <b-icon icon="arrow-return-right" class="mr-1" />
              Posted on {{ comment.rule_displayed_name }}
            </small>
            <div v-if="comment.comment && comment.comment.length > 200" class="mb-1 mt-1">
              {{ expanded[comment.id] ? comment.comment : comment.comment.substring(0, 200) + "…" }}
              <a
                href="#"
                class="text-primary ml-1"
                @click.prevent="$set(expanded, comment.id, !expanded[comment.id])"
              >
                {{ expanded[comment.id] ? "show less" : "show more" }}
              </a>
            </div>
            <p v-else class="mb-1 mt-1">{{ comment.comment }}</p>
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
              <b-button
                size="sm"
                variant="outline-primary"
                class="ml-auto"
                @click="$emit('triage', comment)"
              >
                Triage
              </b-button>
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
import { sectionIndex } from "../../utils/sectionSortOrder";
import { groupCommentsByRule } from "../../utils/groupCommentsByRule";

export default {
  name: "CommentsByRule",
  components: { TriageStatusBadge, ReactionButtons, CommentThread },
  mixins: [DateFormatMixin, ReactionToggleMixin],
  props: {
    rows: { type: Array, required: true },
    allExpanded: { type: Boolean, default: false },
  },
  data() {
    return {
      expandedGroups: {},
      expanded: {},
    };
  },
  computed: {
    ruleGroups() {
      const baseGroups = groupCommentsByRule(this.rows);
      return baseGroups.map((g) => {
        const sectionMap = {};
        for (const c of g.comments) {
          const sectionKey = c.section || "(general)";
          if (!sectionMap[sectionKey]) sectionMap[sectionKey] = [];
          sectionMap[sectionKey].push(c);
        }
        return {
          ...g,
          sections: Object.entries(sectionMap)
            .sort(([keyA], [keyB]) => {
              const idxA = keyA === "(general)" ? -1 : sectionIndex(keyA);
              const idxB = keyB === "(general)" ? -1 : sectionIndex(keyB);
              return idxA - idxB;
            })
            .map(([key, comments]) => ({
              key,
              label: key === "(general)" ? "Overall Requirement" : SECTION_LABELS[key] || key,
              comments,
            })),
        };
      });
    },
  },
  watch: {
    allExpanded(val) {
      if (val) {
        this.expandAll();
      } else {
        this.collapseAll();
      }
    },
  },
  methods: {
    isExpanded(ruleName) {
      return this.expandedGroups[ruleName] === true;
    },
    toggleRule(ruleName) {
      this.$set(this.expandedGroups, ruleName, !this.isExpanded(ruleName));
    },
    expandAll() {
      this.ruleGroups.forEach((g) => {
        this.$set(this.expandedGroups, g.ruleName, true);
      });
    },
    collapseAll() {
      this.ruleGroups.forEach((g) => {
        this.$set(this.expandedGroups, g.ruleName, false);
      });
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
