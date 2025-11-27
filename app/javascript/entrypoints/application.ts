import { createApp } from 'vue'
import App from '../App.vue'
import router from '../router'
import { pinia } from '../stores'
import { registerComponents } from '../bootstrap-vue-next-components'

// Import Bootstrap and BootstrapVueNext styles
import 'bootstrap/dist/css/bootstrap.css'
import 'bootstrap-vue-next/dist/bootstrap-vue-next.css'

document.addEventListener('DOMContentLoaded', () => {
  const app = createApp(App, {
    // Pass props from Rails via data attributes or window object
    navigation: (window as any).vueAppData?.navigation || [],
    signedIn: (window as any).vueAppData?.signedIn || false,
    usersPath: (window as any).vueAppData?.usersPath || '',
    profilePath: (window as any).vueAppData?.profilePath || '/users/edit',
    signOutPath: (window as any).vueAppData?.signOutPath || '/users/sign_out',
    accessRequests: (window as any).vueAppData?.accessRequests || [],
    notice: (window as any).vueAppData?.notice || null,
    alert: (window as any).vueAppData?.alert || null,
    currentUser: (window as any).vueAppData?.currentUser || null
  })

  app.use(router)
  app.use(pinia)
  registerComponents(app)

  app.mount('#app')
})
