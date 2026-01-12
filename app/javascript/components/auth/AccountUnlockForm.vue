<script setup lang="ts">
import { ref } from 'vue'
import { useAuth } from '@/composables/useAuth'

const { resendUnlock, loading } = useAuth()

// Form state
const email = ref('')

async function handleSubmit() {
  await resendUnlock(email.value)
  // Clear form on success or failure (toast handles feedback)
  email.value = ''
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
        placeholder="Enter your email"
        autocomplete="email"
      >
      <small class="text-muted">
        We'll send unlock instructions to this email address.
      </small>
    </div>

    <button type="submit" class="btn btn-primary w-100 mb-3" :disabled="loading">
      {{ loading ? 'Sending...' : 'Resend Unlock Instructions' }}
    </button>

    <div class="text-center">
      <router-link to="/users/sign_in" class="text-decoration-none">
        Back to sign in
      </router-link>
    </div>
  </form>
</template>
