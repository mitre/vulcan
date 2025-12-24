// Experimental routes - UI prototypes and design experiments
// These routes are loaded conditionally in development only
// See routes/index.ts for loading logic

import type { RouteRecordRaw } from 'vue-router'

const experimentalRoutes: RouteRecordRaw[] = [
  {
    path: '/login2',
    name: 'login2',
    component: () => import('@/pages/Login2.vue'),
    meta: { experimental: true },
  },
  {
    path: '/components/:componentId/editor2',
    name: 'component_editor2',
    component: () => import('@/pages/components/Editor2DemoPage.vue'),
    meta: { experimental: true },
  },
]

export default experimentalRoutes
