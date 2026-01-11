import { createBootstrap } from 'bootstrap-vue-next'
import { createApp } from 'vue'
import LoginPage from '../pages/auth/LoginPage.vue'
import { pinia } from '../stores'

// Configure axios CSRF token
import '../config/axios'

// Import all styles
import '../application.scss'
import 'bootstrap-vue-next/dist/bootstrap-vue-next.css'
import 'bootstrap-icons/font/bootstrap-icons.css'

document.addEventListener('DOMContentLoaded', () => {
  const app = createApp(LoginPage)

  app.use(pinia)
  app.use(createBootstrap())

  app.mount('#app')
})
