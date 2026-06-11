<script>
export default {
  computed: {
    // Superseded by composables/useAuthToken.js — the hidden-form consumers
    // (NewComponentModal, AddComponentModal, LockControlsModal, NewMembership)
    // already migrated. Remaining imports are verified dead-vs-real and
    // migrated per-file; the mixin is deleted once no consumers remain.
    authenticityToken: function () {
      return document.querySelector("meta[name='csrf-token']").getAttribute("content");
    },
  },
};
</script>
