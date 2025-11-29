import { createApp } from 'vue'
import { registerComponents } from '../bootstrap-vue-next-components'
import Users from '../components/users/Users.vue'

document.addEventListener('DOMContentLoaded', () => {
  const app = createApp({
    components: {
      Users,
    },
  })

  registerComponents(app)
  app.mount('#users')
})
