<script setup lang="ts">
import { ref } from 'vue'

// Define props
interface Props {
  oidcPath: string
  oidcTitle: string
  oidcIconPath?: string
}

defineProps<Props>()

// Get CSRF token from Rails meta tag
const csrfToken = ref(document.querySelector('meta[name="csrf-token"]')?.getAttribute('content') || '')
</script>

<template>
  <form :action="oidcPath" method="post">
    <input type="hidden" name="authenticity_token" :value="csrfToken">
    <button type="submit" class="btn btn-primary btn-lg w-100">
      <img
        v-if="oidcIconPath"
        :src="oidcIconPath"
        style="vertical-align: middle; margin-right: 10px"
        height="40"
        width="40"
      >
      Sign in with {{ oidcTitle }}
    </button>
  </form>
</template>
