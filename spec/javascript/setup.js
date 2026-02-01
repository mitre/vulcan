import Vue from 'vue'
import BootstrapVue from 'bootstrap-vue'
import axios from 'axios'
import { Wormhole } from 'portal-vue'

Vue.use(BootstrapVue)
Vue.config.productionTip = false

// Disable portal-vue duplicate target tracking for tests.
// Without this, tests that mount BootstrapVue components with toasters/modals
// trigger "[portal-vue]: Target already exists" warnings.
// Reference: https://github.com/LinusBorg/portal-vue/issues/204
Wormhole.trackInstances = false

// Mock CSRF token meta tag for FormMixin
if (typeof document !== 'undefined') {
  const meta = document.createElement('meta')
  meta.setAttribute('name', 'csrf-token')
  meta.setAttribute('content', 'test-csrf-token')
  document.head.appendChild(meta)
}

// Initialize axios defaults for FormMixin
axios.defaults.headers = axios.defaults.headers || {}
axios.defaults.headers.common = axios.defaults.headers.common || {}
