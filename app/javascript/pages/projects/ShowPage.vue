<template>
  <div>
    <Project
      v-if="project"
      :project="project"
      :available_roles="availableRoles"
      :current_user_id="currentUserId"
      :effective_permissions="effectivePermissions"
    />
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import Project from '@/components/project/Project.vue'
import axios from 'axios'

const route = useRoute()
const project = ref(null)
const availableRoles = ref(['viewer', 'author', 'reviewer', 'admin'])
const currentUserId = ref((window as any).vueAppData?.currentUser?.id)
const effectivePermissions = ref('viewer')

onMounted(async () => {
  // Fetch project from API
  const projectId = route.params.id
  const response = await axios.get(`/projects/${projectId}.json`)
  project.value = response.data
})
</script>
