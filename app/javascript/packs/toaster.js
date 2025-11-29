import { createApp } from 'vue'
import { registerComponents } from '../bootstrap-vue-next-components'
import Toaster from '../components/toaster/Toaster.vue'

// Import Bootstrap and BootstrapVueNext styles
import 'bootstrap/dist/css/bootstrap.css'
import 'bootstrap-vue-next/dist/bootstrap-vue-next.css'

document.addEventListener('DOMContentLoaded', () => {
  const app = createApp({
    components: {
      Toaster,
    },
  })

  registerComponents(app)
  app.mount('#Toaster')
})
