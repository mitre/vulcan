<script setup lang="ts">
/**
 * NavbarItem Component
 *
 * Individual navigation item in the navbar.
 */

defineProps<{
  icon?: string
  link: string
  name: string
}>()
</script>

<template>
  <div>
    <BNavItem :to="link" class="mx-3">
      <i :class="`bi bi-${icon}`" aria-hidden="true" />
      <span class="d-sm-inline-block d-lg-block ms-1">{{ name }}</span>
    </BNavItem>
  </div>
</template>
