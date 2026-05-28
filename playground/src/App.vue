<script setup lang="ts">
import { BApp, BButton, BContainer, useToast } from 'bootstrap-vue-next'
import { getCurrentInstance } from 'vue'

// Test 1: useToast with create() - what we're using in Vulcan
const toast = useToast()

// Debug: Check app instance
const instance = getCurrentInstance()
console.log('[Playground] Provides:', Object.keys(instance?.appContext.provides || {}))
console.log('[Playground] _isOrchestratorInstalled at setup:', toast._isOrchestratorInstalled?.value)

function testCreate() {
  console.log('[Test 1] Using useToast().create()')
  console.log('  _isOrchestratorInstalled at click:', toast._isOrchestratorInstalled?.value)
  console.log('  store before:', toast.store.value.length)

  const result = toast.create({
    title: 'Test Create',
    body: 'This uses useToast().create()',
    variant: 'success',
    pos: 'top-end',
    modelValue: 5000,
  })

  console.log('  create returned:', result)
  console.log('  store after:', toast.store.value.length)
  console.log('  store contents:', JSON.stringify(toast.store.value))
}

function testShow() {
  console.log('[Test 2] Using useToast().show()')
  console.log('  store before:', toast.store.value.length)

  // Try show() method instead
  const result = toast.show?.({
    props: {
      title: 'Test Show',
      body: 'This uses useToast().show()',
      variant: 'info',
    }
  })

  console.log('  show returned:', result)
  console.log('  store after:', toast.store.value.length)
}

// Log what methods are available
console.log('[App.vue] useToast() returned:', Object.keys(toast))
console.log('[App.vue] toast.create is:', typeof toast.create)
console.log('[App.vue] toast.show is:', typeof toast.show)
</script>

<template>
  <BApp>
    <BContainer class="py-5">
      <h1>BVN Toast Playground</h1>
      <p class="text-muted">Testing bootstrap-vue-next 0.40.8 toast functionality</p>

      <div class="d-flex gap-3 my-4">
        <BButton variant="success" @click="testCreate">
          Test create()
        </BButton>

        <BButton variant="info" @click="testShow">
          Test show()
        </BButton>
      </div>

      <div class="alert alert-secondary">
        <h5>Debug Info</h5>
        <p>Open browser console to see logs</p>
        <p>Store length: {{ toast.store.value.length }}</p>
        <pre>{{ JSON.stringify(toast.store.value, null, 2) }}</pre>
      </div>
    </BContainer>
  </BApp>
</template>
