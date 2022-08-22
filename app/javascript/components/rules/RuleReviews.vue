<template>
  <div>
    <!-- Collapsable header -->
    <div class="clickable" @click="showReviews = !showReviews">
      <h2 class="m-0 d-inline-block">Reviews &amp; Comments</h2>
      <b-badge pill class="ml-1 superVerticalAlign">{{ rule.reviews.length }}</b-badge>

      <i v-if="showReviews" class="mdi mdi-menu-down superVerticalAlign collapsableArrow" />
      <i v-if="!showReviews" class="mdi mdi-menu-up superVerticalAlign collapsableArrow" />
    </div>

    <b-collapse id="collapse-reviews" v-model="showReviews">
      <!-- All reviews -->
      <p
        v-if="numShownReviews < rule.reviews.length"
        class="ml-2 mb-0 text-primary clickable"
        @click="numShownReviews += 5"
      >
        show older reviews...
      </p>
      <div v-for="review in shownReviews" :key="review.id">
        <p class="ml-2 mb-0 mt-2">
          <strong>{{ review.name }} - {{ actionDescriptions[review.action] }}</strong>
        </p>
        <p class="ml-2 mb-0">
          <small>{{ friendlyDateTime(review.created_at) }}</small>
        </p>
        <p class="ml-3 mb-3 white-space-pre-wrap">{{ review.comment }}</p>
      </div>
    </b-collapse>
  </div>
</template>

<script>
import axios from "axios";
import DateFormatMixinVue from "../../mixins/DateFormatMixin.vue";
import AlertMixinVue from "../../mixins/AlertMixin.vue";
import FormMixinVue from "../../mixins/FormMixin.vue";

export default {
  name: "RuleReviews",
  mixins: [DateFormatMixinVue, AlertMixinVue, FormMixinVue],
  props: {
    effectivePermissions: {
      type: String,
      required: false,
    },
    currentUserId: {
      type: Number,
      required: false,
    },
    rule: {
      type: Object,
      required: true,
    },
  },
  data: function () {
    return {
      numShownReviews: 5,
      showReviews: true,
      actionDescriptions: {
        comment: "Commented",
        request_review: "Requested Review",
        revoke_review_request: "Revoked Request for Review",
        request_changes: "Requested Changes",
        approve: "Approved",
        lock_control: "Locked",
        unlock_control: "Unlocked",
      },
    };
  },
  computed: {
    shownReviews: function () {
      return this.rule.reviews.slice(-1 * this.numShownReviews);
    },
  },
};
</script>

<style scoped></style>
