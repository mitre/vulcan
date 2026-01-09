<script setup lang="ts">
import PageContainer from '@/components/shared/PageContainer.vue'
/**
 * Users Index Page
 *
 * Uses async setup with Suspense for loading state.
 */
import Users from '@/components/users/Users.vue'
import { useUsersStore } from '@/stores'

const usersStore = useUsersStore()

// Top-level await makes this component suspensible
await usersStore.fetchAdminUsers()
</script>

<template>
  <PageContainer>
    <Users :users="usersStore.users" :histories="usersStore.histories" />
  </PageContainer>
</template>
