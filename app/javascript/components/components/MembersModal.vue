<template>
  <b-modal
    :id="modalId"
    :title="modalTitle"
    size="lg"
    centered
    scrollable
    lazy
    ok-only
    ok-title="Close"
    body-class="p-0"
  >
    <!-- Tabs for Component vs Inherited Members -->
    <b-tabs card content-class="mt-0" nav-class="bg-light">
      <!-- Component Members Tab -->
      <b-tab active>
        <template #title>
          Component Members
          <b-badge variant="primary" pill class="ml-1">{{ component.memberships_count }}</b-badge>
        </template>

        <div class="p-3">
          <!-- Search and Add -->
          <div class="d-flex justify-content-between align-items-center mb-3">
            <b-input-group size="sm" class="w-50">
              <b-input-group-prepend is-text>
                <b-icon icon="search" />
              </b-input-group-prepend>
              <b-form-input
                v-model="componentSearch"
                placeholder="Search by name or email..."
                debounce="300"
              />
            </b-input-group>
            <b-button v-if="isEditable" variant="primary" size="sm" @click="showAddMemberModal">
              <b-icon icon="person-plus" /> Add Member
            </b-button>
          </div>

          <!-- Members List -->
          <div class="members-list">
            <div
              v-for="member in filteredComponentMembers"
              :key="member.id"
              class="member-row d-flex justify-content-between align-items-center py-2 border-bottom"
            >
              <div class="member-info">
                <div class="font-weight-medium">{{ member.name }}</div>
                <small class="text-muted">{{ member.email }}</small>
              </div>
              <div class="member-actions d-flex align-items-center">
                <b-form-select
                  v-if="isEditable"
                  v-model="member.role"
                  :options="availableRoles"
                  size="sm"
                  class="role-select mr-2"
                  @change="updateRole(member)"
                />
                <span v-else class="text-muted mr-2">{{ member.role }}</span>
                <b-button
                  v-if="isEditable"
                  variant="outline-danger"
                  size="sm"
                  @click="confirmRemove(member)"
                >
                  <b-icon icon="trash" />
                </b-button>
              </div>
            </div>

            <p
              v-if="filteredComponentMembers.length === 0"
              class="text-muted text-center py-3 mb-0"
            >
              {{
                componentSearch ? "No members match your search." : "No component-specific members."
              }}
            </p>
          </div>
        </div>
      </b-tab>

      <!-- Inherited Members Tab -->
      <b-tab v-if="component && component.inherited_memberships !== undefined">
        <template #title>
          Inherited from Project
          <b-badge variant="secondary" pill class="ml-1">{{
            (component.inherited_memberships || []).length
          }}</b-badge>
        </template>

        <div class="p-3">
          <!-- Search -->
          <b-input-group size="sm" class="mb-3">
            <b-input-group-prepend is-text>
              <b-icon icon="search" />
            </b-input-group-prepend>
            <b-form-input
              v-model="inheritedSearch"
              placeholder="Search by name or email..."
              debounce="300"
            />
          </b-input-group>

          <p class="text-muted small mb-3">
            <b-icon icon="info-circle" /> These members are inherited from the project and cannot be
            modified here.
          </p>

          <!-- Inherited Members List -->
          <div class="members-list">
            <div
              v-for="member in filteredInheritedMembers"
              :key="member.id"
              class="member-row d-flex justify-content-between align-items-center py-2 border-bottom"
            >
              <div class="member-info">
                <div class="font-weight-medium">{{ member.name }}</div>
                <small class="text-muted">{{ member.email }}</small>
              </div>
              <span class="text-muted">{{ member.role }}</span>
            </div>

            <p
              v-if="filteredInheritedMembers.length === 0"
              class="text-muted text-center py-3 mb-0"
            >
              {{ inheritedSearch ? "No members match your search." : "No inherited members." }}
            </p>
          </div>
        </div>
      </b-tab>
    </b-tabs>

    <!-- Add Member Modal -->
    <b-modal
      :id="addMemberModalId"
      title="Add Member"
      centered
      @ok="addMember"
      @hidden="resetAddForm"
    >
      <b-form-group label="Select User" label-for="new-member-select">
        <b-form-select
          id="new-member-select"
          v-model="newMember.userId"
          :options="availableMemberOptions"
        >
          <template #first>
            <b-form-select-option :value="null" disabled>Choose a user...</b-form-select-option>
          </template>
        </b-form-select>
      </b-form-group>
      <b-form-group label="Role" label-for="new-member-role">
        <b-form-select id="new-member-role" v-model="newMember.role" :options="availableRoles" />
      </b-form-group>
    </b-modal>

    <!-- Remove Confirmation Modal -->
    <b-modal
      :id="removeMemberModalId"
      title="Remove Member"
      centered
      ok-variant="danger"
      ok-title="Remove"
      @ok="removeMember"
    >
      <p>
        Are you sure you want to remove
        <strong>{{ memberToRemove && memberToRemove.name }}</strong> from this component?
      </p>
    </b-modal>
  </b-modal>
</template>

<script>
import axios from "axios";
import RoleComparisonMixin from "../../mixins/RoleComparisonMixin.vue";
import FormMixinVue from "../../mixins/FormMixin.vue";

export default {
  name: "MembersModal",
  mixins: [RoleComparisonMixin, FormMixinVue],
  props: {
    component: {
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
  data() {
    return {
      componentSearch: "",
      inheritedSearch: "",
      newMember: {
        userId: null,
        role: "viewer",
      },
      memberToRemove: null,
    };
  },
  computed: {
    modalId() {
      return `members-modal-${this.component.id}`;
    },
    addMemberModalId() {
      return `add-member-modal-${this.component.id}`;
    },
    removeMemberModalId() {
      return `remove-member-modal-${this.component.id}`;
    },
    modalTitle() {
      const inheritedCount = this.component.inherited_memberships?.length || 0;
      const count = this.component.memberships_count + inheritedCount;
      return `Members (${count})`;
    },
    isEditable() {
      return this.role_gte_to(this.effectivePermissions, "admin");
    },
    filteredComponentMembers() {
      if (!this.componentSearch) {
        return this.component.memberships;
      }
      const search = this.componentSearch.toLowerCase();
      return this.component.memberships.filter(
        (m) =>
          (m.name || "").toLowerCase().includes(search) ||
          (m.email || "").toLowerCase().includes(search),
      );
    },
    filteredInheritedMembers() {
      const inherited = this.component.inherited_memberships || [];
      if (!this.inheritedSearch) {
        return inherited;
      }
      const search = this.inheritedSearch.toLowerCase();
      return inherited.filter(
        (m) =>
          (m.name || "").toLowerCase().includes(search) ||
          (m.email || "").toLowerCase().includes(search),
      );
    },
    availableMemberOptions() {
      if (!this.component.available_members) return [];
      return this.component.available_members.map((m) => ({
        value: m.id,
        text: `${m.name} (${m.email})`,
      }));
    },
  },
  methods: {
    showAddMemberModal() {
      this.$bvModal.show(this.addMemberModalId);
    },
    resetAddForm() {
      this.newMember = { userId: null, role: "viewer" };
    },
    addMember() {
      if (!this.newMember.userId) return;

      const form = document.createElement("form");
      form.method = "POST";
      form.action = "/memberships";

      const fields = {
        "membership[user_id]": this.newMember.userId,
        "membership[role]": this.newMember.role,
        "membership[membership_type]": "Component",
        "membership[membership_id]": this.component.id,
        authenticity_token: this.authenticityToken,
      };

      for (const [name, value] of Object.entries(fields)) {
        const input = document.createElement("input");
        input.type = "hidden";
        input.name = name;
        input.value = value;
        form.appendChild(input);
      }

      document.body.appendChild(form);
      form.submit();
    },
    async updateRole(member) {
      try {
        await axios.put(`/memberships/${member.id}.json`, {
          membership: { role: member.role },
        });
        this.$emit("membershipsUpdated");
      } catch (error) {
        const message = error.response?.data?.toast?.message || "Could not update role.";
        this.alert(message, "danger");
      }
    },
    confirmRemove(member) {
      this.memberToRemove = member;
      this.$bvModal.show(this.removeMemberModalId);
    },
    async removeMember() {
      if (!this.memberToRemove) return;

      try {
        await axios.delete(`/memberships/${this.memberToRemove.id}.json`);
        this.memberToRemove = null;
        this.$emit("membershipsUpdated");
      } catch (error) {
        const message = error.response?.data?.toast?.message || "Could not remove member.";
        this.alert(message, "danger");
      }
    },
  },
};
</script>

<style scoped>
.members-list {
  max-height: 350px;
  overflow-y: auto;
}

.member-row:last-child {
  border-bottom: none !important;
}

.role-select {
  width: 120px;
}

.font-weight-medium {
  font-weight: 500;
}
</style>
