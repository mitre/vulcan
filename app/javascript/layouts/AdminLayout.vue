<script setup lang="ts">
/**
 * AdminLayout - Layout wrapper for admin pages
 *
 * Simple responsive sidebar pattern:
 * - Desktop (lg+): Persistent sidebar + content side by side
 * - Mobile (<lg): Full-width content + offcanvas sidebar on toggle
 */

import { BButton, BOffcanvas } from 'bootstrap-vue-next'
import { ref } from 'vue'
import { RouterView } from 'vue-router'
import AdminSidebar from '@/components/admin/AdminSidebar.vue'

// Offcanvas visibility state (for mobile toggle)
const sidebarVisible = ref(false)

function showSidebar() {
  sidebarVisible.value = true
}
</script>

<template>
  <div class="admin-layout d-flex flex-column h-100">
    <!-- Mobile toggle bar - only visible below lg breakpoint -->
    <div class="d-lg-none border-bottom bg-body-tertiary p-2">
      <BButton
        variant="outline-secondary"
        size="sm"
        @click="showSidebar"
      >
        <i class="bi bi-list me-1" />
        Menu
      </BButton>
    </div>

    <!-- Main content wrapper -->
    <div class="d-flex flex-grow-1 overflow-hidden">
      <!-- Desktop sidebar - only visible on lg+ -->
      <aside class="admin-sidebar d-none d-lg-flex flex-column border-end bg-body-tertiary">
        <div class="p-2 border-bottom">
          <span class="fw-semibold">
            <i class="bi bi-gear-fill me-2" />
            Admin
          </span>
        </div>
        <AdminSidebar />
      </aside>

      <!-- Main content area - always visible -->
      <main class="admin-content flex-grow-1 overflow-auto">
        <div class="p-3 p-lg-4">
          <RouterView />
        </div>
      </main>
    </div>

    <!-- Mobile offcanvas sidebar -->
    <BOffcanvas
      v-model="sidebarVisible"
      placement="start"
      header-class="border-bottom bg-body-tertiary"
      body-class="p-0"
    >
      <template #title>
        <span class="fw-semibold">
          <i class="bi bi-gear-fill me-2" />
          Admin
        </span>
      </template>

      <AdminSidebar @navigate="sidebarVisible = false" />
    </BOffcanvas>
  </div>
</template>

<style scoped>
.admin-layout {
  min-height: 0;
}

/* Desktop sidebar styling */
.admin-sidebar {
  width: 220px;
  min-width: 220px;
}

/* Main content area */
.admin-content {
  background-color: var(--bs-body-bg);
}
</style>
