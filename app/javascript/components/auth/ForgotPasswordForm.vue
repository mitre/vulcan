<script setup lang="ts">
import { ref } from 'vue'
import { useAppToast } from '@/composables/useToast'

const toast = useAppToast()

// Form state
const email = ref('')
const loading = ref(false)

async function handleSubmit() {
  loading.value = true

  try {
    // Get CSRF token
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content')

    const response = await fetch('/users/password', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': csrfToken || '',
      },
      body: JSON.stringify({
        user: {
          email: email.value,
        },
      }),
    })

    if (response.ok) {
      toast.success('Password reset instructions sent to your email', 'Check Your Email')
      email.value = '' // Clear form
    }
    else {
      const data = await response.json()
      toast.error(data.error || 'Failed to send reset instructions', 'Error')
    }
  }
  catch (error) {
    toast.error('Network error. Please try again.', 'Error')
  }
  finally {
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
        placeholder="Enter your email"
        autocomplete="email"
      >
      <small class="text-muted">
        We'll send password reset instructions to this email address.
      </small>
    </div>

    <button type="submit" class="btn btn-primary w-100 mb-3" :disabled="loading">
      {{ loading ? 'Sending...' : 'Send Reset Instructions' }}
    </button>

    <div class="text-center">
      <router-link to="/users/sign_in" class="text-decoration-none">
        Back to sign in
      </router-link>
    </div>
  </form>
</template>
