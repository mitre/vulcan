<script setup lang="ts">
import { onMounted, watch } from 'vue'
import Navbar from '@/components/navbar/App.vue'
import Toaster from '@/components/toaster/Toaster.vue'
import AppFooter from '@/components/shared/AppFooter.vue'
import { useAuthStore, useNavigationStore } from '@/stores'
import { useColorMode } from '@/composables'

const authStore = useAuthStore()
const navigationStore = useNavigationStore()

// Initialize color mode early to prevent flash
useColorMode()

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
      <div class="app-container py-3 py-lg-4 px-3 px-sm-4 px-lg-5 mx-auto">
        <router-view />
      </div>
    </main>

    <!-- Footer - fixed at bottom of viewport -->
    <AppFooter />
  </BApp>
</template>

<style>
/* App container - centered with max-width for modern feel */
.app-container {
  width: 100%;
  max-width: 1600px; /* Wider - 50% less centered than 1400px */
}

/* Full-width override for pages that need edge-to-edge (like editors) */
.app-container:has(.full-width-page) {
  max-width: 100%;
  padding-left: 0 !important;
  padding-right: 0 !important;
}
</style>
