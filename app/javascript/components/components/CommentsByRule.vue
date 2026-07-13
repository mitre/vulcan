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
          >
            <CommentItem :comment="normalize(comment)" :can-reply="false">
              <template #header="{ comment: c }">
                <div class="d-flex align-items-baseline mb-1">
                  <b-form-checkbox
                    v-if="selectable && !c.adjudicatedAt"
                    :checked="selectedIds.includes(c.id)"
                    class="mr-2"
                    :aria-label="`Select comment ${c.id}`"
                    @change="$emit('toggle-select', c.id)"
                  />
                  <CommentAuthorLine
                    :name="c.authorName"
                    :commenter-display-name="c.authorName"
                    :email="c.authorEmail"
                    :date="c.createdAt"
                    layout="inline"
                    :show-badge="false"
                  />
                </div>
                <small v-if="c.parentRuleDisplayedName" class="text-muted d-block mb-1">
                  <b-icon icon="arrow-return-right" class="mr-1" />
                  Posted on {{ c.ruleDisplayedName }}
                </small>
              </template>
              <template #actions="{ comment: c }">
                <div class="d-flex align-items-center">
                  <ReactionButtons
                    v-if="c.reactions"
                    :review-id="c.id"
                    :reactions="c.reactions"
                    @toggle="(kind) => toggleCommentReaction(comment, kind)"
                  />
                  <CommentThread
                    v-if="c.responsesCount > 0"
                    :parent-review-id="c.id"
                    :responses-count="c.responsesCount"
                    :can-reply="false"
                    class="ml-2"
                  />
                  <b-button
                    size="sm"
                    variant="outline-primary"
                    class="ml-auto"
                    data-testid="comment-triage-btn"
                    @click="$emit('triage', comment)"
                  >
                    Triage
                  </b-button>
                </div>
              </template>
            </CommentItem>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import { useCommentReactions } from "../../composables/useCommentReactions";
import CommentItem from "../shared/CommentItem.vue";
import ReactionButtons from "../shared/ReactionButtons.vue";
import CommentThread from "../shared/CommentThread.vue";
import CommentAuthorLine from "../shared/CommentAuthorLine.vue";
import { SECTION_LABELS } from "../../constants/triageVocabulary";
import { sectionIndex } from "../../utils/sectionSortOrder";
import { groupCommentsByRule } from "../../utils/groupCommentsByRule";
import { normalizeComment } from "../../utils/normalizeComment";

export default {
  name: "CommentsByRule",
  components: { CommentItem, ReactionButtons, CommentThread, CommentAuthorLine },
  props: {
    rows: { type: Array, required: true },
    allExpanded: { type: Boolean, default: false },
    selectable: { type: Boolean, default: false },
    selectedIds: { type: Array, default: () => [] },
  },
  setup() {
    const { toggle: toggleReactionApi } = useCommentReactions();
    return { toggleReactionApi };
  },
  data() {
    return {
      expandedGroups: {},
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
    normalize(comment) {
      return normalizeComment(comment);
    },
    toggleCommentReaction(comment, kind) {
      const prev = { ...comment.reactions };
      this.toggleReactionApi(comment.id, kind, prev, (reactions) => {
        this.$emit("reaction-updated", { id: comment.id, reactions });
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
