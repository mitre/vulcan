import { describe, it, expect, afterEach } from 'vitest'
import { mount, createLocalVue } from '@vue/test-utils'
import BootstrapVue from 'bootstrap-vue'
import ControlsPageLayout from '@/components/rules/ControlsPageLayout.vue'

const localVue = createLocalVue()
localVue.use(BootstrapVue)

/**
 * ControlsPageLayout Requirements:
 *
 * 1. Layout Structure:
 *    - Command bar (optional, controlled by showCommandBar prop)
 *    - Filter bar (optional, controlled by showFilterBar prop)
 *    - Two-column layout: left sidebar + main content
 *
 * 2. Conditional Rendering:
 *    - Main content shows when hasSelectedRule=true, empty state otherwise
 *    - Command bar and filter bar are independent of rule selection
 *    - Modals and right-panels ALWAYS render (they contain slideovers that
 *      may show component-level info even without a rule selected)
 *
 * 3. Responsive:
 *    - Mobile: full width columns
 *    - Desktop: configurable sidebar width
 */
describe('ControlsPageLayout', () => {
  let wrapper

  const createWrapper = (props = {}, slots = {}) => {
    return mount(ControlsPageLayout, {
      localVue,
      propsData: {
        hasSelectedRule: false,
        ...props
      },
      slots: {
        'left-sidebar': '<div class="test-left-sidebar">Left Sidebar</div>',
        'main-content': '<div class="test-main-content">Main Content</div>',
        'modals': '<div class="test-modals">Modals</div>',
        'right-panels': '<div class="test-right-panels">Right Panels</div>',
        ...slots
      }
    })
  }

  afterEach(() => {
    if (wrapper) {
      wrapper.destroy()
    }
  })

  describe('layout structure', () => {
    it('renders the layout container', () => {
      wrapper = createWrapper()
      expect(wrapper.find('.controls-page-layout').exists()).toBe(true)
    })

    it('renders the two-column row', () => {
      wrapper = createWrapper()
      expect(wrapper.find('.row').exists()).toBe(true)
    })

    it('always renders left sidebar slot', () => {
      wrapper = createWrapper()
      expect(wrapper.find('.test-left-sidebar').exists()).toBe(true)
    })
  })

  describe('main content area', () => {
    it('shows main content when rule is selected', () => {
      wrapper = createWrapper({ hasSelectedRule: true })
      expect(wrapper.find('.test-main-content').exists()).toBe(true)
      expect(wrapper.text()).not.toContain('No control currently selected')
    })

    it('shows empty state when no rule is selected', () => {
      wrapper = createWrapper({ hasSelectedRule: false })
      expect(wrapper.find('.test-main-content').exists()).toBe(false)
      expect(wrapper.text()).toContain('No control currently selected')
    })

    it('uses custom emptyStateMessage when provided', () => {
      wrapper = createWrapper({
        hasSelectedRule: false,
        emptyStateMessage: 'Please select a rule'
      })
      expect(wrapper.text()).toContain('Please select a rule')
    })
  })

  describe('command bar slot', () => {
    it('does not render command-bar when showCommandBar is false (default)', () => {
      wrapper = createWrapper({}, {
        'command-bar': '<div class="test-command-bar">Command Bar</div>'
      })
      expect(wrapper.find('.test-command-bar').exists()).toBe(false)
    })

    it('renders command-bar when showCommandBar is true', () => {
      wrapper = createWrapper(
        { showCommandBar: true },
        { 'command-bar': '<div class="test-command-bar">Command Bar</div>' }
      )
      expect(wrapper.find('.test-command-bar').exists()).toBe(true)
    })

    it('renders command-bar regardless of rule selection (for component-level actions)', () => {
      // IMPORTANT: Command bar should show even without a selected rule
      // because it contains component-level actions like Edit, Release, Members
      wrapper = createWrapper(
        { showCommandBar: true, hasSelectedRule: false },
        { 'command-bar': '<div class="test-command-bar">Command Bar</div>' }
      )
      expect(wrapper.find('.test-command-bar').exists()).toBe(true)
    })
  })

  describe('filter bar slot', () => {
    it('does not render filter-bar when showFilterBar is false (default)', () => {
      wrapper = createWrapper({}, {
        'filter-bar': '<div class="test-filter-bar">Filter Bar</div>'
      })
      expect(wrapper.find('.test-filter-bar').exists()).toBe(false)
    })

    it('renders filter-bar when showFilterBar is true', () => {
      wrapper = createWrapper(
        { showFilterBar: true },
        { 'filter-bar': '<div class="test-filter-bar">Filter Bar</div>' }
      )
      expect(wrapper.find('.test-filter-bar').exists()).toBe(true)
    })
  })

  describe('modals slot', () => {
    // CRITICAL: Modals must ALWAYS render regardless of rule selection
    // They contain component-level modals (Members, etc.) that work without a rule

    it('always renders modals slot regardless of rule selection', () => {
      wrapper = createWrapper({ hasSelectedRule: false })
      expect(wrapper.find('.test-modals').exists()).toBe(true)
    })

    it('renders modals slot when rule is selected', () => {
      wrapper = createWrapper({ hasSelectedRule: true })
      expect(wrapper.find('.test-modals').exists()).toBe(true)
    })
  })

  describe('right-panels slot (slideovers)', () => {
    // CRITICAL: Right panels (slideovers) must ALWAYS render regardless of rule selection
    // They contain:
    // - Component-level panels (Details, Metadata, Questions, History, Reviews)
    // - Rule-level panels (Satisfies, Reviews, History) - disabled when no rule selected
    //
    // If they don't render, clicking panel buttons does nothing (the bug we fixed)

    it('always renders right-panels slot regardless of rule selection', () => {
      wrapper = createWrapper({ hasSelectedRule: false })
      expect(wrapper.find('.test-right-panels').exists()).toBe(true)
    })

    it('renders right-panels slot when rule is selected', () => {
      wrapper = createWrapper({ hasSelectedRule: true })
      expect(wrapper.find('.test-right-panels').exists()).toBe(true)
    })
  })

  describe('responsive column widths', () => {
    it('uses default sidebar width of 2 columns on desktop', () => {
      wrapper = createWrapper({ hasSelectedRule: true })
      const sidebar = wrapper.find('.left-sidebar-column')
      const main = wrapper.find('.main-content-column')

      // Mobile: full width
      expect(sidebar.classes()).toContain('col-12')
      expect(main.classes()).toContain('col-12')

      // Desktop: 2 + 10 = 12 columns
      expect(sidebar.classes()).toContain('col-md-2')
      expect(main.classes()).toContain('col-md-10')
    })

    it('uses custom sidebarWidth when provided', () => {
      wrapper = createWrapper({ hasSelectedRule: true, sidebarWidth: 3 })
      const sidebar = wrapper.find('.left-sidebar-column')
      const main = wrapper.find('.main-content-column')

      // Desktop: 3 + 9 = 12 columns
      expect(sidebar.classes()).toContain('col-md-3')
      expect(main.classes()).toContain('col-md-9')
    })

    it('validates sidebarWidth is between 1 and 6', () => {
      // This tests the prop validator
      const validator = ControlsPageLayout.props.sidebarWidth.validator
      expect(validator(1)).toBe(true)
      expect(validator(6)).toBe(true)
      expect(validator(0)).toBe(false)
      expect(validator(7)).toBe(false)
    })
  })
})
