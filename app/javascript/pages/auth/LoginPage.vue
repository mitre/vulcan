<script setup lang="ts">
import { computed, ref } from 'vue'
import LoginForm from '@/components/auth/LoginForm.vue'
import ProviderButton from '@/components/auth/ProviderButton.vue'
import RegisterForm from '@/components/auth/RegisterForm.vue'
import PageContainer from '@/components/shared/PageContainer.vue'

// Type for auth provider configuration
interface AuthProvider {
  id: string
  title: string
  path: string
  icon?: string
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
  oidcIconPath?: string
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
      icon: window.vueAppData.oidcIconPath,
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
  <PageContainer>
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
        <div class="card">
          <div class="card-body">
            <!-- OAuth/OIDC/LDAP Providers (if any) -->
            <div v-if="providers.length > 0" class="mb-3">
              <ProviderButton
                v-for="provider in providers"
                :key="provider.id"
                :path="provider.path"
                :title="provider.title"
                :icon="provider.icon"
                class="mb-2"
              />
            </div>

            <!-- Separator between providers and local login -->
            <div v-if="providers.length > 0 && localLoginEnabled" class="text-center my-4">
              <hr class="w-25 d-inline-block" style="vertical-align: middle">
              <span class="px-3 text-muted">or</span>
              <hr class="w-25 d-inline-block" style="vertical-align: middle">
            </div>

            <!-- Local Login Form (if enabled) -->
            <div v-if="localLoginEnabled && !showRegistration">
              <LoginForm />

              <!-- Registration Link -->
              <div v-if="registrationEnabled" class="text-center mt-3">
                <span class="text-muted">Don't have an account? </span>
                <a href="#" class="text-decoration-none" @click.prevent="showRegistrationForm">
                  Sign up
                </a>
              </div>
            </div>

            <!-- Registration Form -->
            <div v-if="showRegistration">
              <h5 class="card-title mb-3">
                Create Account
              </h5>
              <RegisterForm @switch-to-login="handleSwitchToLogin" />

              <!-- Back to Login Link -->
              <div class="text-center mt-3">
                <span class="text-muted">Already have an account? </span>
                <a href="#" class="text-decoration-none" @click.prevent="handleSwitchToLogin">
                  Sign in
                </a>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </PageContainer>
</template>
