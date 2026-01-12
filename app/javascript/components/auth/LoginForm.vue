<script setup lang="ts">
import { ref } from 'vue'
import { useAuth } from '@/composables/useAuth'
import { useAppToast } from '@/composables/useToast'
import PasswordInput from './PasswordInput.vue'

const auth = useAuth()
const toast = useAppToast()

// Form state
const email = ref('')
const password = ref('')
const loading = ref(false)

async function handleSubmit() {
  loading.value = true

  try {
    const success = await auth.login({ email: email.value, password: password.value })

    if (success) {
      // Redirect to projects page
      window.location.href = '/projects'
    }
    else {
      // Login failed - loading already reset by auth composable
      loading.value = false
    }
  }
  catch (error: unknown) {
    // Unexpected error (should be caught by auth.login)
    const err = error as { response?: { data?: { error?: string } }, message?: string }
    toast.error(err.response?.data?.error || err.message || 'Unknown error', 'Login Failed')
    loading.value = false
  }
}
</script>

<template>
  <form autocomplete="on" @submit.prevent="handleSubmit">
    <div class="mb-3">
      <label for="email" class="form-label">Email</label>
      <input
        id="email"
        v-model="email"
        type="email"
        class="form-control"
        required
        placeholder="Enter email"
        autocomplete="email"
      >
    </div>

    <PasswordInput
      id="password"
      v-model="password"
      label="Password"
      placeholder="Enter password"
      autocomplete="current-password"
      hint="<a href=&quot;/auth/forgot-password&quot; class=&quot;text-primary&quot;>Forgot password?</a>"
    />

    <button type="submit" class="btn btn-primary w-100" :disabled="loading">
      {{ loading ? 'Signing in...' : 'Sign in' }}
    </button>

    <!-- Auth Helper Links -->
    <div class="text-center mt-3 small text-muted">
      Need help?
      <div class="mt-1">
        <router-link to="/auth/confirmation" class="text-decoration-none">
          Resend confirmation
        </router-link>
        <span class="mx-2">•</span>
        <router-link to="/auth/unlock" class="text-decoration-none">
          Unlock account
        </router-link>
      </div>
    </div>
  </form>
</template>
