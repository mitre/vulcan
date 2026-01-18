<script setup lang="ts">
import { ref } from 'vue'
import IBiEye from '~icons/bi/eye'
import IBiEyeSlash from '~icons/bi/eye-slash'

interface Props {
  modelValue: string
  id: string
  label?: string
  placeholder?: string
  required?: boolean
  autocomplete?: string
  hint?: string // Optional hint text (e.g., "Forgot password?" link)
  showStrength?: boolean // Show password strength indicator
}

const props = withDefaults(defineProps<Props>(), {
  label: 'Password',
  placeholder: 'Enter password',
  required: true,
  autocomplete: 'current-password',
  hint: undefined,
  showStrength: false,
})

const emit = defineEmits<{
  'update:modelValue': [value: string]
}>()

const showPassword = ref(false)

function togglePasswordVisibility() {
  showPassword.value = !showPassword.value
}

// Password strength calculation (for registration)
const passwordStrength = ref<'weak' | 'fair' | 'good' | 'strong'>('weak')
const strengthColor = ref('danger')
const strengthText = ref('Weak')

function calculatePasswordStrength(password: string) {
  if (!props.showStrength)
    return

  let strength = 0
  if (password.length >= 8)
    strength++
  if (password.length >= 12)
    strength++
  if (/[a-z]/.test(password) && /[A-Z]/.test(password))
    strength++
  if (/\d/.test(password))
    strength++
  if (/[^a-z\d]/i.test(password))
    strength++

  if (strength <= 1) {
    passwordStrength.value = 'weak'
    strengthColor.value = 'danger'
    strengthText.value = 'Weak'
  }
  else if (strength === 2) {
    passwordStrength.value = 'fair'
    strengthColor.value = 'warning'
    strengthText.value = 'Fair'
  }
  else if (strength === 3) {
    passwordStrength.value = 'good'
    strengthColor.value = 'info'
    strengthText.value = 'Good'
  }
  else {
    passwordStrength.value = 'strong'
    strengthColor.value = 'success'
    strengthText.value = 'Strong'
  }
}

function handleInput(event: Event) {
  const value = (event.target as HTMLInputElement).value
  emit('update:modelValue', value)
  if (props.showStrength) {
    calculatePasswordStrength(value)
  }
}
</script>

<template>
  <div class="mb-3">
    <div class="d-flex justify-content-between align-items-center mb-1">
      <label :for="id" class="form-label mb-0">
        {{ label }}
        <span v-if="required" class="text-danger">*</span>
      </label>
      <div v-if="hint" class="small" v-html="hint" />
    </div>

    <div class="input-group">
      <input
        :id="id"
        :type="showPassword ? 'text' : 'password'"
        :value="modelValue"
        class="form-control"
        :placeholder="placeholder"
        :required="required"
        :autocomplete="autocomplete"
        @input="handleInput"
      >
      <button
        type="button"
        class="btn btn-outline-secondary"
        tabindex="-1"
        @click="togglePasswordVisibility"
      >
        <IBiEye v-if="!showPassword" style="font-size: 1.25rem;" />
        <IBiEyeSlash v-else style="font-size: 1.25rem;" />
      </button>
    </div>

    <!-- Password strength indicator (only for registration) -->
    <div v-if="showStrength && modelValue.length > 0" class="mt-2">
      <div class="progress" style="height: 4px;">
        <div
          class="progress-bar"
          :class="`bg-${strengthColor}`"
          role="progressbar"
          :style="{ width: `${(passwordStrength === 'weak' ? 25 : passwordStrength === 'fair' ? 50 : passwordStrength === 'good' ? 75 : 100)}%` }"
        />
      </div>
      <small class="text-muted">
        Strength: <span :class="`text-${strengthColor}`">{{ strengthText }}</span>
      </small>
    </div>

    <!-- Password requirements helper text (only for registration) -->
    <div v-if="showStrength" class="mt-2">
      <small class="text-muted d-block">
        Password must contain:
      </small>
      <small class="text-muted d-block">
        • At least 8 characters (12+ recommended)
      </small>
      <small class="text-muted d-block">
        • Uppercase and lowercase letters
      </small>
      <small class="text-muted d-block">
        • Numbers and special characters
      </small>
    </div>
  </div>
</template>
