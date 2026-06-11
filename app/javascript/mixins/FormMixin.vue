<script>
export default {
  computed: {
    // Superseded by composables/useAuthToken.js — the hidden-form consumers
    // (NewComponentModal, AddComponentModal, LockControlsModal, NewMembership)
    // migrated in v2-0re.13.3. Remaining imports are verified dead-vs-real and
    // migrated per-file in v2-0re.13.4/.14/.15; the mixin is deleted in .10.
    authenticityToken: function () {
      return document.querySelector("meta[name='csrf-token']").getAttribute("content");
    },
  },
};
</script>
