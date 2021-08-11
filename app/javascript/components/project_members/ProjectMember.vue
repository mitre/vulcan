<template>
  <tr>
    <!-- Project member ifno -->
    <td>
      {{project_member.name}}
      <br/>
      <small>{{project_member.email}}</small>
    </td>

    <!-- Change member role dropdown -->
    <td>
      <form v-bind:id="formId" v-bind:action="formAction" method="post">
        <input type="hidden" name="_method" value="put" />
        <input type="hidden" name="authenticity_token" v-bind:value="authenticityToken" />
        <select class="form-control" name="project_member[role]" @change="roleChanged($event)" v-model="project_member.role">
          <option v-bind:key="available_role" v-for="available_role in available_roles">{{available_role}}</option>
        </select>
      </form>
    </td>

    <!-- Remove member from project -->
    <td>
      <a data-confirm="Are you sure you want to remove this user from the project?" 
         data-method="delete" 
         v-bind:href="formAction"
         rel="nofollow">
        <button type="button" class="btn btn-danger">
          <i class="mdi mdi-trash-can" aria-hidden="true"></i>
          Remove
        </button>
      </a>
    </td>
  </tr>
</template>

<script>
export default {
  name: 'ProjectMember',
  props: {
    project_member: {
      type: Object,
      required: true,
    },
    project: {
      type: Object,
      required: true
    },
    available_roles: {
      type: Array,
      required: true,
    }
  },
  computed: {
    formId: function() {
      return "ProjectMember-" + this.project_member.id;
    },
    formAction: function() {
      return "/projects/" + this.project.id + "/project_members/" + this.project_member.id;
    },
    authenticityToken: function() {
      return document.querySelector("meta[name='csrf-token']").getAttribute("content");
    }
  },
  methods: {
    // Automatically submit the form when a user selects a form option
    roleChanged: function(event) {
      document.getElementById(this.formId).submit();
    }
  }
}
</script>

<style scoped>

</style>
