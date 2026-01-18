import linkify from 'v-linkify'
import { createApp } from 'vue'
import { registerComponents } from '../bootstrap-vue-next-components'
import ProjectComponents from '../components/components/ProjectComponents.vue'

document.addEventListener('DOMContentLoaded', () => {
  const app = createApp({
    components: {
      Projectcomponents: ProjectComponents,
    },
  })

  registerComponents(app)
  app.directive('linkified', linkify)
  app.mount('#projectcomponents')
})
