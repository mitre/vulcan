<script setup lang="ts">
import IBiEnvelopeCheck from '~icons/bi/envelope-check'
import EmailConfirmationForm from '@/components/auth/EmailConfirmationForm.vue'
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
            <IBiEnvelopeCheck class="text-primary mb-2" style="font-size: 2rem;" />
            <h4 class="mb-2 fw-semibold">
              Resend Confirmation
            </h4>
            <p class="text-muted mb-0" style="font-size: 0.875rem;">
              Enter your email to receive confirmation instructions
            </p>
          </div>

          <!-- Email Confirmation Form -->
          <EmailConfirmationForm />
        </div>
      </div>
    </div>
  </PageContainer>
</template>
