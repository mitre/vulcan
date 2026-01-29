import Vue from 'vue'
import BootstrapVue from 'bootstrap-vue'

Vue.use(BootstrapVue)
Vue.config.productionTip = false

// Mock CSRF token meta tag for FormMixin
if (typeof document !== 'undefined') {
  const meta = document.createElement('meta')
  meta.setAttribute('name', 'csrf-token')
  meta.setAttribute('content', 'test-csrf-token')
  document.head.appendChild(meta)
}
