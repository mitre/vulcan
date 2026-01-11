<script setup lang="ts">
import { BApp } from 'bootstrap-vue-next'
import IBiShieldLock from '~icons/bi/shield-lock'
import AuthFooter from '@/components/auth/AuthFooter.vue'
import AuthHeader from '@/components/auth/AuthHeader.vue'
import ForgotPasswordForm from '@/components/auth/ForgotPasswordForm.vue'
import { useColorMode } from '@/composables'

// Initialize color mode early to prevent flash
useColorMode()
</script>

<template>
  <BApp>
    <div class="d-flex flex-column min-vh-100">
      <!-- Header with classification banner + dark mode -->
      <AuthHeader />

      <!-- Centered container - flex-grow to fill space -->
      <div class="flex-grow-1 bg-body-secondary d-flex align-items-center justify-content-center p-4">
        <!-- Centered card -->
        <div class="card shadow-sm w-100" style="max-width: 28rem;">
          <div class="card-body p-4">
            <!-- Icon + Title -->
            <div class="text-center mb-3">
              <IBiShieldLock class="text-primary mb-2" style="font-size: 2rem;" />
              <h4 class="mb-2 fw-semibold">
                Reset Password
              </h4>
              <p class="text-muted mb-0" style="font-size: 0.875rem;">
                Enter your email to receive reset instructions
              </p>
            </div>

            <!-- Forgot Password Form -->
            <ForgotPasswordForm />
          </div>
        </div>
      </div>

      <!-- Footer with classification banner -->
      <AuthFooter />
    </div>
  </BApp>
</template>
