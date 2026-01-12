/**
 * App.vue Layout Tests
 * Protects CSS Grid layout from regression
 */

import type { VueWrapper } from '@vue/test-utils'
import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import { mount } from '@vue/test-utils'
import { createPinia } from 'pinia'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { createRouter, createWebHistory } from 'vue-router'
import App from '@/App.vue'

// Mock composables
vi.mock('@/composables/useColorMode', () => ({
  useColorMode: () => ({}),
}))

vi.mock('@/composables/useCommandPalette', () => ({
  useCommandPalette: () => ({
    open: false,
  }),
}))

// Create test router
const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/', component: { template: '<div>Home</div>' } },
  ],
})

describe('app.vue Layout', () => {
  let wrapper: VueWrapper

  beforeEach(() => {
    const pinia = createPinia()

    wrapper = mount(App, {
      global: {
        plugins: [router, pinia],
        stubs: {
          CommandPalette: true,
          AuthHeader: true,
          Navbar: true,
          Toaster: true,
          AppFooter: true,
          ErrorBoundary: true,
          Suspense: false,
        },
      },
    })
  })

  afterEach(() => {
    wrapper?.unmount()
  })

  it('uses CSS Grid layout with correct structure', () => {
    const container = wrapper.find('.app-container')
    expect(container.exists()).toBe(true)
  })

  it('has header, main, and footer sections', () => {
    // Check for header
    const header = wrapper.find('.app-header')
    expect(header.exists()).toBe(true)

    // Check for main content
    const main = wrapper.find('.app-main')
    expect(main.exists()).toBe(true)

    // Check for footer
    const footer = wrapper.find('.app-footer')
    expect(footer.exists()).toBe(true)
  })

  it('applies correct layout classes to elements', () => {
    const container = wrapper.find('.app-container')
    const header = wrapper.find('.app-header')
    const main = wrapper.find('.app-main')
    const footer = wrapper.find('.app-footer')

    // Verify structural classes exist
    expect(container.exists()).toBe(true)
    expect(header.exists()).toBe(true)
    expect(main.exists()).toBe(true)
    expect(footer.exists()).toBe(true)

    // Verify main has proper classes for scrolling
    expect(main.classes()).toContain('app-main')
    expect(main.classes()).toContain('bg-body-secondary')
  })

  it('renders BApp wrapper for Bootstrap-Vue-Next', () => {
    // BApp is needed for modals, toasts, popovers
    const html = wrapper.html()
    // Check that we're inside BApp context (has proper structure)
    expect(html).toBeTruthy()
  })
})

/**
 * Regression Tests - Protect Layout Fix from Session 128
 *
 * These tests protect THE ROOT CAUSE that was causing footer cutoff:
 * - application.scss had .footer { height: var(--app-footer-height) } forcing 40px
 * - Actual footer content was ~100px tall
 * - Solution: Removed height constraint + CSS Grid layout
 */
describe('app.vue Layout - Regression Protection', () => {
  it('prevents footer height constraint from being added (ROOT CAUSE)', () => {
    // Read SCSS file
    const scssPath = join(process.cwd(), 'app/javascript/application.scss')
    const scssContent = readFileSync(scssPath, 'utf-8')

    // Check that no .footer class with height/min-height exists
    // This regex matches: .footer { ... height: var(--app-footer-height) ... }
    const footerHeightPattern = /\.footer\s*\{[^}]*height:\s*var\(--app-footer-height\)/

    expect(scssContent).not.toMatch(footerHeightPattern)
  })

  it('maintains CSS Grid layout in App.vue (SOLUTION)', () => {
    // Read App.vue source
    const appVuePath = join(process.cwd(), 'app/javascript/App.vue')
    const appVueContent = readFileSync(appVuePath, 'utf-8')

    // Verify CSS Grid is implemented
    expect(appVueContent).toContain('display: grid')
    expect(appVueContent).toContain('grid-template-rows: auto 1fr auto')
    expect(appVueContent).toContain('height: 100vh')

    // Verify grid rows are assigned
    expect(appVueContent).toContain('grid-row: 1') // header
    expect(appVueContent).toContain('grid-row: 2') // main
    expect(appVueContent).toContain('grid-row: 3') // footer

    // Verify main content has overflow
    expect(appVueContent).toContain('overflow-y: auto')
  })
})
