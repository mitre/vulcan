<script setup lang="ts">
import { onMounted, watch } from 'vue'
import Navbar from '@/components/navbar/App.vue'
import Toaster from '@/components/toaster/Toaster.vue'
import AppFooter from '@/components/shared/AppFooter.vue'
import { useAuthStore, useNavigationStore } from '@/stores'

const authStore = useAuthStore()
const navigationStore = useNavigationStore()

// Fetch navigation when auth state changes
watch(
  () => authStore.signedIn,
  (signedIn) => {
    if (signedIn) {
      navigationStore.fetchNavigation()
    }
    else {
      navigationStore.reset()
    }
  },
)

onMounted(() => {
  // Fetch navigation if user is already signed in
  if (authStore.signedIn) {
    navigationStore.fetchNavigation()
  }
})
</script>

<template>
  <BApp class="d-flex flex-column vh-100">
    <!-- Navbar - fixed at top -->
    <header id="navbar" class="flex-shrink-0">
      <Navbar
        :navigation="navigationStore.links"
        :signed_in="authStore.signedIn"
        :users_path="authStore.isAdmin ? '/users' : ''"
        profile_path="/users/edit"
        sign_out_path="/users/sign_out"
        :access_requests="navigationStore.accessRequests"
      />
    </header>

    <!-- Toast container for notifications -->
    <div id="toaster">
      <Toaster />
    </div>

    <!-- Main content area - scrollable, pb-5 accounts for fixed footer -->
    <main class="flex-grow-1 overflow-auto pb-5">
      <div class="container-fluid py-3">
        <router-view />
      </div>
    </main>

    <!-- Footer - fixed at bottom of viewport -->
    <AppFooter />
  </BApp>
</template>
