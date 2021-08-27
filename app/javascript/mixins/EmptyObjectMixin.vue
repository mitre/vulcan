<script>
// This mixin provides a generic helper method that
// determines if a provided object is empty.
export default {
  methods: {
    isEmpty(o) {
      // Guard for the case where the object is null or undefined
      if (!o) {
        return true;
      }
      return Object.keys(o).length === 0;
    },
  },
};
</script>
