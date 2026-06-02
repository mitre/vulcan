<script>
export default {
  computed: {
    // Used by hidden form fields in NewComponentModal, AddComponentModal,
    // LockControlsModal, and NewMembership templates.
    authenticityToken: function () {
      return document.querySelector("meta[name='csrf-token']").getAttribute("content");
    },
  },
};
</script>
