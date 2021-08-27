<script>
// This is meant to be a mixin that helps with determining how to display
// feedback for a form.
//
// When added as a mixin, the Vue component will have object props for
// `validFeedback` and `invalidFeedback` where keys are the property and
// values are strings representing the feedback.
export default {
  props: {
    validFeedback: {
      type: Object,
      required: false,
      default() {
        return {};
      },
    },
    invalidFeedback: {
      type: Object,
      required: false,
      default() {
        return {};
      },
    },
  },
  methods: {
    inputClass: function (field) {
      if (this.hasInvalidFeedback(field)) {
        return "is-invalid";
      } else if (this.hasValidFeedback(field)) {
        return "is-valid";
      }
      return "";
    },
    hasValidFeedback: function (field) {
      return this.validFeedback.hasOwnProperty(field);
    },
    hasInvalidFeedback: function (field) {
      return this.invalidFeedback.hasOwnProperty(field);
    },
  },
};
</script>
