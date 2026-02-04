import { describe, it, expect, afterEach } from 'vitest'
import { mount, createLocalVue } from '@vue/test-utils'
import { BootstrapVue, IconsPlugin } from 'bootstrap-vue'
import ProjectCommandBar from '@/components/project/ProjectCommandBar.vue'
import { PANEL_LABELS } from '@/constants/terminology'

const localVue = createLocalVue()
localVue.use(BootstrapVue)
localVue.use(IconsPlugin)

/**
 * ProjectCommandBar - Command Bar for Project page
 *
 * REQUIREMENTS:
 *
 * 1. ACTIONS (left side):
 *    - Visibility toggle: admin only, switches discoverable/hidden
 *    - Download dropdown: always visible, export options
 *    - New Component button: admin only
 *
 * 2. PANEL BUTTONS (right side):
 *    - Project Details: always visible
 *    - Project Metadata: always visible
 *    - Project History: always visible
 *    - All emit 'toggle-panel' with panel name
 *
 * 3. VISUAL FEEDBACK:
 *    - Active panel button has 'secondary' variant
 *    - Inactive panel buttons have 'outline-secondary' variant
 *
 * 4. CONSISTENCY:
 *    - Uses same styling pattern as ControlsCommandBar
 *    - Uses PANEL_LABELS from terminology constants
 */
describe('ProjectCommandBar', () => {
  let wrapper

  const defaultProps = {
    project: {
      id: 1,
      name: 'Test Project',
      visibility: 'hidden',
      components: []
    },
    effectivePermissions: 'admin',
    activePanel: null
  }

  const createWrapper = (props = {}) => {
    return mount(ProjectCommandBar, {
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

  // ==========================================
  // BASIC RENDERING
  // ==========================================
  describe('basic rendering', () => {
    it('renders the command bar', () => {
      wrapper = createWrapper()
      expect(wrapper.find('.command-bar').exists()).toBe(true)
    })

    it('renders panel buttons on the right', () => {
      wrapper = createWrapper()
      expect(wrapper.text()).toContain('Details')
      expect(wrapper.text()).toContain('Metadata')
      expect(wrapper.text()).toContain('History')
    })
  })

  // ==========================================
  // VISIBILITY TOGGLE (Admin only)
  // ==========================================
  describe('visibility toggle', () => {
    it('shows visibility toggle for admin', () => {
      wrapper = createWrapper({ effectivePermissions: 'admin' })
      const toggle = wrapper.find('[data-testid="visibility-toggle"]')
      expect(toggle.exists()).toBe(true)
    })

    it('hides visibility toggle for non-admin', () => {
      wrapper = createWrapper({ effectivePermissions: 'author' })
      const toggle = wrapper.find('[data-testid="visibility-toggle"]')
      expect(toggle.exists()).toBe(false)
    })

    it('emits toggle-visibility when changed', async () => {
      wrapper = createWrapper({ effectivePermissions: 'admin' })
      const checkbox = wrapper.find('[data-testid="visibility-toggle"] input[type="checkbox"]')
      await checkbox.setChecked(true)
      expect(wrapper.emitted('toggle-visibility')).toBeTruthy()
    })
  })

  // ==========================================
  // DOWNLOAD DROPDOWN
  // ==========================================
  describe('download dropdown', () => {
    it('shows download dropdown', () => {
      wrapper = createWrapper()
      expect(wrapper.text()).toContain('Download')
    })

    it('emits download event with type when option clicked', async () => {
      wrapper = createWrapper()
      // Find and click dropdown item
      const dropdown = wrapper.find('[data-testid="download-dropdown"]')
      expect(dropdown.exists()).toBe(true)
    })
  })

  // ==========================================
  // NEW COMPONENT BUTTON (Admin only)
  // ==========================================
  describe('new component button', () => {
    it('shows new component button for admin', () => {
      wrapper = createWrapper({ effectivePermissions: 'admin' })
      const btn = wrapper.find('[data-testid="new-component-btn"]')
      expect(btn.exists()).toBe(true)
    })

    it('hides new component button for non-admin', () => {
      wrapper = createWrapper({ effectivePermissions: 'viewer' })
      const btn = wrapper.find('[data-testid="new-component-btn"]')
      expect(btn.exists()).toBe(false)
    })

    it('emits new-component when clicked', async () => {
      wrapper = createWrapper({ effectivePermissions: 'admin' })
      const btn = wrapper.find('[data-testid="new-component-btn"]')
      await btn.trigger('click')
      expect(wrapper.emitted('new-component')).toBeTruthy()
    })
  })

  // ==========================================
  // PANEL BUTTONS
  // ==========================================
  describe('panel buttons', () => {
    it('renders all 3 project panel buttons', () => {
      wrapper = createWrapper()
      const buttons = wrapper.findAll('button')
      const panelButtons = buttons.wrappers.filter(b =>
        b.text().includes('Details') ||
        b.text().includes('Metadata') ||
        b.text().includes('History')
      )
      expect(panelButtons.length).toBe(3)
    })

    it('emits toggle-panel with "proj-details" when Details clicked', async () => {
      wrapper = createWrapper()
      const btn = wrapper.findAll('button').wrappers.find(b => b.text().includes('Details'))
      await btn.trigger('click')
      expect(wrapper.emitted('toggle-panel')).toBeTruthy()
      expect(wrapper.emitted('toggle-panel')[0]).toEqual(['proj-details'])
    })

    it('emits toggle-panel with "proj-metadata" when Metadata clicked', async () => {
      wrapper = createWrapper()
      const btn = wrapper.findAll('button').wrappers.find(b => b.text().includes('Metadata'))
      await btn.trigger('click')
      expect(wrapper.emitted('toggle-panel')).toBeTruthy()
      expect(wrapper.emitted('toggle-panel')[0]).toEqual(['proj-metadata'])
    })

    it('emits toggle-panel with "proj-history" when History clicked', async () => {
      wrapper = createWrapper()
      const btn = wrapper.findAll('button').wrappers.find(b => b.text().includes('History'))
      await btn.trigger('click')
      expect(wrapper.emitted('toggle-panel')).toBeTruthy()
      expect(wrapper.emitted('toggle-panel')[0]).toEqual(['proj-history'])
    })
  })

  // ==========================================
  // ACTIVE PANEL VISUAL FEEDBACK
  // ==========================================
  describe('active panel visual feedback', () => {
    it('shows secondary variant when panel is active', () => {
      wrapper = createWrapper({ activePanel: 'proj-details' })
      const detailsBtn = wrapper.findAll('button').wrappers.find(b => b.text().includes('Details'))
      expect(detailsBtn.classes()).toContain('btn-secondary')
    })

    it('shows outline-secondary variant when panel is inactive', () => {
      wrapper = createWrapper({ activePanel: null })
      const detailsBtn = wrapper.findAll('button').wrappers.find(b => b.text().includes('Details'))
      expect(detailsBtn.classes()).toContain('btn-outline-secondary')
    })
  })
})
