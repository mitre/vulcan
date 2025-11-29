// Route definitions for Vulcan SPA
// Using lazy loading for code splitting

const routes = [
  {
    path: '/',
    name: 'root',
    component: () => import('@/pages/projects/IndexPage.vue'),
  },
  {
    path: '/users/sign_in',
    name: 'login',
    component: () => import('@/pages/auth/LoginPage.vue'),
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
    name: 'components',
    component: () => import('@/pages/components/IndexPage.vue'),
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
  {
    path: '/stigs',
    name: 'stigs',
    component: () => import('@/pages/stigs/IndexPage.vue'),
  },
  {
    path: '/stigs/:id',
    name: 'stig',
    component: () => import('@/pages/stigs/ShowPage.vue'),
  },
  {
    path: '/srgs',
    name: 'security_requirements_guides',
    component: () => import('@/pages/srgs/IndexPage.vue'),
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
]

export default routes
