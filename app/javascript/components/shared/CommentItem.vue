<template>
  <div class="comment-item" :class="triageBgClass(comment.triageStatus)">
    <b-media>
      <template #aside>
        <UserBadge :name="comment.authorName" :email="comment.authorEmail" />
      </template>

      <slot name="header" :comment="comment">
        <div class="d-flex flex-wrap align-items-baseline mb-1">
          <CommentAuthorLine
            :name="comment.authorName"
            :commenter-display-name="comment.authorName"
            :email="comment.authorEmail"
            :date="comment.createdAt"
            layout="inline"
          />
          <SectionLabel
            v-if="comment.section"
            :section="comment.section"
            class="badge badge-light ml-1"
          />
        </div>
      </slot>

      <slot name="status" :comment="comment">
        <TriageStatusBadge
          v-if="comment.triageStatus"
          :status="comment.triageStatus"
          :adjudicated-at="comment.adjudicatedAt"
          :duplicate-of-id="comment.duplicateOfReviewId"
          :addressed-by-rule-id="comment.addressedByRuleId"
          :addressed-by-rule-name="comment.addressedByRuleName"
          class="mb-1"
        />
      </slot>

      <slot name="body" :comment="comment">
        <CommentBody
          :text="comment.text"
          :created-at="comment.createdAt"
          :is-imported="comment.isImported"
        />
      </slot>

      <slot name="actions" :comment="comment">
        <CommentActions
          :review-id="comment.id"
          :reactions="comment.reactions"
          :responses-count="comment.responsesCount"
          :can-reply="canReply"
          @toggle-reaction="(kind) => $emit('toggle-reaction', kind)"
          @reply="(id) => $emit('reply', id)"
        />
      </slot>

      <slot name="extra" :comment="comment" />
    </b-media>
  </div>
</template>

<script>
import UserBadge from "./UserBadge.vue";
import CommentAuthorLine from "./CommentAuthorLine.vue";
import SectionLabel from "./SectionLabel.vue";
import TriageStatusBadge from "./TriageStatusBadge.vue";
import CommentBody from "./CommentBody.vue";
import CommentActions from "./CommentActions.vue";
import { triageBgClass } from "../../utils/triageBgClass";

export default {
  name: "CommentItem",
  components: {
    UserBadge,
    CommentAuthorLine,
    SectionLabel,
    TriageStatusBadge,
    CommentBody,
    CommentActions,
  },
  props: {
    comment: { type: Object, required: true },
    canReply: { type: Boolean, default: true },
  },
  methods: {
    triageBgClass,
  },
};
</script>
