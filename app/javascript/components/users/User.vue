<template>
  <tr>
    <!-- User info -->
    <td>
      {{user.name}}
      <br/>
      <small>{{user.email}}</small>
    </td>
    <td>
      {{ldapColumn(user)}}
    </td>

    <!-- Change user admin status dropdown -->
    <td>
      <form v-bind:id="formId" v-bind:action="formAction" method="post">
        <input type="hidden" name="_method" value="put" />
        <input type="hidden" name="authenticity_token" v-bind:value="authenticityToken" />
        <select class="form-control" name="user[admin]" @change="adminStatusChanged($event)" v-model="user.admin">
          <option value="false">user</option>
          <option value="true">admin</option>
        </select>
      </form>
    </td>

    <!-- Remove user -->
    <td>
      <a data-confirm="Are you sure you want to permanently remove this user?" 
         data-method="delete" 
         v-bind:href="formAction"
         rel="nofollow">
        <b-button variant="danger" type="button">
          <i class="mdi mdi-trash-can" aria-hidden="true"></i>
          Remove
        </b-button>
      </a>
    </td>
  </tr>
</template>

<script>
export default {
  name: 'ProjectMember',
  props: {
    user: {
      type: Object,
      required: true,
    }
  },
  computed: {
    formId: function() {
      return "User-" + this.user.id;
    },
    formAction: function() {
      return "/users/" + this.user.id;
    },
    authenticityToken: function() {
      return document.querySelector("meta[name='csrf-token']").getAttribute("content");
    }
  },
  methods: {
    // Automatically submit the form when a user selects a form option
    adminStatusChanged: function(event) {
      document.getElementById(this.formId).submit();
    },
    ldapColumn: function(user) {
      return user.provider === null ? 'Vulcan User' : 'LDAP User'
    }
  }
}
</script>

<style scoped>

</style>
