// Route definitions for Vulcan SPA
// Using lazy loading for code splitting

import type { RouteRecordRaw } from 'vue-router'
import experimentalRoutes from './experimental'

const routes: RouteRecordRaw[] = [
  {
    path: '/',
    name: 'root',
    component: () => import('@/pages/projects/IndexPage.vue'),
  },
  // Login page - now part of the SPA
  {
    path: '/users/sign_in',
    name: 'login',
    component: () => import('@/pages/auth/LoginPage.vue'),
    meta: { layout: 'auth' }, // Simple header, no command palette
  },
  {
    path: '/projects',
    name: 'projects',
    component: () => import('@/pages/projects/IndexPage.vue'),
  },
  {
    path: '/projects/new',
    name: 'new_project',
    component: () => import('@/pages/projects/NewPage.vue'),
  },
  {
    path: '/projects/:id',
    name: 'project',
    component: () => import('@/pages/projects/ShowPage.vue'),
  },
  {
    path: '/components',
    redirect: { name: 'benchmarks', query: { tab: 'component' } },
  },
  {
    path: '/components/:id',
    name: 'component',
    component: () => import('@/pages/components/ShowPage.vue'),
  },
  {
    path: '/components/:id/controls',
    name: 'component_controls',
    component: () => import('@/pages/components/ControlsPage.vue'),
  },
  {
    path: '/rules/:id/edit',
    name: 'edit_rule',
    component: () => import('@/pages/rules/EditPage.vue'),
  },
  // Unified Benchmarks page
  {
    path: '/benchmarks',
    name: 'benchmarks',
    component: () => import('@/pages/benchmarks/IndexPage.vue'),
  },
  // Legacy routes redirect to unified benchmarks with tab query param
  {
    path: '/stigs',
    redirect: { name: 'benchmarks', query: { tab: 'stig' } },
  },
  {
    path: '/stigs/:id',
    name: 'stig',
    component: () => import('@/pages/stigs/ShowPage.vue'),
  },
  {
    path: '/srgs',
    redirect: { name: 'benchmarks', query: { tab: 'srg' } },
  },
  {
    path: '/srgs/:id',
    name: 'security_requirements_guide',
    component: () => import('@/pages/srgs/ShowPage.vue'),
  },
  {
    path: '/users',
    name: 'users',
    component: () => import('@/pages/users/IndexPage.vue'),
  },
  {
    path: '/account/settings',
    name: 'account-settings',
    component: () => import('@/pages/users/AccountSettingsPage.vue'),
  },

  // Auth helper routes
  {
    path: '/auth/confirmation',
    name: 'email-confirmation',
    component: () => import('@/pages/auth/EmailConfirmationPage.vue'),
  },
  {
    path: '/auth/unlock',
    name: 'account-unlock',
    component: () => import('@/pages/auth/AccountUnlockPage.vue'),
  },
  {
    path: '/auth/reset-password',
    name: 'reset-password',
    component: () => import('@/pages/auth/PasswordResetEditPage.vue'),
  },

  // Admin routes - nested under AdminLayout
  {
    path: '/admin',
    component: () => import('@/layouts/AdminLayout.vue'),
    meta: { requiresAdmin: true },
    children: [
      {
        path: '',
        name: 'admin_dashboard',
        component: () => import('@/pages/admin/DashboardPage.vue'),
      },
      {
        path: 'users',
        name: 'admin_users',
        component: () => import('@/pages/admin/UsersPage.vue'),
      },
      {
        path: 'audit',
        name: 'admin_audit',
        component: () => import('@/pages/admin/AuditPage.vue'),
      },
      {
        path: 'settings',
        name: 'admin_settings',
        component: () => import('@/pages/admin/SettingsPage.vue'),
      },
      {
        path: 'content/benchmarks',
        name: 'admin_benchmarks',
        component: () => import('@/pages/admin/BenchmarksPage.vue'),
      },
      // Redirects for backwards compatibility
      {
        path: 'content/stigs',
        redirect: { name: 'admin_benchmarks' },
      },
      {
        path: 'content/srgs',
        redirect: { name: 'admin_benchmarks' },
      },
    ],
  },
]

// Load experimental routes in development only
// These are UI prototypes that should not be accessible in production
if (import.meta.env.DEV) {
  routes.push(...experimentalRoutes)
}

export default routes
