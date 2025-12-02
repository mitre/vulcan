<script setup lang="ts">
import { onMounted, watch } from 'vue'
import { RouterView } from 'vue-router'
import Navbar from '@/components/navbar/App.vue'
import AppFooter from '@/components/shared/AppFooter.vue'
import CommandPalette from '@/components/shared/CommandPalette.vue'
import ErrorBoundary from '@/components/shared/ErrorBoundary.vue'
import PageContainer from '@/components/shared/PageContainer.vue'
import PageSpinner from '@/components/shared/PageSpinner.vue'
import Toaster from '@/components/toaster/Toaster.vue'
import { useColorMode, useCommandPalette } from '@/composables'
import { useAuthStore, useNavigationStore } from '@/stores'

const authStore = useAuthStore()
const navigationStore = useNavigationStore()

// Command palette composable (manages open state, Cmd+J shortcut)
const { open: showCommandPalette } = useCommandPalette()

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
  <BApp>
    <div class="d-flex flex-column vh-100">
      <!-- Command Palette (Cmd+J) -->
      <CommandPalette />

      <!-- Navbar - sticky at top, stays visible when scrolling -->
      <header id="navbar" class="flex-shrink-0 sticky-top shadow-sm">
        <Navbar
          :navigation="navigationStore.links"
          :signed_in="authStore.signedIn"
          :users_path="authStore.isAdmin ? '/users' : ''"
          profile_path="/profile"
          sign_out_path="/users/sign_out"
          :access_requests="navigationStore.accessRequests"
          @open-command-palette="showCommandPalette = true"
        />
      </header>

      <!-- Toast container for notifications -->
      <div id="toaster">
        <Toaster />
      </div>

      <!-- Main content area - flex-grow to fill remaining space -->
      <!-- overflow-hidden prevents content from expanding viewport -->
      <!-- No pb-5 needed - footer is in normal flow, not fixed position -->
      <main class="flex-grow-1 overflow-hidden">
        <RouterView v-slot="{ Component }">
          <template v-if="Component">
            <ErrorBoundary>
              <Suspense>
                <component :is="Component" />
                <template #fallback>
                  <PageContainer>
                    <PageSpinner message="Loading..." />
                  </PageContainer>
                </template>
              </Suspense>
            </ErrorBoundary>
          </template>
        </RouterView>
      </main>

      <!-- Footer - fixed at bottom of viewport -->
      <AppFooter />
    </div>
  </BApp>
</template>

<style scoped>
/* Fix: min-height: 0 allows flex item to shrink for proper scrolling */
main {
  min-height: 0;
}
</style>
