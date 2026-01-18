import { createApp } from 'vue'
import { registerComponents } from '../bootstrap-vue-next-components'
import NewProject from '../components/project/NewProject.vue'

document.addEventListener('DOMContentLoaded', () => {
  const app = createApp({
    components: {
      Newproject: NewProject,
    },
  })

  registerComponents(app)
  app.mount('#NewProject')
})
