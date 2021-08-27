<template>
  <div>
    <!-- Collapsable header -->
    <div class="clickable" @click="showComments = !showComments">
      <h2 class="m-0 d-inline-block">Comments</h2>
      <b-badge pill class="superVerticalAlign">{{ rule.comments.length }}</b-badge>

      <i v-if="showComments" class="mdi mdi-menu-down superVerticalAlign collapsableArrow" />
      <i v-if="!showComments" class="mdi mdi-menu-up superVerticalAlign collapsableArrow" />
    </div>

    <b-collapse id="collapse-comments" v-model="showComments">
      <!-- All comments -->
      <div v-for="comment in rule.comments" :key="comment.id">
        <p class="ml-2 mb-0 mt-2">
          <strong>{{ comment.name }}</strong>
        </p>
        <p class="ml-2 mb-0">
          <small>{{ friendlyDateTime(comment.created_at) }}</small>
        </p>
        <p class="ml-3 mb-3">{{ comment.body }}</p>
      </div>

      <!-- Create a new comment -->
      <b-form class="ml-2 mb-0 mt-2" @submit="commentFormSubmitted">
        <b-form-group>
          <b-form-textarea
            v-model="newCommentBody"
            name="comment[body]"
            placeholder="Enter a comment..."
            rows="3"
            required
          />
        </b-form-group>
        <b-button type="submit" variant="primary">Comment</b-button>
      </b-form>
    </b-collapse>
  </div>
</template>

<script>
import axios from "axios";
import DateFormatMixinVue from "../../mixins/DateFormatMixin.vue";
import AlertMixinVue from "../../mixins/AlertMixin.vue";
import FormMixinVue from "../../mixins/FormMixin.vue";

export default {
  name: "ControlComments",
  mixins: [DateFormatMixinVue, AlertMixinVue, FormMixinVue],
  props: {
    rule: {
      type: Object,
      required: true,
    },
  },
  data: function () {
    return {
      newCommentBody: "",
      showComments: false,
    };
  },
  methods: {
    commentFormSubmitted: function (event) {
      event.preventDefault();
      // guard against invalid comment body
      if (!this.newCommentBody.trim()) {
        return;
      }

      axios
        .post(`/rules/${this.rule.id}/comments`, {
          body: this.newCommentBody.trim(),
        })
        .then(this.commentPostSuccess)
        .catch(this.alertOrNotifyResponse);
    },
    // Upon success, emit an event to the parent that indicates that this rule should be re-fetched.
    commentPostSuccess: function (response) {
      this.newCommentBody = "";
      this.$emit("ruleUpdated", this.rule.id, "comments");
    },
  },
};
</script>

<style scoped></style>
