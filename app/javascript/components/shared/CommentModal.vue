<template>
  <div :class="wrapperClass">
    <b-button
      v-b-modal.comment-modal
      :variant="buttonVariant"
      :class="buttonClass"
      :disabled="buttonDisabled"
    >
      {{ buttonText }}
    </b-button>

    <b-modal
      id="comment-modal"
      ref="modal"
      :title="title"
      centered
      @show="resetModal"
      @hidden="resetModal"
      @ok="handleOk"
    >
      <p v-if="message">{{ message }}</p>
      <form ref="form" @submit.stop.prevent="handleSubmit">
        <b-form-group
          label="Comment"
          label-for="comment-input"
          :invalid-feedback="invalidFeedback"
          :state="commentValidState"
        >
          <b-form-textarea
            id="comment-input"
            v-model="comment"
            :state="commentValidState"
            :required="requireNonEmpty"
          />
        </b-form-group>
      </form>
    </b-modal>
  </div>
</template>

<script>
// CommentModal is for generating a modal that prompts a user to input a comment,
// then once submitted, emits an event @comment that contains the contents of the
// comment.
export default {
  name: "CommentModal",
  props: {
    title: {
      type: String,
      required: true,
    },
    message: {
      type: String,
      default: "",
    },
    // Message will be validated to be non-empty
    requireNonEmpty: {
      type: Boolean,
      default: true,
    },
    buttonText: {
      type: String,
      required: true,
    },
    buttonVariant: {
      type: String,
      default: "primary",
    },
    buttonClass: {
      type: String,
      default: "",
    },
    buttonDisabled: {
      type: Boolean,
      default: false,
    },
    wrapperClass: {
      type: String,
      default: "",
    },
  },
  data: function () {
    return {
      comment: "",
      commentValidState: null,
    };
  },
  computed: {
    invalidFeedback: function () {
      return this.requireNonEmpty ? "Must not be blank" : "";
    },
  },
  mounted() {},
  methods: {
    resetModal() {
      this.comment = "";
      this.commentValidState = null;
    },
    handleOk(bvModalEvt) {
      // Prevent modal from closing
      bvModalEvt.preventDefault();
      // Trigger submit handler
      this.handleSubmit();
    },
    handleSubmit() {
      // Exit when the form isn't valid
      if (!this.checkFormValidity()) {
        return;
      }

      this.$emit("comment", this.comment);

      // Hide the modal manually
      this.$nextTick(() => {
        this.$bvModal.hide("comment-modal");
      });
    },
    checkFormValidity() {
      this.commentValidState = this.$refs.form.checkValidity();
      return this.commentValidState;
    },
  },
};
</script>

<style scoped></style>
