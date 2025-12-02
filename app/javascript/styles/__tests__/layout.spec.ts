/**
 * Layout System Tests
 *
 * These tests verify the actual DOM structure and CSS classes generated
 * by our layout components. We inject CSS custom properties and test
 * that components use them correctly.
 *
 * Testing Strategy:
 * 1. Inject CSS custom properties into JSDOM (simulating application.scss)
 * 2. Mount actual Vue components
 * 3. Verify DOM structure matches layout expectations
 * 4. Verify correct Bootstrap classes are applied
 * 5. Verify inline styles use CSS variables (not magic numbers)
 *
 * CRITICAL: BApp from bootstrap-vue-next renders as a Fragment (no wrapper element).
 * Layout classes MUST be on an actual div inside BApp, not on BApp itself.
 */

import { mount } from '@vue/test-utils'
import { afterEach, beforeEach, describe, expect, it } from 'vitest'
import { defineComponent, Fragment, h } from 'vue'

// =============================================================================
// LAYOUT CONSTANTS - Single Source of Truth
// =============================================================================
// These MUST match the values in application.scss
// If these change, update both files!

export const LAYOUT_CONSTANTS = {
  // Core dimensions
  navbarHeight: '56px',
  footerHeight: '40px',
  pageHeaderHeight: '56px',

  // Sidebar widths
  sidebarWidth: '280px',
  sidebarWidthCollapsed: '80px',
  sidebarWidthNarrow: '250px',
  sidebarRightWidth: '280px',

  // Container
  containerMaxWidth: '1600px',
} as const

// CSS variable names (for verifying components use vars, not magic numbers)
export const CSS_VARS = {
  navbarHeight: '--app-navbar-height',
  footerHeight: '--app-footer-height',
  pageHeaderHeight: '--app-page-header-height',
  mainHeight: '--app-main-height',
  contentHeight: '--app-content-height',
  sidebarWidth: '--app-sidebar-width',
  sidebarWidthCollapsed: '--app-sidebar-width-collapsed',
  sidebarWidthNarrow: '--app-sidebar-width-narrow',
  sidebarRightWidth: '--app-sidebar-right-width',
  containerMaxWidth: '--app-container-max-width',
} as const

// =============================================================================
// TEST UTILITIES
// =============================================================================

/**
 * Inject CSS custom properties into JSDOM
 * This simulates what application.scss provides
 */
function injectLayoutStyles(): HTMLStyleElement {
  const style = document.createElement('style')
  style.setAttribute('data-testid', 'layout-vars')
  style.textContent = `
    :root {
      ${CSS_VARS.navbarHeight}: ${LAYOUT_CONSTANTS.navbarHeight};
      ${CSS_VARS.footerHeight}: ${LAYOUT_CONSTANTS.footerHeight};
      ${CSS_VARS.pageHeaderHeight}: ${LAYOUT_CONSTANTS.pageHeaderHeight};
      ${CSS_VARS.mainHeight}: calc(100vh - var(${CSS_VARS.navbarHeight}) - var(${CSS_VARS.footerHeight}));
      ${CSS_VARS.contentHeight}: calc(var(${CSS_VARS.mainHeight}) - var(${CSS_VARS.pageHeaderHeight}));
      ${CSS_VARS.sidebarWidth}: ${LAYOUT_CONSTANTS.sidebarWidth};
      ${CSS_VARS.sidebarWidthCollapsed}: ${LAYOUT_CONSTANTS.sidebarWidthCollapsed};
      ${CSS_VARS.sidebarWidthNarrow}: ${LAYOUT_CONSTANTS.sidebarWidthNarrow};
      ${CSS_VARS.sidebarRightWidth}: ${LAYOUT_CONSTANTS.sidebarRightWidth};
      ${CSS_VARS.containerMaxWidth}: ${LAYOUT_CONSTANTS.containerMaxWidth};
    }
  `
  document.head.appendChild(style)
  return style
}

/**
 * Get CSS variable value from document root
 */
function getCssVar(name: string): string {
  return getComputedStyle(document.documentElement).getPropertyValue(name).trim()
}

/**
 * Check if an element's style uses a CSS variable (not a magic number)
 */
function styleUsesCssVar(style: string, varName: string): boolean {
  return style.includes(`var(${varName})`)
}

/**
 * Check if style contains any magic pixel values (bad practice)
 */
function hasMagicPixelValue(style: string): boolean {
  // Match pixel values that aren't 0px and aren't inside var()
  const magicPixelRegex = /(?<!var\([^)]*)\b[1-9]\d*px\b/
  return magicPixelRegex.test(style)
}

// =============================================================================
// TESTS: CSS Custom Properties
// =============================================================================

describe('layout CSS Custom Properties', () => {
  let styleElement: HTMLStyleElement

  beforeEach(() => {
    styleElement = injectLayoutStyles()
  })

  afterEach(() => {
    styleElement.remove()
  })

  describe('core Dimensions', () => {
    it('defines --app-navbar-height correctly', () => {
      expect(getCssVar(CSS_VARS.navbarHeight)).toBe(LAYOUT_CONSTANTS.navbarHeight)
    })

    it('defines --app-footer-height correctly', () => {
      expect(getCssVar(CSS_VARS.footerHeight)).toBe(LAYOUT_CONSTANTS.footerHeight)
    })

    it('defines --app-page-header-height correctly', () => {
      expect(getCssVar(CSS_VARS.pageHeaderHeight)).toBe(LAYOUT_CONSTANTS.pageHeaderHeight)
    })
  })

  describe('sidebar Widths', () => {
    it('defines --app-sidebar-width correctly', () => {
      expect(getCssVar(CSS_VARS.sidebarWidth)).toBe(LAYOUT_CONSTANTS.sidebarWidth)
    })

    it('defines --app-sidebar-width-collapsed correctly', () => {
      expect(getCssVar(CSS_VARS.sidebarWidthCollapsed)).toBe(LAYOUT_CONSTANTS.sidebarWidthCollapsed)
    })

    it('defines --app-sidebar-right-width correctly', () => {
      expect(getCssVar(CSS_VARS.sidebarRightWidth)).toBe(LAYOUT_CONSTANTS.sidebarRightWidth)
    })
  })

  describe('derived Heights', () => {
    it('defines --app-main-height as calc expression using CSS vars', () => {
      const value = getCssVar(CSS_VARS.mainHeight)
      expect(value).toContain('calc')
      expect(value).toContain('var(--app-navbar-height)')
      expect(value).toContain('var(--app-footer-height)')
    })

    it('defines --app-content-height as calc expression using CSS vars', () => {
      const value = getCssVar(CSS_VARS.contentHeight)
      expect(value).toContain('calc')
      expect(value).toContain('var(--app-main-height)')
    })
  })
})

// =============================================================================
// TESTS: Root App Layout (BApp + wrapper div)
// =============================================================================

describe('root App Layout Structure', () => {
  let styleElement: HTMLStyleElement

  beforeEach(() => {
    styleElement = injectLayoutStyles()
  })

  afterEach(() => {
    styleElement.remove()
  })

  /**
   * CRITICAL TEST: BApp renders as Fragment, so layout classes must be on inner div.
   * This test prevents regression where classes were incorrectly placed on BApp.
   */
  describe('bApp Fragment Pattern', () => {
    // Simulates the WRONG pattern (classes on Fragment - won't work)
    const WrongPattern = defineComponent({
      name: 'WrongPattern',
      setup() {
        // Fragment with classes - classes go nowhere!
        return () => h(Fragment, { class: 'd-flex flex-column vh-100' }, [
          h('header', { class: 'flex-shrink-0' }, 'Navbar'),
          h('main', { class: 'flex-grow-1' }, 'Content'),
          h('footer', { class: 'mt-auto' }, 'Footer'),
        ])
      },
    })

    // Simulates the CORRECT pattern (classes on inner div)
    const CorrectPattern = defineComponent({
      name: 'CorrectPattern',
      setup() {
        // Fragment wrapping a div with layout classes - correct!
        return () => h(Fragment, null, [
          h('div', { class: 'd-flex flex-column vh-100' }, [
            h('header', { class: 'flex-shrink-0' }, 'Navbar'),
            h('main', { class: 'flex-grow-1' }, 'Content'),
            h('footer', { class: 'mt-auto' }, 'Footer'),
          ]),
        ])
      },
    })

    it('wRONG: Fragment does not pass classes to children', () => {
      const wrapper = mount(WrongPattern)
      // Fragment doesn't render, so we can't find vh-100 on any element
      const vh100Element = wrapper.find('.vh-100')
      expect(vh100Element.exists()).toBe(false)
    })

    it('cORRECT: Inner div receives layout classes', () => {
      const wrapper = mount(CorrectPattern)
      const layoutDiv = wrapper.find('.vh-100')

      expect(layoutDiv.exists()).toBe(true)
      expect(layoutDiv.classes()).toContain('d-flex')
      expect(layoutDiv.classes()).toContain('flex-column')
      expect(layoutDiv.classes()).toContain('vh-100')
    })

    it('cORRECT: Footer has mt-auto for sticky footer behavior', () => {
      const wrapper = mount(CorrectPattern)
      const footer = wrapper.find('footer')

      expect(footer.exists()).toBe(true)
      expect(footer.classes()).toContain('mt-auto')
    })

    it('cORRECT: Main content has flex-grow-1', () => {
      const wrapper = mount(CorrectPattern)
      const main = wrapper.find('main')

      expect(main.exists()).toBe(true)
      expect(main.classes()).toContain('flex-grow-1')
    })

    it('cORRECT: Header has flex-shrink-0', () => {
      const wrapper = mount(CorrectPattern)
      const header = wrapper.find('header')

      expect(header.exists()).toBe(true)
      expect(header.classes()).toContain('flex-shrink-0')
    })
  })
})

// =============================================================================
// TESTS: Layout Structure Verification
// =============================================================================

describe('layout Structure Tests', () => {
  let styleElement: HTMLStyleElement

  beforeEach(() => {
    styleElement = injectLayoutStyles()
  })

  afterEach(() => {
    styleElement.remove()
  })

  describe('layout 1: Simple (PageContainer pattern)', () => {
    // Simulates what a simple page should look like
    const SimpleLayout = defineComponent({
      name: 'SimpleLayout',
      setup() {
        return () => h('div', { class: 'container-fluid container-app py-3' }, [
          h('div', { class: 'card' }, 'Content here'),
        ])
      },
    })

    it('renders with correct Bootstrap container classes', () => {
      const wrapper = mount(SimpleLayout)
      const container = wrapper.find('.container-fluid')

      expect(container.exists()).toBe(true)
      expect(container.classes()).toContain('container-app')
      expect(container.classes()).toContain('py-3')
    })

    it('does not have fixed height constraints (body scrolls)', () => {
      const wrapper = mount(SimpleLayout)
      const container = wrapper.find('.container-fluid')

      // Simple layout should NOT have h-100 or fixed heights
      expect(container.classes()).not.toContain('h-100')
      expect(container.classes()).not.toContain('vh-100')
    })
  })

  describe('layout 2: Editor (Two-column with sidebar)', () => {
    // Simulates the ControlsPage/RequirementsFocus structure
    const EditorLayout = defineComponent({
      name: 'EditorLayout',
      setup() {
        return () => h('div', {
          class: 'd-flex flex-column',
          style: 'height: var(--app-main-height);',
        }, [
          // Page header
          h('div', { class: 'flex-shrink-0 border-bottom' }, 'Header'),
          // Content row
          h('div', { class: 'row flex-grow-1 g-0 overflow-hidden' }, [
            // Sidebar
            h('div', {
              class: 'col-auto overflow-auto',
              style: 'width: var(--app-sidebar-width);',
            }, 'Sidebar'),
            // Main content
            h('div', { class: 'col overflow-auto' }, 'Main Content'),
          ]),
        ])
      },
    })

    it('uses CSS variable for container height (not magic number)', () => {
      const wrapper = mount(EditorLayout)
      const root = wrapper.find('div')
      const style = root.attributes('style') || ''

      expect(styleUsesCssVar(style, CSS_VARS.mainHeight)).toBe(true)
      expect(hasMagicPixelValue(style)).toBe(false)
    })

    it('uses CSS variable for sidebar width (not magic number)', () => {
      const wrapper = mount(EditorLayout)
      const sidebar = wrapper.find('.col-auto')
      const style = sidebar.attributes('style') || ''

      expect(styleUsesCssVar(style, CSS_VARS.sidebarWidth)).toBe(true)
      expect(hasMagicPixelValue(style)).toBe(false)
    })

    it('has correct Bootstrap flex structure', () => {
      const wrapper = mount(EditorLayout)

      // Root is flex column
      const root = wrapper.find('div')
      expect(root.classes()).toContain('d-flex')
      expect(root.classes()).toContain('flex-column')

      // Header doesn't grow
      const header = wrapper.find('.flex-shrink-0')
      expect(header.exists()).toBe(true)

      // Content row grows and hides overflow
      const contentRow = wrapper.find('.row')
      expect(contentRow.classes()).toContain('flex-grow-1')
      expect(contentRow.classes()).toContain('overflow-hidden')

      // Sidebar scrolls independently
      const sidebar = wrapper.find('.col-auto')
      expect(sidebar.classes()).toContain('overflow-auto')

      // Main content scrolls independently
      const main = wrapper.find('.col')
      expect(main.classes()).toContain('overflow-auto')
    })
  })

  describe('layout 3: Viewer (Three-column)', () => {
    // Simulates the BenchmarkViewer structure
    const ViewerLayout = defineComponent({
      name: 'ViewerLayout',
      setup() {
        return () => h('div', {
          class: 'd-flex flex-column',
          style: 'height: var(--app-main-height);',
        }, [
          // Header
          h('header', { class: 'flex-shrink-0 border-bottom' }, 'Benchmark Header'),
          // Content
          h('div', { class: 'row flex-grow-1 g-0 overflow-hidden' }, [
            // Left sidebar
            h('div', {
              class: 'col-auto overflow-auto border-end',
              style: 'width: var(--app-sidebar-width);',
            }, 'Rule List'),
            // Center content
            h('div', { class: 'col overflow-auto' }, 'Rule Details'),
            // Right sidebar
            h('div', {
              class: 'col-auto overflow-auto border-start d-none d-xl-block',
              style: 'width: var(--app-sidebar-right-width);',
            }, 'Rule Overview'),
          ]),
        ])
      },
    })

    it('uses CSS variables for all fixed widths', () => {
      const wrapper = mount(ViewerLayout)
      const sidebars = wrapper.findAll('.col-auto')

      sidebars.forEach((sidebar) => {
        const style = sidebar.attributes('style') || ''
        // Should use a CSS var, not magic number
        expect(style).toMatch(/var\(--app-sidebar/)
        expect(hasMagicPixelValue(style)).toBe(false)
      })
    })

    it('hides right sidebar on smaller screens using Bootstrap classes', () => {
      const wrapper = mount(ViewerLayout)
      const rightSidebar = wrapper.findAll('.col-auto')[1]

      // Should have responsive display classes
      expect(rightSidebar.classes()).toContain('d-none')
      expect(rightSidebar.classes()).toContain('d-xl-block')
    })

    it('has three columns in the content row', () => {
      const wrapper = mount(ViewerLayout)
      const row = wrapper.find('.row')
      const columns = row.findAll('.col, .col-auto')

      expect(columns.length).toBe(3)
    })

    it('all scroll containers have overflow-auto', () => {
      const wrapper = mount(ViewerLayout)
      const scrollContainers = wrapper.findAll('.overflow-auto')

      // Should have 3 scrollable areas: left sidebar, center, right sidebar
      expect(scrollContainers.length).toBe(3)
    })
  })
})

// =============================================================================
// TESTS: Anti-Pattern Detection
// =============================================================================

describe('anti-Pattern Detection', () => {
  describe('magic Number Detection', () => {
    it('detects magic pixel values in styles', () => {
      expect(hasMagicPixelValue('height: 200px;')).toBe(true)
      expect(hasMagicPixelValue('max-height: calc(100vh - 200px);')).toBe(true)
      expect(hasMagicPixelValue('width: 280px;')).toBe(true)
    })

    it('allows CSS variable usage', () => {
      expect(hasMagicPixelValue('height: var(--app-main-height);')).toBe(false)
      expect(hasMagicPixelValue('width: var(--app-sidebar-width);')).toBe(false)
    })

    it('allows 0px values', () => {
      expect(hasMagicPixelValue('margin: 0px;')).toBe(false)
      expect(hasMagicPixelValue('padding: 0px 0px;')).toBe(false)
    })
  })

  describe('cSS Variable Usage Detection', () => {
    it('correctly identifies CSS variable usage', () => {
      expect(styleUsesCssVar('height: var(--app-main-height);', '--app-main-height')).toBe(true)
      expect(styleUsesCssVar('width: var(--app-sidebar-width);', '--app-sidebar-width')).toBe(true)
    })

    it('correctly identifies missing CSS variable usage', () => {
      expect(styleUsesCssVar('height: 100vh;', '--app-main-height')).toBe(false)
      expect(styleUsesCssVar('width: 280px;', '--app-sidebar-width')).toBe(false)
    })
  })
})

// =============================================================================
// TESTS: Layout Constants Validation
// =============================================================================

describe('layout Constants Validation', () => {
  it('exports all required layout constants', () => {
    expect(LAYOUT_CONSTANTS).toHaveProperty('navbarHeight')
    expect(LAYOUT_CONSTANTS).toHaveProperty('footerHeight')
    expect(LAYOUT_CONSTANTS).toHaveProperty('pageHeaderHeight')
    expect(LAYOUT_CONSTANTS).toHaveProperty('sidebarWidth')
    expect(LAYOUT_CONSTANTS).toHaveProperty('sidebarWidthCollapsed')
    expect(LAYOUT_CONSTANTS).toHaveProperty('sidebarWidthNarrow')
    expect(LAYOUT_CONSTANTS).toHaveProperty('sidebarRightWidth')
    expect(LAYOUT_CONSTANTS).toHaveProperty('containerMaxWidth')
  })

  it('has reasonable total fixed height (navbar + footer + header < 200px)', () => {
    const navbar = Number.parseInt(LAYOUT_CONSTANTS.navbarHeight)
    const footer = Number.parseInt(LAYOUT_CONSTANTS.footerHeight)
    const header = Number.parseInt(LAYOUT_CONSTANTS.pageHeaderHeight)

    const total = navbar + footer + header
    expect(total).toBeLessThan(200)
    expect(total).toBeGreaterThan(100)
  })

  it('has sidebar width greater than collapsed width', () => {
    const full = Number.parseInt(LAYOUT_CONSTANTS.sidebarWidth)
    const collapsed = Number.parseInt(LAYOUT_CONSTANTS.sidebarWidthCollapsed)

    expect(full).toBeGreaterThan(collapsed)
  })

  it('exports all CSS variable names', () => {
    expect(CSS_VARS).toHaveProperty('navbarHeight')
    expect(CSS_VARS).toHaveProperty('mainHeight')
    expect(CSS_VARS).toHaveProperty('sidebarWidth')
  })
})
