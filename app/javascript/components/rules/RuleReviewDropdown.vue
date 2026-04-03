<template>
  <div class="review-dropdown mt-2">
    <b-card class="shadow-sm">
      <template #header>
        <div class="d-flex justify-content-between align-items-center">
          <strong>Complete a Review</strong>
          <b-button variant="link" size="sm" class="p-0" @click="$emit('close')">
            <b-icon icon="x" />
          </b-button>
        </div>
      </template>

      <b-form @submit.prevent="submitReview">
        <b-form-group>
          <b-form-textarea
            v-model="reviewComment"
            placeholder="Leave a comment..."
            rows="3"
            required
          />
        </b-form-group>

        <b-form-group label="" class="mb-0">
          <b-form-radio
            v-for="action in reviewActions"
            :key="action.value"
            v-model="selectedReviewAction"
            v-b-tooltip.left.hover
            name="review-action-radios"
            :value="action.value"
            class="mb-2"
            :disabled="!!action.disabledTooltip"
            :title="action.disabledTooltip"
          >
            <div>
              <strong class="small">{{ action.name }}</strong>
              <br />
              <small class="text-muted">{{ action.description }}</small>
            </div>
          </b-form-radio>
        </b-form-group>
      </b-form>

      <template #footer>
        <b-button
          type="submit"
          size="sm"
          variant="primary"
          :disabled="!selectedReviewAction || !reviewComment.trim()"
          @click="submitReview"
        >
          Submit Review
        </b-button>
      </template>
    </b-card>
  </div>
</template>

<script>
import axios from "axios";
import AlertMixinVue from "../../mixins/AlertMixin.vue";
import { buildReviewActions } from "../../utils/reviewActionHelpers";

export default {
  name: "RuleReviewDropdown",
  mixins: [AlertMixinVue],
  props: {
    rule: {
      type: Object,
      required: true,
    },
    effectivePermissions: {
      type: String,
      default: "",
    },
    currentUserId: {
      type: Number,
      required: true,
    },
    readOnly: {
      type: Boolean,
      default: false,
    },
  },
  data() {
    return {
      selectedReviewAction: null,
      reviewComment: "",
    };
  },
  computed: {
    reviewActions() {
      return buildReviewActions(
        this.rule,
        this.readOnly,
        this.effectivePermissions,
        this.currentUserId,
      );
    },
  },
  methods: {
    submitReview() {
      if (!this.reviewComment.trim() || !this.selectedReviewAction) {
        return;
      }

      axios
        .post(`/rules/${this.rule.id}/reviews`, {
          review: {
            component_id: this.rule.component_id,
            action: this.selectedReviewAction,
            comment: this.reviewComment.trim(),
          },
        })
        .then((response) => {
          this.alertOrNotifyResponse(response);
          this.reviewComment = "";
          this.selectedReviewAction = null;
          this.$emit("reviewSubmitted");
          this.$emit("close");
        })
        .catch(this.alertOrNotifyResponse);
    },
  },
};
</script>

<style scoped>
.review-dropdown {
  max-width: 400px;
}
</style>
