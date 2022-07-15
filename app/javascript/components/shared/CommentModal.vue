<template>
  <div :class="wrapperClass">
    <b-button
      :variant="buttonVariant"
      :class="buttonClass"
      :size="buttonSize"
      :disabled="buttonDisabled"
      @click="$bvModal.show(`comment-modal-${mod}`)"
    >
      {{ buttonText }}
    </b-button>

    <b-modal
      :id="`comment-modal-${mod}`"
      ref="modal"
      :title="title"
      :size="size"
      centered
      @show="resetModal"
      @hidden="resetModal"
      @ok="handleOk"
    >
      <slot />

      <p v-if="message">{{ message }}</p>

      <form ref="form" @submit.stop.prevent="handleSubmit">
        <b-form-group label="Comment" label-for="comment-input">
          <b-form-textarea id="comment-input" v-model="comment" />
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
    buttonText: {
      type: String,
      required: true,
    },
    buttonVariant: {
      type: String,
      default: "primary",
    },
    buttonClass: {
      type: [Object, Array],
      default: () => [],
    },
    buttonSize: {
      type: String,
      default: "medium",
    },
    buttonDisabled: {
      type: Boolean,
      default: false,
    },
    wrapperClass: {
      type: String,
      default: "",
    },
    size: {
      type: String,
      default: null,
    },
  },
  data: function () {
    return {
      mod: Math.floor(Math.random() * 1000),
      comment: "",
    };
  },
  methods: {
    resetModal() {
      this.comment = "";
    },
    handleOk(bvModalEvt) {
      // Prevent modal from closing
      bvModalEvt.preventDefault();
      // Trigger submit handler
      this.handleSubmit();
    },
    handleSubmit() {
      this.$emit("comment", this.comment);

      // Hide the modal manually
      this.$nextTick(() => {
        this.$bvModal.hide(`comment-modal-${this.mod}`);
      });
    },
  },
};
</script>

<style scoped></style>
