<script setup lang="ts">
import { computed, ref } from 'vue'
import { BApp } from 'bootstrap-vue-next'
import IBiShieldLock from '~icons/bi/shield-lock'
import AuthFooter from '@/components/auth/AuthFooter.vue'
import AuthHeader from '@/components/auth/AuthHeader.vue'
import LoginForm from '@/components/auth/LoginForm.vue'
import ProviderButton from '@/components/auth/ProviderButton.vue'
import RegisterForm from '@/components/auth/RegisterForm.vue'
import { useColorMode } from '@/composables'

// Initialize color mode early to prevent flash
useColorMode()

// Type for auth provider configuration
interface AuthProvider {
  id: string // Provider ID (used for Bootstrap Icons: github, google, oidc, ldap, etc.)
  title: string // Display name
  path: string // OAuth/OIDC authorization path
  customIcon?: string // Optional custom icon URL (overrides Bootstrap Icon)
}

// Type for Rails-provided window data
interface VueAppData {
  // Provider configuration (OIDC, GitHub, LDAP, etc.)
  authProviders?: AuthProvider[]
  // Feature flags
  localLoginEnabled?: boolean
  registrationEnabled?: boolean
  // Backwards compatibility (deprecated - use authProviders)
  oidcTitle?: string
  oidcPath?: string
  oidcIconPath?: string // Deprecated - ProviderButton now uses Bootstrap Icons
}

declare global {
  interface Window {
    vueAppData?: VueAppData
  }
}

// View state
const showRegistration = ref(false)

// Auth configuration from Rails
const localLoginEnabled = ref(window.vueAppData?.localLoginEnabled ?? true)
const registrationEnabled = ref(window.vueAppData?.registrationEnabled ?? true)

// Provider configuration (with backwards compatibility for old OIDC-only config)
const providers = computed<AuthProvider[]>(() => {
  // New multi-provider config
  if (window.vueAppData?.authProviders) {
    return window.vueAppData.authProviders
  }

  // Backwards compatibility: convert old OIDC config to new format
  if (window.vueAppData?.oidcPath) {
    return [{
      id: 'oidc',
      title: window.vueAppData.oidcTitle || 'OIDC',
      path: window.vueAppData.oidcPath,
      customIcon: window.vueAppData.oidcIconPath,
    }]
  }

  return []
})

// Event handlers
function handleSwitchToLogin() {
  showRegistration.value = false
}

function showRegistrationForm() {
  showRegistration.value = true
}
</script>

<template>
  <BApp>
    <div class="d-flex flex-column min-vh-100">
      <!-- Header with classification banner + dark mode -->
      <AuthHeader />

      <!-- Centered container - flex-grow to fill space -->
      <div class="flex-grow-1 bg-body-secondary d-flex align-items-center justify-content-center p-4">
        <!-- Centered card - simple approach -->
        <div class="card shadow-sm w-100" style="max-width: 28rem;">
          <div class="card-body p-4">
              <!-- Icon + Title -->
              <div class="text-center mb-3">
                <IBiShieldLock class="text-primary mb-2" style="font-size: 2rem;" />
                <h4 class="mb-2 fw-semibold">
                  {{ showRegistration ? 'Create Account' : 'Welcome to Vulcan' }}
                </h4>
                <p class="text-muted mb-0" style="font-size: 0.875rem;">
                  <template v-if="!showRegistration && registrationEnabled">
                    Don't have an account?
                    <a href="#" class="text-decoration-none" @click.prevent="showRegistrationForm">
                      Sign up
                    </a>
                  </template>
                  <template v-if="showRegistration">
                    Already have an account?
                    <a href="#" class="text-decoration-none" @click.prevent="handleSwitchToLogin">
                      Sign in
                    </a>
                  </template>
                </p>
              </div>

              <!-- OAuth/OIDC/LDAP Providers (if any) -->
              <div v-if="providers.length > 0 && !showRegistration" class="mb-3">
                <ProviderButton
                  v-for="provider in providers"
                  :key="provider.id"
                  :path="provider.path"
                  :title="provider.title"
                  :provider-id="provider.id"
                  :custom-icon="provider.customIcon"
                  class="mb-2"
                />
              </div>

              <!-- Separator between providers and local login -->
              <div v-if="providers.length > 0 && localLoginEnabled && !showRegistration" class="text-center my-4">
                <hr class="w-25 d-inline-block" style="vertical-align: middle">
                <span class="px-3 text-muted small">or</span>
                <hr class="w-25 d-inline-block" style="vertical-align: middle">
              </div>

              <!-- Local Login Form (if enabled) -->
              <div v-if="localLoginEnabled && !showRegistration">
                <LoginForm />
              </div>

              <!-- Registration Form -->
              <div v-if="showRegistration">
                <RegisterForm @switch-to-login="handleSwitchToLogin" />
              </div>
          </div>
        </div>
      </div>

      <!-- Footer with classification banner -->
      <AuthFooter />
    </div>
  </BApp>
</template>
