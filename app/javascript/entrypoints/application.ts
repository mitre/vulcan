import { createBootstrap } from 'bootstrap-vue-next'
import { createApp } from 'vue'
import Vue3Linkify from 'vue-3-linkify'
import App from '../App.vue'
import { registerComponents } from '../bootstrap-vue-next-components'
import router from '../router'
import { pinia } from '../stores'

// Configure axios CSRF token (must be before any axios usage)
import '../config/axios'

// Import all styles - esbuild handles SCSS via sassPlugin
import '../application.scss'
import 'bootstrap-vue-next/dist/bootstrap-vue-next.css'
import 'bootstrap-icons/font/bootstrap-icons.css'

document.addEventListener('DOMContentLoaded', () => {
  const app = createApp(App, {
    // Pass props from Rails via data attributes or window object
    navigation: (window as any).vueAppData?.navigation || [],
    signedIn: (window as any).vueAppData?.signedIn || false,
    usersPath: (window as any).vueAppData?.usersPath || '',
    profilePath: (window as any).vueAppData?.profilePath || '/account/settings',
    signOutPath: (window as any).vueAppData?.signOutPath || '/users/sign_out',
    accessRequests: (window as any).vueAppData?.accessRequests || [],
    notice: (window as any).vueAppData?.notice || null,
    alert: (window as any).vueAppData?.alert || null,
    currentUser: (window as any).vueAppData?.currentUser || null,
  })

  app.use(router)
  app.use(pinia)
  // BApp component handles orchestrators (toast, modal, popover)
  // createBootstrap() just provides global defaults - no conflict
  app.use(createBootstrap())
  app.use(Vue3Linkify)
  // Also register as 'linkified' for backward compatibility
  app.directive('linkified', app.directive('linkify')!)
  registerComponents(app)

  app.mount('#app')
})
