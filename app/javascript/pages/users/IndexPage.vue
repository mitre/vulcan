<script setup lang="ts">
import { onMounted } from 'vue'
import Users from '@/components/users/Users.vue'
import { useUsersStore } from '@/stores'

const usersStore = useUsersStore()

onMounted(async () => {
  // Always fetch from API
  await usersStore.fetchUsers()
})
</script>

<template>
  <div>
    <div v-if="usersStore.loading" class="text-center py-5">
      <div class="spinner-border" role="status">
        <span class="visually-hidden">Loading...</span>
      </div>
      <p class="mt-2">
        Loading users...
      </p>
    </div>
    <div v-else-if="usersStore.error" class="alert alert-danger">
      {{ usersStore.error }}
    </div>
    <Users v-else :users="usersStore.users" :histories="usersStore.histories" />
  </div>
</template>
