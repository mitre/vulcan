<script setup lang="ts">
/**
 * ProfilePage - User profile management
 *
 * Vue 3 Composition API with:
 * - Form state management with ref()
 * - Computed properties for validation
 * - Async form submission
 * - Toast notifications
 */

import { computed, onMounted, ref } from 'vue'
import PageContainer from '@/components/shared/PageContainer.vue'
import { useAppToast, useProfile } from '@/composables'

const toast = useAppToast()
const {
  user,
  loading,
  name: currentName,
  email: currentEmail,
  slackUserId: currentSlackUserId,
  isOAuthUser,
  provider,
  updateProfile,
  deleteAccount,
  refresh,
} = useProfile()

// Form state
const name = ref('')
const email = ref('')
const slackUserId = ref('')
const password = ref('')
const passwordConfirmation = ref('')
const currentPassword = ref('')

// UI state
const showDeleteConfirm = ref(false)
const deleteConfirmText = ref('')

// Initialize form with current values
onMounted(async () => {
  await refresh()
  resetForm()
})

function resetForm() {
  name.value = currentName.value
  email.value = currentEmail.value
  slackUserId.value = currentSlackUserId.value
  password.value = ''
  passwordConfirmation.value = ''
  currentPassword.value = ''
}

// Validation
const passwordsMatch = computed(() => {
  if (!password.value && !passwordConfirmation.value) return true
  return password.value === passwordConfirmation.value
})

const passwordMinLength = computed(() => {
  if (!password.value) return true
  return password.value.length >= 6
})

const canSubmit = computed(() => {
  if (isOAuthUser.value) {
    // OAuth users can update name and slack without current password
    return name.value.trim().length > 0
  }
  // Local users need current password
  return (
    name.value.trim().length > 0
    && currentPassword.value.length > 0
    && passwordsMatch.value
    && passwordMinLength.value
  )
})

const canDelete = computed(() => {
  return deleteConfirmText.value === 'DELETE'
})

async function handleSubmit() {
  if (!canSubmit.value) return

  try {
    const updateData: Record<string, string> = {
      name: name.value.trim(),
      current_password: currentPassword.value,
    }

    // Only include fields that changed or have values
    if (email.value !== currentEmail.value) {
      updateData.email = email.value
    }
    if (slackUserId.value !== currentSlackUserId.value) {
      updateData.slack_user_id = slackUserId.value
    }
    if (password.value) {
      updateData.password = password.value
      updateData.password_confirmation = passwordConfirmation.value
    }

    const response = await updateProfile(updateData as any)

    if (response.data.success) {
      toast.success('Profile updated successfully')
      resetForm()
    }
  }
  catch (error: any) {
    const message = error.response?.data?.error || error.message || 'Failed to update profile'
    toast.error(message, 'Update Failed')
  }
}

async function handleDelete() {
  if (!canDelete.value) return

  try {
    await deleteAccount()
    // Redirect happens in store
  }
  catch (error: any) {
    toast.error('Failed to delete account', 'Error')
  }
}
</script>

<template>
  <PageContainer>
    <div class="row justify-content-center">
      <div class="col-lg-8 col-xl-6">
        <h1 class="h3 mb-4">
          Edit Profile
        </h1>

        <!-- OAuth Provider Notice -->
        <div v-if="isOAuthUser" class="alert alert-info mb-4">
          <i class="bi bi-info-circle me-2" />
          Some settings are managed by {{ provider }} and cannot be changed here.
        </div>

        <form @submit.prevent="handleSubmit">
          <!-- Name -->
          <div class="mb-3">
            <label for="name" class="form-label">Name</label>
            <input
              id="name"
              v-model="name"
              type="text"
              class="form-control"
              required
              :disabled="isOAuthUser"
              autocomplete="name"
            >
          </div>

          <!-- Email -->
          <div class="mb-3">
            <label for="email" class="form-label">Email</label>
            <input
              id="email"
              v-model="email"
              type="email"
              class="form-control"
              required
              :disabled="isOAuthUser"
              autocomplete="email"
            >
          </div>

          <!-- Slack User ID -->
          <div class="mb-3">
            <label for="slack-user-id" class="form-label">Slack User ID</label>
            <input
              id="slack-user-id"
              v-model="slackUserId"
              type="text"
              class="form-control"
              :disabled="isOAuthUser"
              placeholder="e.g., U123456"
            >
            <div class="form-text">
              Provide your Slack user ID if you would like to receive Slack notifications.
            </div>
          </div>

          <!-- Password Section (Local users only) -->
          <template v-if="!isOAuthUser">
            <hr class="my-4">

            <div class="mb-3">
              <label for="password" class="form-label">
                New Password
                <span class="text-muted fw-normal">(leave blank to keep current)</span>
              </label>
              <input
                id="password"
                v-model="password"
                type="password"
                class="form-control"
                :class="{ 'is-invalid': password && !passwordMinLength }"
                autocomplete="new-password"
                minlength="6"
              >
              <div v-if="password && !passwordMinLength" class="invalid-feedback">
                Password must be at least 6 characters.
              </div>
            </div>

            <div class="mb-3">
              <label for="password-confirmation" class="form-label">Confirm New Password</label>
              <input
                id="password-confirmation"
                v-model="passwordConfirmation"
                type="password"
                class="form-control"
                :class="{ 'is-invalid': passwordConfirmation && !passwordsMatch }"
                autocomplete="new-password"
              >
              <div v-if="passwordConfirmation && !passwordsMatch" class="invalid-feedback">
                Passwords do not match.
              </div>
            </div>

            <hr class="my-4">

            <div class="mb-4">
              <label for="current-password" class="form-label">
                Current Password
                <span class="text-danger">*</span>
              </label>
              <input
                id="current-password"
                v-model="currentPassword"
                type="password"
                class="form-control"
                required
                autocomplete="current-password"
              >
              <div class="form-text">
                We need your current password to confirm changes.
              </div>
            </div>
          </template>

          <!-- Submit Button -->
          <div class="d-flex gap-2 mb-5">
            <button
              type="submit"
              class="btn btn-primary"
              :disabled="!canSubmit || loading"
            >
              <span v-if="loading" class="spinner-border spinner-border-sm me-2" />
              Update Profile
            </button>
            <button
              type="button"
              class="btn btn-outline-secondary"
              @click="resetForm"
            >
              Reset
            </button>
          </div>
        </form>

        <!-- Danger Zone -->
        <div class="card border-danger">
          <div class="card-header bg-danger text-white">
            <h5 class="mb-0">
              Danger Zone
            </h5>
          </div>
          <div class="card-body">
            <h6>Delete Account</h6>
            <p class="text-muted small mb-3">
              Once you delete your account, there is no going back. Please be certain.
            </p>

            <div v-if="!showDeleteConfirm">
              <button
                type="button"
                class="btn btn-outline-danger"
                @click="showDeleteConfirm = true"
              >
                Delete My Account
              </button>
            </div>

            <div v-else>
              <div class="mb-3">
                <label class="form-label">
                  Type <strong>DELETE</strong> to confirm:
                </label>
                <input
                  v-model="deleteConfirmText"
                  type="text"
                  class="form-control"
                  placeholder="DELETE"
                >
              </div>
              <div class="d-flex gap-2">
                <button
                  type="button"
                  class="btn btn-danger"
                  :disabled="!canDelete || loading"
                  @click="handleDelete"
                >
                  <span v-if="loading" class="spinner-border spinner-border-sm me-2" />
                  Permanently Delete Account
                </button>
                <button
                  type="button"
                  class="btn btn-outline-secondary"
                  @click="showDeleteConfirm = false; deleteConfirmText = ''"
                >
                  Cancel
                </button>
              </div>
            </div>
          </div>
        </div>

        <!-- Back Link -->
        <div class="mt-4">
          <router-link to="/projects" class="btn btn-link ps-0">
            <i class="bi bi-arrow-left me-1" />
            Back to Projects
          </router-link>
        </div>
      </div>
    </div>
  </PageContainer>
</template>
