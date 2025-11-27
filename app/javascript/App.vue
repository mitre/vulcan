<template>
  <BApp>
    <!-- Navbar - always visible -->
    <div id="navbar">
      <Navbar
        :navigation="navigation"
        :signed_in="signedIn"
        :users_path="usersPath"
        :profile_path="profilePath"
        :sign_out_path="signOutPath"
        :access_requests="accessRequests"
      />
    </div>

    <!-- Toast notifications - global -->
    <div id="toaster">
      <Toaster :notice="notice" :alert="alert" />
    </div>

    <!-- Main content area - routed pages -->
    <div class="pt-3 container-fluid">
      <router-view />
    </div>
  </BApp>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useAuthStore } from '@/stores/auth'
import Navbar from '@/components/navbar/App.vue'
import Toaster from '@/components/toaster/Toaster.vue'

// Props passed from Rails
const props = defineProps<{
  navigation?: Array<any>
  signedIn?: boolean
  usersPath?: string
  profilePath?: string
  signOutPath?: string
  accessRequests?: Array<any>
  notice?: string
  alert?: string
  currentUser?: any
}>()

const authStore = useAuthStore()

// Set navigation defaults
const navigation = ref(props.navigation || [])
const signedIn = ref(props.signedIn || false)
const usersPath = ref(props.usersPath || '')
const profilePath = ref(props.profilePath || '/users/edit')
const signOutPath = ref(props.signOutPath || '/users/sign_out')
const accessRequests = ref(props.accessRequests || [])
const notice = ref(props.notice || null)
const alert = ref(props.alert || null)

onMounted(() => {
  // Initialize auth store with current user if provided
  if (props.currentUser) {
    authStore.setUser(props.currentUser)
  }
})
</script>
