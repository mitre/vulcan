<script setup lang="ts">
/**
 * LockControlsModal.vue
 * Modal for bulk locking all controls in a component
 * Vue 3 Composition API + Bootstrap 5
 */
import { ref } from 'vue'
import { useAppToast } from '@/composables'
import { http } from '@/services/http.service'

// Props
const props = defineProps<{
  component_id: number
}>()

// Emits
const emit = defineEmits<{
  projectUpdated: []
}>()

// Toast for notifications
const toast = useAppToast()

// State
const showModal = ref(false)
const comment = ref('')
const loading = ref(false)

// Methods
function openModal() {
  comment.value = ''
  showModal.value = true
}

function closeModal() {
  showModal.value = false
}

function lockControls() {
  // Validation
  if (!comment.value.trim()) {
    toast.error('Please enter a comment')
    return
  }

  loading.value = true

  http.post(`/components/${props.component_id}/lock`, {
    review: { action: 'lock_control', comment: comment.value },
  })
    .then((response) => {
      toast.fromResponse(response)
      closeModal()
      emit('projectUpdated')
    })
    .catch((err) => {
      toast.fromError(err)
    })
    .finally(() => {
      loading.value = false
    })
}
</script>

<template>
  <span>
    <!-- Modal trigger button (slot) -->
    <span @click="openModal">
      <slot name="opener">
        <button class="btn btn-primary px-2 m-2">
          Lock Component Controls
        </button>
      </slot>
    </span>

    <!-- Modal -->
    <Teleport to="body">
      <div
        v-if="showModal"
        class="modal fade show d-block"
        tabindex="-1"
        style="background-color: rgba(0,0,0,0.5);"
        @click.self="closeModal"
      >
        <div class="modal-dialog modal-lg modal-dialog-centered">
          <div class="modal-content">
            <div class="modal-header">
              <h5 class="modal-title">Lock Component Controls</h5>
              <button
                type="button"
                class="btn-close"
                aria-label="Close"
                @click="closeModal"
              />
            </div>
            <div class="modal-body">
              <form @submit.prevent="lockControls">
                <div class="mb-3">
                  <label for="lockComment" class="form-label">Comment</label>
                  <textarea
                    id="lockComment"
                    v-model="comment"
                    class="form-control"
                    rows="3"
                    placeholder="Leave a comment..."
                    required
                  />
                </div>
              </form>
            </div>
            <div class="modal-footer">
              <button
                type="button"
                class="btn btn-secondary"
                @click="closeModal"
              >
                Cancel
              </button>
              <button
                type="button"
                class="btn btn-primary"
                :disabled="loading"
                @click="lockControls"
              >
                {{ loading ? 'Loading...' : 'Lock Controls' }}
              </button>
            </div>
          </div>
        </div>
      </div>
    </Teleport>
  </span>
</template>
