<script setup lang="ts">
import IBiKey from '~icons/bi/key'
import PasswordResetForm from '@/components/auth/PasswordResetForm.vue'
import PageContainer from '@/components/shared/PageContainer.vue'
</script>

<template>
  <PageContainer>
    <div class="d-flex align-items-center justify-content-center" style="min-height: 60vh;">
      <!-- Centered card -->
      <div class="card shadow-sm w-100" style="max-width: 28rem;">
        <div class="card-body p-4">
          <!-- Icon + Title -->
          <div class="text-center mb-3">
            <IBiKey class="text-primary mb-2" style="font-size: 2rem;" />
            <h4 class="mb-2 fw-semibold">
              Reset Password
            </h4>
            <p class="text-muted mb-0" style="font-size: 0.875rem;">
              Choose a new password for your account
            </p>
          </div>

          <!-- Password Reset Form -->
          <PasswordResetForm />
        </div>
      </div>
    </div>
  </PageContainer>
</template>
