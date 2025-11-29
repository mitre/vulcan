import { createApp } from 'vue'
import { registerComponents } from '../bootstrap-vue-next-components'

// Import Bootstrap and BootstrapVueNext styles
import 'bootstrap/dist/css/bootstrap.css'
import 'bootstrap-vue-next/dist/bootstrap-vue-next.css'

document.addEventListener('DOMContentLoaded', () => {
  const app = createApp({})
  registerComponents(app)
  app.mount('#login')
})
