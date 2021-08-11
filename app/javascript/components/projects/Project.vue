<template>
  <div class="card projectCard">
    <div class="row">
      <!-- Title & info -->
      <div class="col-9">
        <h2>{{project.name}}</h2>
      </div>
      <!-- Actions (TODO - filter actions based on permissions) -->
      <div class="col-3 ">
        <div class="projectActionsDropdown">
          <b-dropdown :id="dropdownId" text="Actions" class="m-md-2" right>
            <!-- Manage users dropdown item -->
            <b-dropdown-item v-bind:href="manageUsersAction">
              <i class="mdi mdi-account-circle" aria-hidden="true"></i>
              Manage Project Members
            </b-dropdown-item>
            <!-- Delete project dropdown item -->
            <b-dropdown-item data-confirm="Are you sure you want to permanently delete this project?" 
                             data-method="delete" 
                             v-bind:href="deleteAction"
                             rel="nofollow">
              <i class="mdi mdi-trash-can" aria-hidden="true"></i>
              Delete Project
            </b-dropdown-item>
          </b-dropdown>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
export default {
  name: 'Project',
  props: {
    project: {
      type: Object,
      required: true,
    }
  },
  computed: {
    dropdownId: function() {
      return "ProjectDropdown-" + this.project.id;
    },
    deleteAction: function() {
      return 'projects/' + this.project.id;
    },
    manageUsersAction: function() {
      return 'projects/' + this.project.id + '/project_members';
    }
  }
}
</script>

<style scoped>
.projectCard {
  margin: 1em;
  padding: 1em;
}

.projectActionsDropdown {
  float: right;
}
</style>
