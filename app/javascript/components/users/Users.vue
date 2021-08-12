<template>
  <div>
    <h1>Manage Vulcan Users</h1>
    <UsersTable :users="users" />
  </div>
</template>

<script>
export default {
  name: 'Users',
  props: {
    users: {
      type: Array,
      required: true,
    }
  }
}
</script>

<style scoped>

</style>
