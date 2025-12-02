<script setup lang="ts">
/**
 * AdminSidebar - Navigation sidebar for admin panel
 *
 * Uses BNav with pills and vertical layout per Bootstrap-Vue-Next docs.
 * https://bootstrap-vue-next.github.io/bootstrap-vue-next/docs/components/nav.html
 *
 * Navigation items:
 * - Dashboard (overview stats)
 * - Users (user management)
 * - Audit Log (activity viewer)
 * - Content (STIGs/SRGs management) - expandable
 * - Settings (read-only viewer)
 * - Back to main app
 */

import { BCollapse, BNav, BNavItem } from 'bootstrap-vue-next'
import { computed, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'

const emit = defineEmits<{
  (e: 'navigate'): void
}>()

const route = useRoute()
const router = useRouter()

// Content submenu expansion state
const contentExpanded = ref(false)

// Navigation items
const navItems = [
  {
    name: 'Dashboard',
    icon: 'bi-speedometer2',
    path: '/admin',
  },
  {
    name: 'Users',
    icon: 'bi-people',
    path: '/admin/users',
  },
  {
    name: 'Audit Log',
    icon: 'bi-journal-text',
    path: '/admin/audit',
  },
  {
    name: 'Settings',
    icon: 'bi-sliders',
    path: '/admin/settings',
  },
]

// Content submenu items - unified benchmarks management
const contentItems = [
  {
    name: 'Benchmarks',
    icon: 'bi-collection',
    path: '/admin/content/benchmarks',
  },
]

// Check if a route is active
function isActive(path: string): boolean {
  return route.path === path
}

// Check if content section is active
const isContentActive = computed(() => {
  return route.path.startsWith('/admin/content')
})

// Navigate and emit for mobile close
function navigate(path: string) {
  router.push(path)
  emit('navigate')
}

// Go back to main app
function goBack() {
  router.push('/')
  emit('navigate')
}
</script>

<template>
  <nav class="admin-sidebar-nav d-flex flex-column h-100">
    <!-- Main navigation using BNav -->
    <BNav vertical pills class="flex-column mb-auto">
      <BNavItem
        v-for="item in navItems"
        :key="item.path"
        :active="isActive(item.path)"
        link-classes="d-flex align-items-center gap-2"
        @click="navigate(item.path)"
      >
        <i class="bi" :class="[item.icon]" />
        {{ item.name }}
      </BNavItem>

      <!-- Content submenu (expandable) -->
      <BNavItem
        :active="isContentActive"
        link-classes="d-flex align-items-center gap-2"
        @click="contentExpanded = !contentExpanded"
      >
        <i class="bi bi-folder" />
        Content
        <i
          class="bi ms-auto"
          :class="contentExpanded ? 'bi-chevron-down' : 'bi-chevron-right'"
        />
      </BNavItem>

      <BCollapse v-model="contentExpanded">
        <BNav vertical pills class="ms-3">
          <BNavItem
            v-for="item in contentItems"
            :key="item.path"
            :active="isActive(item.path)"
            link-classes="d-flex align-items-center gap-2 py-1"
            @click="navigate(item.path)"
          >
            <i class="bi" :class="[item.icon]" />
            {{ item.name }}
          </BNavItem>
        </BNav>
      </BCollapse>
    </BNav>

    <!-- Bottom section: Back to app -->
    <div class="mt-auto border-top pt-2">
      <BNav vertical>
        <BNavItem
          link-classes="d-flex align-items-center gap-2 text-muted"
          @click="goBack"
        >
          <i class="bi bi-arrow-left" />
          Back to Vulcan
        </BNavItem>
      </BNav>
    </div>
  </nav>
</template>

<style scoped>
.admin-sidebar-nav {
  padding: 0.5rem;
}

/* Override default nav-link styling for icons */
.admin-sidebar-nav :deep(.nav-link i.bi) {
  font-size: 1.1em;
  width: 1.25rem;
  text-align: center;
}
</style>
