<script setup lang="ts">
import { computed, ref } from 'vue'
import IBiAmazon from '~icons/bi/amazon'
import IBiApple from '~icons/bi/apple'
import IBiBuildingLock from '~icons/bi/building-lock'
import IBiDiscord from '~icons/bi/discord'
import IBiFacebook from '~icons/bi/facebook'
// Icon components auto-imported via unplugin-icons
import IBiGithub from '~icons/bi/github'
import IBiGoogle from '~icons/bi/google'
import IBiKey from '~icons/bi/key'
import IBiLinkedin from '~icons/bi/linkedin'
import IBiMicrosoft from '~icons/bi/microsoft'
import IBiShieldLock from '~icons/bi/shield-lock'
import IBiSlack from '~icons/bi/slack'
import IBiTwitterX from '~icons/bi/twitter-x'

// Define props
interface Props {
  path: string
  title: string
  providerId?: string // e.g., 'github', 'google', 'oidc', 'ldap'
  customIcon?: string // Custom icon URL (overrides Bootstrap Icon)
  icon?: string // Backward compatibility - alias for customIcon
}

const props = defineProps<Props>()

// Use customIcon or icon (backward compat)
const iconUrl = computed(() => props.customIcon || props.icon)

// Get CSRF token from Rails meta tag
const csrfToken = ref(document.querySelector('meta[name="csrf-token"]')?.getAttribute('content') || '')

// Map provider IDs to icon components
const providerIconComponents: Record<string, typeof IBiGithub> = {
  github: IBiGithub,
  google: IBiGoogle,
  microsoft: IBiMicrosoft,
  apple: IBiApple,
  facebook: IBiFacebook,
  twitter: IBiTwitterX,
  linkedin: IBiLinkedin,
  amazon: IBiAmazon,
  discord: IBiDiscord,
  slack: IBiSlack,
  oidc: IBiShieldLock,
  ldap: IBiBuildingLock,
}

// Determine which icon component to use
const IconComponent = computed(() => {
  if (!props.providerId)
    return null
  return providerIconComponents[props.providerId.toLowerCase()] || IBiKey
})
</script>

<template>
  <form :action="path" method="post">
    <input type="hidden" name="authenticity_token" :value="csrfToken">
    <button type="submit" class="btn btn-primary btn-lg w-100">
      <!-- Custom icon URL (if provided) -->
      <img
        v-if="iconUrl"
        :src="iconUrl"
        style="vertical-align: middle; margin-right: 10px"
        height="24"
        width="24"
        :alt="`${title} icon`"
      >
      <!-- Bootstrap Icon component (default for known providers) -->
      <component
        :is="IconComponent"
        v-else-if="IconComponent"
        style="font-size: 1.5rem; vertical-align: middle; margin-right: 10px; display: inline-block"
        :aria-label="`${title} icon`"
      />
      Sign in with {{ title }}
    </button>
  </form>
</template>
