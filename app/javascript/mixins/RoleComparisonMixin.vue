<script>
// This mixin is for making comparisons between roles, which becomes useful
// when determining what a user should see / have permissions to do.
export default {
  methods: {
    /**
     * Checks that a provided `effective_permissions` is greater than or equal
     * to in permissions to a provided `comparison_role`.
     *
     * Roles in order of "numeric value" are:
     * - 'viewer'   => 0
     * - 'author'   => 1
     * - 'reviewer' => 2
     * - 'admin'    => 3
     *
     * Examples:
     * - role_gte_to('viewer', 'viewer') => true
     * - role_gte_to('viewer', 'author') => false
     * - role_gte_to('admin', 'author')  => true
     */
    role_gte_to: function (effective_permissions, comparison_role) {
      if (comparison_role == "viewer") {
        return ["viewer", "author", "reviewer", "admin"].includes(effective_permissions);
      } else if (comparison_role == "author") {
        return ["author", "reviewer", "admin"].includes(effective_permissions);
      } else if (comparison_role == "reviewer") {
        return ["reviewer", "admin"].includes(effective_permissions);
      } else if (comparison_role == "admin") {
        return ["admin"].includes(effective_permissions);
      }
      // Edge case where invalid `comparison_role` input was provided
      return false;
    },
  },
};
</script>
