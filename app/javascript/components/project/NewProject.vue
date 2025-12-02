<script setup lang="ts">
/**
 * NewProject - Create a new project form
 *
 * Vue 3 Composition API with:
 * - Form state management with ref()
 * - Validation with computed properties
 * - Async API submission via useProjects composable
 * - Toast notifications on success/error
 * - Navigation after success
 */

import { computed, ref } from 'vue'
import { useRouter } from 'vue-router'
import { useProjects } from '@/composables'

const router = useRouter()
const { create, loading } = useProjects()

// Form state
const name = ref('')
const description = ref('')
const visibility = ref<'discoverable' | 'hidden'>('discoverable')
const slackChannelId = ref('')

// Validation
const canSubmit = computed(() => {
  return name.value.trim().length > 0 && description.value.trim().length > 0
})

// Visibility options
const visibilityOptions = [
  { value: 'discoverable', text: 'Discoverable' },
  { value: 'hidden', text: 'Hidden' },
]

async function handleSubmit() {
  if (!canSubmit.value) return

  const projectId = await create({
    name: name.value.trim(),
    description: description.value.trim(),
    visibility: visibility.value,
    slack_channel_id: slackChannelId.value.trim() || undefined,
  })

  if (projectId) {
    // Navigate to the new project page
    router.push(`/projects/${projectId}`)
  }
}

function handleCancel() {
  router.push('/projects')
}
</script>

<template>
  <div class="row justify-content-center">
    <div class="col-lg-8 col-xl-6">
      <h1 class="h3 mb-4">
        Start a New Project
      </h1>

      <form @submit.prevent="handleSubmit">
        <!-- Name -->
        <div class="mb-3">
          <label for="project-name" class="form-label">
            Project Title
            <span class="text-danger">*</span>
          </label>
          <input
            id="project-name"
            v-model="name"
            type="text"
            class="form-control"
            placeholder="Enter project title"
            required
            autocomplete="off"
          >
        </div>

        <!-- Description -->
        <div class="mb-3">
          <label for="project-description" class="form-label">
            Project Description
            <span class="text-danger">*</span>
          </label>
          <textarea
            id="project-description"
            v-model="description"
            class="form-control"
            placeholder="Describe your project"
            rows="4"
            required
            autocomplete="off"
          />
        </div>

        <!-- Visibility -->
        <div class="mb-3">
          <label for="project-visibility" class="form-label">Visibility</label>
          <select
            id="project-visibility"
            v-model="visibility"
            class="form-select"
          >
            <option
              v-for="option in visibilityOptions"
              :key="option.value"
              :value="option.value"
            >
              {{ option.text }}
            </option>
          </select>
          <div class="form-text">
            Marking the project as discoverable means that non-members will see
            the project's details (name, description, etc.) on the projects' list
            and can request access.
          </div>
        </div>

        <!-- Slack Channel ID -->
        <div class="mb-4">
          <label for="slack-channel-id" class="form-label">Slack Channel ID</label>
          <input
            id="slack-channel-id"
            v-model="slackChannelId"
            type="text"
            class="form-control"
            placeholder="e.g., C123456 or #general"
            autocomplete="off"
          >
          <div class="form-text">
            Provide a Slack channel ID to receive notifications about activities on this project.
          </div>
        </div>

        <!-- Submit Buttons -->
        <div class="d-flex gap-2">
          <button
            type="submit"
            class="btn btn-primary"
            :disabled="!canSubmit || loading"
          >
            <span v-if="loading" class="spinner-border spinner-border-sm me-2" />
            Create Project
          </button>
          <button
            type="button"
            class="btn btn-outline-secondary"
            @click="handleCancel"
          >
            Cancel
          </button>
        </div>
      </form>
    </div>
  </div>
</template>
