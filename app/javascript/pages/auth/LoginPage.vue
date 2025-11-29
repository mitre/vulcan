<script setup lang="ts">
import { ref } from 'vue'
import { useAppToast } from '@/composables/useToast'
import { useAuthStore } from '@/stores'

const authStore = useAuthStore()
const toast = useAppToast()

// Auth configuration from Rails/ENV - show all tabs by default
const oidcEnabled = ref(true)
const localEnabled = ref(true)
const registrationEnabled = ref(true)
const oidcTitle = ref((window as any).vueAppData?.oidcTitle || 'OIDC')
const oidcPath = ref((window as any).vueAppData?.oidcPath || '/users/auth/oidc')
const oidcIconPath = ref((window as any).vueAppData?.oidcIconPath || '')
const activeTab = ref((window as any).vueAppData?.activeTab || '')

// Login form state
const email = ref('')
const password = ref('')
const _rememberMe = ref(false) // Prefixed with _ as it's not yet used in the UI
const loading = ref(false)

// Registration form state
const registerName = ref('')
const registerEmail = ref('')
const slackUserId = ref('')
const registerPassword = ref('')
const registerPasswordConfirmation = ref('')
const registerLoading = ref(false)

async function handleLogin() {
  loading.value = true
  try {
    await authStore.login({ email: email.value, password: password.value })
    window.location.href = '/projects'
  }
  catch (error: any) {
    toast.error(error.response?.data?.error || error.message || 'Unknown error', 'Login Failed')
    loading.value = false
  }
}

async function handleRegister() {
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
      // Switch to login tab
      activeTab.value = 'local'
    }
    else {
      // Handle unexpected success response without success flag
      toast.warning('Please try logging in or register again.', 'Registration Status Unclear')
    }
  }
  catch (error: any) {
    const errorMessage = error.response?.data?.error
      || error.response?.data?.errors?.join(', ')
      || error.message
      || 'Unknown error'
    toast.error(errorMessage, 'Registration Failed')
  }
  finally {
    registerLoading.value = false
  }
}
</script>

<template>
  <div class="row">
    <div class="col-md-12">
      <h1>Welcome to Vulcan</h1>
      <br>
    </div>
  </div>
  <div class="row">
    <div class="col-md-5 order-2 order-md-1">
      <h2>What is Vulcan?</h2>
      <p>
        Vulcan helps Subject Matter Experts (SMEs) apply Security Requirements Guides (SRGs)
        to author Security Technical Implementation Guides (STIGs) & corresponding InSpec
        Profiles as security testing content.
      </p>
      <p>Welcome to Vulcan Development</p>
    </div>
    <div class="col-md offset-md-0 offset-lg-1 order-1 order-md-2">
      <b-card no-body>
        <b-tabs card fill pills>
          <!-- OIDC Login -->
          <b-tab v-if="oidcEnabled" :title="oidcTitle">
            <b-card-text>
              <a :href="oidcPath" class="btn btn-block btn-light border" data-method="post">
                <img v-if="oidcIconPath" :src="oidcIconPath" style="vertical-align: middle; margin-right: 10px" height="40" width="40">
                Sign in with {{ oidcTitle }}
              </a>
            </b-card-text>
          </b-tab>

          <!-- Local Login -->
          <b-tab v-if="localEnabled" title="Local Login" :active="activeTab === 'local'">
            <b-card-text>
              <form autocomplete="on" @submit.prevent="handleLogin">
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
            </b-card-text>
          </b-tab>

          <!-- Registration -->
          <b-tab v-if="registrationEnabled" title="Register" :active="activeTab === 'registration'">
            <b-card-text>
              <form autocomplete="on" @submit.prevent="handleRegister">
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

                <div class="mb-3">
                  <label for="register-password" class="form-label">Password <span class="text-danger">*</span></label>
                  <input
                    id="register-password"
                    v-model="registerPassword"
                    type="password"
                    class="form-control"
                    required
                    placeholder="Enter password (min 6 characters)"
                    autocomplete="new-password"
                  >
                </div>

                <div class="mb-3">
                  <label for="register-password-confirmation" class="form-label">Confirm Password <span class="text-danger">*</span></label>
                  <input
                    id="register-password-confirmation"
                    v-model="registerPasswordConfirmation"
                    type="password"
                    class="form-control"
                    required
                    placeholder="Confirm password"
                    autocomplete="new-password"
                  >
                </div>

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
            </b-card-text>
          </b-tab>
        </b-tabs>
      </b-card>
    </div>
  </div>
</template>
