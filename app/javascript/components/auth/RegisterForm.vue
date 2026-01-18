<script setup lang="ts">
import { ref } from 'vue'
import { useAppToast } from '@/composables/useToast'
import { useAuthStore } from '@/stores'
import PasswordInput from './PasswordInput.vue'

// Define emits
const emit = defineEmits<{
  switchToLogin: []
}>()

const authStore = useAuthStore()
const toast = useAppToast()

// Form state
const registerName = ref('')
const registerEmail = ref('')
const registerPassword = ref('')
const registerPasswordConfirmation = ref('')
const slackUserId = ref('')
const registerLoading = ref(false)

async function handleSubmit() {
  registerLoading.value = true

  // Validate name
  if (!registerName.value.trim()) {
    toast.warning('Name is required', 'Validation Error')
    registerLoading.value = false
    return
  }

  // Validate passwords match
  if (registerPassword.value !== registerPasswordConfirmation.value) {
    toast.warning('Passwords do not match', 'Validation Error')
    registerLoading.value = false
    return
  }

  // Validate password length
  if (registerPassword.value.length < 6) {
    toast.warning('Password must be at least 6 characters', 'Validation Error')
    registerLoading.value = false
    return
  }

  try {
    const response = await authStore.register({
      name: registerName.value.trim(),
      email: registerEmail.value,
      password: registerPassword.value,
      password_confirmation: registerPasswordConfirmation.value,
      slack_user_id: slackUserId.value.trim() || undefined,
    })

    // Check for success in response data
    if (response.data?.success) {
      toast.success('Please log in with your new account.', 'Registration Successful')
      // Clear the form
      registerName.value = ''
      registerEmail.value = ''
      registerPassword.value = ''
      registerPasswordConfirmation.value = ''
      slackUserId.value = ''
      // Emit event to switch to login tab
      emit('switchToLogin')
    }
    else {
      // Handle unexpected success response without success flag
      toast.warning('Please try logging in or register again.', 'Registration Status Unclear')
    }
  }
  catch (error: unknown) {
    const err = error as {
      response?: {
        data?: {
          error?: string
          errors?: string[]
        }
      }
      message?: string
    }
    const errorMessage = err.response?.data?.error
      || err.response?.data?.errors?.join(', ')
      || err.message
      || 'Unknown error'
    toast.error(errorMessage, 'Registration Failed')
  }
  finally {
    registerLoading.value = false
  }
}
</script>

<template>
  <form autocomplete="on" @submit.prevent="handleSubmit">
    <div class="mb-3">
      <label for="register-name" class="form-label">Name <span class="text-danger">*</span></label>
      <input
        id="register-name"
        v-model="registerName"
        type="text"
        class="form-control"
        required
        placeholder="Enter your full name"
        autocomplete="name"
      >
    </div>

    <div class="mb-3">
      <label for="register-email" class="form-label">Email <span class="text-danger">*</span></label>
      <input
        id="register-email"
        v-model="registerEmail"
        type="email"
        class="form-control"
        required
        placeholder="Enter email"
        autocomplete="email"
      >
    </div>

    <PasswordInput
      id="register-password"
      v-model="registerPassword"
      label="Password"
      placeholder="Enter password"
      autocomplete="new-password"
      :show-strength="true"
    />

    <PasswordInput
      id="register-password-confirmation"
      v-model="registerPasswordConfirmation"
      label="Confirm Password"
      placeholder="Confirm password"
      autocomplete="new-password"
    />

    <div class="mb-3">
      <label for="slack-user-id" class="form-label">Slack User ID <span class="text-muted">(optional)</span></label>
      <input
        id="slack-user-id"
        v-model="slackUserId"
        type="text"
        class="form-control"
        placeholder="Enter Slack user ID (optional)"
      >
    </div>

    <button type="submit" class="btn btn-success w-100" :disabled="registerLoading">
      {{ registerLoading ? 'Creating account...' : 'Sign Up' }}
    </button>
  </form>
</template>
