<script setup lang="ts">
import IBiUnlock from '~icons/bi/unlock'
import AccountUnlockForm from '@/components/auth/AccountUnlockForm.vue'
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
            <IBiUnlock class="text-primary mb-2" style="font-size: 2rem;" />
            <h4 class="mb-2 fw-semibold">
              Unlock Account
            </h4>
            <p class="text-muted mb-0" style="font-size: 0.875rem;">
              Enter your email to receive unlock instructions
            </p>
          </div>

          <!-- Account Unlock Form -->
          <AccountUnlockForm />
        </div>
      </div>
    </div>
  </PageContainer>
</template>
