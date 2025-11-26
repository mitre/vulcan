import { config } from '@vue/test-utils'
import Vue from 'vue'
import BootstrapVue from 'bootstrap-vue'

// Use BootstrapVue
Vue.use(BootstrapVue)

// Suppress Vue warnings in tests
config.silent = true

// Mock window.localStorage
global.localStorage = {
  getItem: () => null,
  setItem: () => {},
  removeItem: () => {},
  clear: () => {}
}

// Mock $root for event bus
config.mocks = {
  $root: {
    $emit: () => {},
    $on: () => {}
  }
}
