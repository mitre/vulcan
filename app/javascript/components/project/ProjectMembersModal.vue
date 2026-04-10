<template>
  <b-modal
    id="project-members-modal"
    :title="modalTitle"
    size="xl"
    centered
    scrollable
    ok-only
    ok-title="Close"
  >
    <!-- Hide table headings since modal has title -->
    <div class="memberships-modal-wrapper">
      <MembershipsTable
        :editable="isEditable"
        membership_type="Project"
        :membership_id="project.id"
        :memberships="project.memberships"
        :memberships_count="project.memberships_count"
        :available_roles="availableRoles"
        :access_requests="project.access_requests"
      />
    </div>
  </b-modal>
</template>

<script>
import RoleComparisonMixin from "../../mixins/RoleComparisonMixin.vue";
import MembershipsTable from "../memberships/MembershipsTable.vue";

export default {
  name: "ProjectMembersModal",
  components: { MembershipsTable },
  mixins: [RoleComparisonMixin],
  props: {
    project: {
      type: Object,
      required: true,
    },
    effectivePermissions: {
      type: String,
      required: true,
    },
    availableRoles: {
      type: Array,
      required: true,
    },
  },
  computed: {
    modalTitle() {
      const pendingCount = this.project.access_requests?.length || 0;
      const total = this.project.memberships_count;
      const pending = pendingCount > 0 ? ` (${pendingCount} pending)` : "";
      return `Project Members (${total})${pending}`;
    },
    isEditable() {
      return this.role_gte_to(this.effectivePermissions, "admin");
    },
  },
};
</script>

<style scoped>
/* Hide MembershipsTable headings when in modal (modal title is sufficient) */
.memberships-modal-wrapper >>> h2 {
  display: none;
}
</style>
