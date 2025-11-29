/**
 * Vitest Setup for Vue 3 + Pinia
 *
 * This file runs before each test file.
 * Sets up Pinia and mocks browser APIs.
 */

import { config } from '@vue/test-utils'
import { beforeEach, vi } from 'vitest'
import { createPinia, setActivePinia } from 'pinia'

// Create fresh Pinia instance before each test
beforeEach(() => {
  setActivePinia(createPinia())
})

// Mock window.localStorage
const localStorageMock = {
  getItem: vi.fn(() => null),
  setItem: vi.fn(),
  removeItem: vi.fn(),
  clear: vi.fn(),
}
Object.defineProperty(global, 'localStorage', { value: localStorageMock })

// Mock window.alert (used by some legacy code)
global.alert = vi.fn()

// Suppress Vue warnings in tests (optional)
config.global.config.warnHandler = () => {}

// Global stubs for common components (add as needed)
config.global.stubs = {
  // Add component stubs here if needed
  // 'RouterLink': true,
  // 'RouterView': true,
}
