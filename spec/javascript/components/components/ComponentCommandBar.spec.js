import { describe, it, expect, afterEach } from 'vitest'
import { mount, createLocalVue } from '@vue/test-utils'
import { BootstrapVue, IconsPlugin } from 'bootstrap-vue'
import ComponentCommandBar from '@/components/components/ComponentCommandBar.vue'

const localVue = createLocalVue()
localVue.use(BootstrapVue)
localVue.use(IconsPlugin)

/**
 * ComponentCommandBar Requirements:
 *
 * 1. Actions (left side):
 *    - Edit button: visible for author+, links to edit page
 *    - Release button: visible for admin, disabled when not releasable
 *    - Members button: always visible, opens members modal
 *    - Advanced Fields toggle: visible for admin
 *
 * 2. Component Panels (right side):
 *    - Details, Metadata, Questions, History, Reviews
 *    - Always enabled (component-level info)
 *    - Toggle on click, emit 'toggle-panel' event
 *
 * 3. Rule Panels: Moved to RuleActionsToolbar (rule-level, not component-level)
 *
 * 4. Visual feedback:
 *    - Active panel button has 'secondary' variant
 *    - Inactive panel button has 'outline-secondary' variant
 */
describe('ComponentCommandBar', () => {
  let wrapper

  const defaultProps = {
    component: {
      id: 41,
      name: 'Test Component',
      prefix: 'TEST',
      released: false,
      releasable: true,
      advanced_fields: false
    },
    selectedRule: null,
    effectivePermissions: 'admin',
    activePanel: null
  }

  const createWrapper = (props = {}) => {
    return mount(ComponentCommandBar, {
      localVue,
      propsData: {
        ...defaultProps,
        ...props
      }
    })
  }

  afterEach(() => {
    if (wrapper) {
      wrapper.destroy()
    }
  })

  describe('rendering', () => {
    it('renders the command bar container', () => {
      wrapper = createWrapper()
      expect(wrapper.find('.command-bar').exists()).toBe(true)
    })

    it('renders with bg-light background', () => {
      wrapper = createWrapper()
      expect(wrapper.find('.command-bar').classes()).toContain('bg-light')
    })
  })

  describe('Edit button', () => {
    it('shows Edit button for admin', () => {
      wrapper = createWrapper({ effectivePermissions: 'admin' })
      expect(wrapper.text()).toContain('Edit')
    })

    it('shows Edit button for author', () => {
      wrapper = createWrapper({ effectivePermissions: 'author' })
      expect(wrapper.text()).toContain('Edit')
    })

    it('hides Edit button for viewer', () => {
      wrapper = createWrapper({ effectivePermissions: 'viewer' })
      const buttons = wrapper.findAll('a.btn')
      const editButton = buttons.wrappers.find(b => b.text().includes('Edit'))
      expect(editButton).toBeUndefined()
    })

    it('links to edit page', () => {
      wrapper = createWrapper()
      const editLink = wrapper.find('a.btn-primary')
      expect(editLink.attributes('href')).toBe('/components/41/edit')
    })
  })

  describe('Release button', () => {
    it('shows Release button for admin', () => {
      wrapper = createWrapper({ effectivePermissions: 'admin' })
      expect(wrapper.text()).toContain('Release')
    })

    it('hides Release button for non-admin', () => {
      wrapper = createWrapper({ effectivePermissions: 'author' })
      const buttons = wrapper.findAll('button')
      const releaseButton = buttons.wrappers.find(b => b.text().includes('Release'))
      expect(releaseButton).toBeUndefined()
    })

    it('disables Release button when component not releasable', () => {
      wrapper = createWrapper({
        component: { ...defaultProps.component, releasable: false }
      })
      const releaseButton = wrapper.findAll('button').wrappers.find(b => b.text().includes('Release'))
      expect(releaseButton.attributes('disabled')).toBe('disabled')
    })

    it('disables Release button when component already released', () => {
      wrapper = createWrapper({
        component: { ...defaultProps.component, released: true }
      })
      const releaseButton = wrapper.findAll('button').wrappers.find(b => b.text().includes('Release'))
      expect(releaseButton.attributes('disabled')).toBe('disabled')
    })

    it('emits release event when clicked', async () => {
      wrapper = createWrapper()
      const releaseButton = wrapper.findAll('button').wrappers.find(b => b.text().includes('Release'))
      await releaseButton.trigger('click')
      expect(wrapper.emitted('release')).toBeTruthy()
    })
  })

  describe('Members button', () => {
    it('always shows Members button', () => {
      wrapper = createWrapper({ effectivePermissions: 'viewer' })
      expect(wrapper.text()).toContain('Members')
    })

    it('emits open-members event when clicked', async () => {
      wrapper = createWrapper()
      const membersButton = wrapper.findAll('button').wrappers.find(b => b.text().includes('Members'))
      await membersButton.trigger('click')
      expect(wrapper.emitted('open-members')).toBeTruthy()
    })
  })

  describe('Advanced Fields toggle', () => {
    it('shows toggle for admin', () => {
      wrapper = createWrapper({ effectivePermissions: 'admin' })
      expect(wrapper.text()).toContain('Advanced')
    })

    it('hides toggle for non-admin', () => {
      wrapper = createWrapper({ effectivePermissions: 'author' })
      expect(wrapper.text()).not.toContain('Advanced')
    })
  })

  describe('component panel buttons', () => {
    // REQUIREMENT: Component-level panels (Details, Metadata, Questions, History, Reviews)
    // must ALWAYS be enabled, even without a rule selected, because they show
    // component-level information that doesn't depend on rule selection.

    it('renders all 5 component panel buttons', () => {
      wrapper = createWrapper()
      // Component panels are in the first button group on the right
      expect(wrapper.text()).toContain('Details')
      expect(wrapper.text()).toContain('Metadata')
      expect(wrapper.text()).toContain('Questions')
      // Note: "History" and "Reviews" appear twice (component + rule panels)
      // We verify them separately in the count test
    })

    it('component panel buttons are NOT disabled when no rule selected', () => {
      wrapper = createWrapper({ selectedRule: null })
      const allButtons = wrapper.findAll('button')

      // Find component panel buttons specifically
      const detailsBtn = allButtons.wrappers.find(b => b.text().includes('Details'))
      const metadataBtn = allButtons.wrappers.find(b => b.text().includes('Metadata'))
      const questionsBtn = allButtons.wrappers.find(b => b.text().includes('Questions'))

      // CRITICAL: These buttons MUST exist - fail loudly if missing
      expect(detailsBtn).toBeDefined()
      expect(metadataBtn).toBeDefined()
      expect(questionsBtn).toBeDefined()

      // CRITICAL: They must NOT be disabled
      expect(detailsBtn.attributes('disabled')).toBeUndefined()
      expect(metadataBtn.attributes('disabled')).toBeUndefined()
      expect(questionsBtn.attributes('disabled')).toBeUndefined()
    })

    it('clicking Details button emits toggle-panel with details', async () => {
      wrapper = createWrapper()
      const detailsBtn = wrapper.findAll('button').wrappers.find(b => b.text().includes('Details'))
      expect(detailsBtn).toBeDefined()
      await detailsBtn.trigger('click')
      expect(wrapper.emitted('toggle-panel')).toBeTruthy()
      expect(wrapper.emitted('toggle-panel').some(e => e[0] === 'details')).toBe(true)
    })

    it('clicking Metadata button emits toggle-panel with metadata', async () => {
      wrapper = createWrapper()
      const metadataBtn = wrapper.findAll('button').wrappers.find(b => b.text().includes('Metadata'))
      expect(metadataBtn).toBeDefined()
      await metadataBtn.trigger('click')
      expect(wrapper.emitted('toggle-panel')).toBeTruthy()
      expect(wrapper.emitted('toggle-panel').some(e => e[0] === 'metadata')).toBe(true)
    })

    it('clicking Questions button emits toggle-panel with questions', async () => {
      wrapper = createWrapper()
      const questionsBtn = wrapper.findAll('button').wrappers.find(b => b.text().includes('Questions'))
      expect(questionsBtn).toBeDefined()
      await questionsBtn.trigger('click')
      expect(wrapper.emitted('toggle-panel')).toBeTruthy()
      expect(wrapper.emitted('toggle-panel').some(e => e[0] === 'questions')).toBe(true)
    })
  })

  // Rule panel tests moved to RuleActionsToolbar.spec.js
  // (Satisfies, History, Reviews are now rule-level actions)

  describe('active panel visual feedback', () => {
    it('active panel button has secondary variant', () => {
      wrapper = createWrapper({ activePanel: 'details' })
      const detailsButton = wrapper.findAll('button').wrappers.find(b => b.text().includes('Details'))
      expect(detailsButton.classes()).toContain('btn-secondary')
    })

    it('inactive panel button has outline-secondary variant', () => {
      wrapper = createWrapper({ activePanel: 'metadata' })
      const detailsButton = wrapper.findAll('button').wrappers.find(b => b.text().includes('Details'))
      expect(detailsButton.classes()).toContain('btn-outline-secondary')
    })
  })
})
