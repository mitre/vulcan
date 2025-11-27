<template>
  <div>
    <Projects
      :projects="projects"
      :is_vulcan_admin="isVulcanAdmin"
    />
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import Projects from '@/components/projects/Projects.vue'

// This will come from Rails initially, then we can fetch via API
const route = useRoute()
const projects = ref((window as any).vueAppData?.projects || [])
const isVulcanAdmin = ref((window as any).vueAppData?.isVulcanAdmin || false)

onMounted(() => {
  // Future: Fetch projects from API if not provided by Rails
  // const response = await fetch('/api/v1/projects')
  // projects.value = await response.json()
})
</script>
