<template>
  <div>
    <h1>Manage Vulcan Users</h1>
    <UsersTable :users="users" />
  </div>
</template>

<script>
import UsersTable from "./UsersTable.vue";

export default {
  name: "Users",
  components: { UsersTable },
  props: {
    users: {
      type: Array,
      required: true,
    },
  },
};
</script>

<style scoped></style>
