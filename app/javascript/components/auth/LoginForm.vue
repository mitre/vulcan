<script setup lang="ts">
import { ref } from 'vue'
import { useAuth } from '@/composables/useAuth'
import { useAppToast } from '@/composables/useToast'

const auth = useAuth()
const toast = useAppToast()

// Form state
const email = ref('')
const password = ref('')
const loading = ref(false)

async function handleSubmit() {
  loading.value = true
  try {
    await auth.login({ email: email.value, password: password.value })
    window.location.href = '/projects'
  }
  catch (error: unknown) {
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

    <div class="mb-3">
      <label for="password" class="form-label">Password</label>
      <input
        id="password"
        v-model="password"
        type="password"
        class="form-control"
        required
        placeholder="Enter password"
        autocomplete="current-password"
      >
    </div>

    <button type="submit" class="btn btn-primary w-100" :disabled="loading">
      {{ loading ? 'Signing in...' : 'Sign in' }}
    </button>

    <div class="text-center mt-3">
      <a href="/users/password/new">Forgot your password?</a>
    </div>
  </form>
</template>
