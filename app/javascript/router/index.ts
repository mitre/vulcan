import { createRouter, createWebHistory } from 'vue-router'
import { useAuthStore } from '../stores'
import routes from '../routes/index.ts'

const router = createRouter({
  history: createWebHistory(),
  routes,
  scrollBehavior(to, from, savedPosition) {
    if (savedPosition) {
      return savedPosition
    }
    else if (to.hash) {
      return { el: to.hash, behavior: 'smooth' }
    }
    else {
      return { top: 0 }
    }
  },
})

// Navigation guard - redirect to login if not authenticated
router.beforeEach((to, from, next) => {
  const authStore = useAuthStore()
  const publicRoutes = ['/users/sign_in', '/auth/confirmation', '/auth/unlock', '/auth/reset-password']
  const isPublicRoute = publicRoutes.includes(to.path)

  if (!isPublicRoute && !authStore.signedIn) {
    // Redirect to login
    next('/users/sign_in')
  }
  else {
    next()
  }
})

export default router
