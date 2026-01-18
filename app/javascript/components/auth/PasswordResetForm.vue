<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import PasswordInput from '@/components/auth/PasswordInput.vue'
import { useAuth } from '@/composables/useAuth'

const { validateResetToken, resetPassword, loading } = useAuth()

// Get token from URL (works with or without router)
const token = ref('')

// Extract token from URL on mount
// Supports both standalone HAML pages and SPA router
onMounted(() => {
  const params = new URLSearchParams(window.location.search)
  token.value = params.get('reset_password_token') || ''
})

// Form state
const password = ref('')
const passwordConfirmation = ref('')
const tokenValid = ref<boolean | null>(null)
const passwordStrength = ref(0)

// Validate token after extracting from URL
async function checkToken() {
  if (!token.value) {
    tokenValid.value = false
    return
  }

  tokenValid.value = await validateResetToken(token.value)
}

onMounted(checkToken)

// Password confirmation validation
const passwordsMatch = computed(() => {
  if (!passwordConfirmation.value)
    return true // Don't show error until they start typing
  return password.value === passwordConfirmation.value
})

const canSubmit = computed(() => {
  return (
    tokenValid.value === true
    && password.value.length >= 8
    && passwordsMatch.value
    && passwordStrength.value >= 2 // Require at least medium strength
  )
})

function handleStrengthUpdate(strength: number) {
  passwordStrength.value = strength
}

async function handleSubmit() {
  if (!canSubmit.value)
    return

  const success = await resetPassword(token.value, password.value, passwordConfirmation.value)

  if (success) {
    // Redirect to home page after successful password reset
    window.location.href = '/'
  }
}
</script>

<template>
  <div v-if="tokenValid === false" class="alert alert-danger">
    <strong>Invalid or expired reset link.</strong>
    <p class="mb-0">
      Please request a new password reset.
    </p>
  </div>

  <form v-else-if="tokenValid === true" autocomplete="on" @submit.prevent="handleSubmit">
    <!-- Password field with strength indicator -->
    <div class="mb-3">
      <label for="password" class="form-label">New Password</label>
      <PasswordInput
        id="password"
        v-model="password"
        placeholder="Enter new password"
        autocomplete="new-password"
        :required="true"
        @strength-update="handleStrengthUpdate"
      />
    </div>

    <!-- Password confirmation field -->
    <div class="mb-3">
      <label for="password-confirmation" class="form-label">Confirm New Password</label>
      <input
        id="password-confirmation"
        v-model="passwordConfirmation"
        type="password"
        class="form-control"
        :class="{ 'is-invalid': !passwordsMatch }"
        required
        placeholder="Confirm new password"
        autocomplete="new-password"
      >
      <div v-if="!passwordsMatch" class="invalid-feedback">
        Passwords do not match
      </div>
    </div>

    <button
      type="submit"
      class="btn btn-primary w-100 mb-3"
      :disabled="!canSubmit || loading"
    >
      {{ loading ? 'Changing Password...' : 'Change Password' }}
    </button>

    <div class="text-center">
      <router-link to="/users/sign_in" class="text-decoration-none">
        Back to sign in
      </router-link>
    </div>
  </form>

  <div v-else class="text-center">
    <div class="spinner-border text-primary" role="status">
      <span class="visually-hidden">Validating token...</span>
    </div>
    <p class="mt-2 text-muted">
      Validating your reset link...
    </p>
  </div>
</template>
