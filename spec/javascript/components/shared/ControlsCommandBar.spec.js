import { describe, it, expect, afterEach } from 'vitest'
import { mount, createLocalVue } from '@vue/test-utils'
import { BootstrapVue, IconsPlugin } from 'bootstrap-vue'
import ControlsCommandBar from '@/components/shared/ControlsCommandBar.vue'
import { PANEL_LABELS } from '@/constants/terminology'

const localVue = createLocalVue()
localVue.use(BootstrapVue)
localVue.use(IconsPlugin)

/**
 * ControlsCommandBar - Unified Command Bar for VIEW and EDIT pages
 *
 * REQUIREMENTS:
 *
 * 1. MODE BEHAVIOR (controlled by readOnly prop):
 *    - VIEW mode (readOnly=true): Shows "Edit" button linking to /edit
 *    - EDIT mode (readOnly=false): Shows "View" button linking to /view
 *
 * 2. ACTIONS (left side):
 *    - Edit/View button: toggles based on mode, requires author+ permission
 *    - Release button: admin only, disabled when not releasable
 *    - Members button: always visible, opens members modal
 *    - Advanced Fields toggle: admin only
 *
 * 3. COMPONENT PANELS (right side):
 *    - Details, Metadata, Questions, Comp History, Comp Reviews
 *    - Always enabled (component-level info doesn't depend on rule)
 *    - Toggle on click, emit 'toggle-panel' event
 *
 * 4. RULE PANELS: Moved to RuleActionsToolbar (rule-level, not component-level)
 *
 * 5. RULE CONTEXT BAR (shown when rule selected):
 *    - Displays rule ID with prefix, version
 *    - Status icons: lock, review, changes requested
 *    - Last editor info
 *    - NOTE: Related button moved to RuleActionsToolbar
 *
 * 6. VISUAL FEEDBACK:
 *    - Active panel button: 'secondary' variant
 *    - Inactive panel button: 'outline-secondary' variant
 */
describe('ControlsCommandBar', () => {
  let wrapper

  const defaultComponent = {
    id: 41,
    name: 'Test Component',
    prefix: 'TEST',
    released: false,
    releasable: true,
    advanced_fields: false
  }

  const defaultRule = {
    id: 1,
    rule_id: '00001',
    version: 'SV-12345r1',
    component_id: 41,
    status: 'Not Yet Determined',
    locked: false,
    review_requestor_id: null,
    changes_requested: false,
    histories: [{ name: 'John Doe', created_at: '2024-01-15' }],
    updated_at: '2024-01-15T10:00:00Z'
  }

  const createWrapper = (props = {}) => {
    return mount(ControlsCommandBar, {
      localVue,
      propsData: {
        component: defaultComponent,
        selectedRule: null,
        effectivePermissions: 'admin',
        activePanel: null,
        readOnly: true,
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

  // ==========================================
  // MODE BEHAVIOR (VIEW vs EDIT)
  // ==========================================
  describe('mode behavior', () => {
    describe('VIEW mode (readOnly=true)', () => {
      it('shows Edit button', () => {
        wrapper = createWrapper({ readOnly: true, effectivePermissions: 'admin' })
        expect(wrapper.text()).toContain('Edit')
        expect(wrapper.text()).not.toContain('View')
      })

      it('Edit button links to edit page', () => {
        wrapper = createWrapper({ readOnly: true })
        const editLink = wrapper.find('a[href="/components/41/edit"]')
        expect(editLink.exists()).toBe(true)
      })
    })

    describe('EDIT mode (readOnly=false)', () => {
      it('shows View button', () => {
        wrapper = createWrapper({ readOnly: false, effectivePermissions: 'admin' })
        expect(wrapper.text()).toContain('View')
      })

      it('View button links to view page', () => {
        wrapper = createWrapper({ readOnly: false })
        const viewLink = wrapper.find('a[href="/components/41"]')
        expect(viewLink.exists()).toBe(true)
      })
    })
  })

  // ==========================================
  // ACTIONS
  // ==========================================
  describe('Edit/View button permissions', () => {
    it('shows Edit button for admin', () => {
      wrapper = createWrapper({ effectivePermissions: 'admin', readOnly: true })
      expect(wrapper.text()).toContain('Edit')
    })

    it('shows Edit button for author', () => {
      wrapper = createWrapper({ effectivePermissions: 'author', readOnly: true })
      expect(wrapper.text()).toContain('Edit')
    })

    it('hides Edit button for viewer', () => {
      wrapper = createWrapper({ effectivePermissions: 'viewer', readOnly: true })
      const buttons = wrapper.findAll('a.btn')
      const editButton = buttons.wrappers.find(b => b.text().includes('Edit'))
      expect(editButton).toBeUndefined()
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
        component: { ...defaultComponent, releasable: false }
      })
      const releaseButton = wrapper.findAll('button').wrappers.find(b => b.text().includes('Release'))
      expect(releaseButton.attributes('disabled')).toBe('disabled')
    })

    it('disables Release button when component already released', () => {
      wrapper = createWrapper({
        component: { ...defaultComponent, released: true }
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

    it('emits toggle-advanced-fields when changed', async () => {
      wrapper = createWrapper({ effectivePermissions: 'admin' })
      const checkbox = wrapper.find('input[type="checkbox"]')
      await checkbox.setChecked(true)
      expect(wrapper.emitted('toggle-advanced-fields')).toBeTruthy()
    })
  })

  // ==========================================
  // COMPONENT PANELS
  // ==========================================
  describe('component panel buttons', () => {
    it('renders all 5 component panel buttons with correct labels from terminology', () => {
      wrapper = createWrapper()
      expect(wrapper.text()).toContain(PANEL_LABELS.details)
      expect(wrapper.text()).toContain(PANEL_LABELS.metadata)
      expect(wrapper.text()).toContain(PANEL_LABELS.questions)
      expect(wrapper.text()).toContain(PANEL_LABELS.compHistory)
      expect(wrapper.text()).toContain(PANEL_LABELS.compReviews)
    })

    it('component panel buttons are NOT disabled when no rule selected', () => {
      wrapper = createWrapper({ selectedRule: null })
      const allButtons = wrapper.findAll('button')

      const detailsBtn = allButtons.wrappers.find(b => b.text().includes('Details'))
      const metadataBtn = allButtons.wrappers.find(b => b.text().includes('Metadata'))
      const questionsBtn = allButtons.wrappers.find(b => b.text().includes('Questions'))

      expect(detailsBtn).toBeDefined()
      expect(metadataBtn).toBeDefined()
      expect(questionsBtn).toBeDefined()

      expect(detailsBtn.attributes('disabled')).toBeUndefined()
      expect(metadataBtn.attributes('disabled')).toBeUndefined()
      expect(questionsBtn.attributes('disabled')).toBeUndefined()
    })

    it('clicking Details button emits toggle-panel with details', async () => {
      wrapper = createWrapper()
      const detailsBtn = wrapper.findAll('button').wrappers.find(b => b.text().includes('Details'))
      await detailsBtn.trigger('click')
      expect(wrapper.emitted('toggle-panel')).toBeTruthy()
      expect(wrapper.emitted('toggle-panel').some(e => e[0] === 'details')).toBe(true)
    })

    it('clicking Metadata button emits toggle-panel with metadata', async () => {
      wrapper = createWrapper()
      const metadataBtn = wrapper.findAll('button').wrappers.find(b => b.text().includes('Metadata'))
      await metadataBtn.trigger('click')
      expect(wrapper.emitted('toggle-panel')).toBeTruthy()
      expect(wrapper.emitted('toggle-panel').some(e => e[0] === 'metadata')).toBe(true)
    })

    it('clicking Questions button emits toggle-panel with questions', async () => {
      wrapper = createWrapper()
      const questionsBtn = wrapper.findAll('button').wrappers.find(b => b.text().includes('Questions'))
      await questionsBtn.trigger('click')
      expect(wrapper.emitted('toggle-panel')).toBeTruthy()
      expect(wrapper.emitted('toggle-panel').some(e => e[0] === 'questions')).toBe(true)
    })
  })

  // ==========================================
  // RULE PANELS - Moved to RuleActionsToolbar
  // ==========================================
  // Rule-level panels (Satisfies, History, Reviews) are now in RuleActionsToolbar
  // because they operate on the selected rule, not the component.
  // See spec/javascript/components/rules/RuleActionsToolbar.spec.js

  // ==========================================
  // RULE CONTEXT BAR
  // ==========================================
  describe('rule context bar', () => {
    describe('when no rule selected', () => {
      it('does not render rule context bar', () => {
        wrapper = createWrapper({ selectedRule: null })
        expect(wrapper.find('.rule-context-bar').exists()).toBe(false)
      })
    })

    describe('when rule is selected', () => {
      it('renders rule context bar', () => {
        wrapper = createWrapper({ selectedRule: defaultRule })
        expect(wrapper.find('.rule-context-bar').exists()).toBe(true)
      })

      it('displays rule ID with component prefix', () => {
        wrapper = createWrapper({ selectedRule: defaultRule })
        expect(wrapper.text()).toContain('TEST-00001')
      })

      it('displays rule version', () => {
        wrapper = createWrapper({ selectedRule: defaultRule })
        expect(wrapper.text()).toContain('SV-12345r1')
      })

      it('shows lock icon when rule is locked', () => {
        wrapper = createWrapper({
          selectedRule: { ...defaultRule, locked: true }
        })
        // Lock icon has text-warning class in the rule context bar
        const ruleContextBar = wrapper.find('.rule-context-bar')
        expect(ruleContextBar.find('.text-warning').exists()).toBe(true)
      })

      it('shows review icon when rule is under review', () => {
        wrapper = createWrapper({
          selectedRule: { ...defaultRule, review_requestor_id: 123 }
        })
        // Review icon has text-info class in the rule context bar
        const ruleContextBar = wrapper.find('.rule-context-bar')
        expect(ruleContextBar.find('.text-info').exists()).toBe(true)
      })

      it('shows warning icon when changes are requested', () => {
        wrapper = createWrapper({
          selectedRule: { ...defaultRule, changes_requested: true }
        })
        // Warning icon has text-danger class in the rule context bar
        const ruleContextBar = wrapper.find('.rule-context-bar')
        expect(ruleContextBar.find('.text-danger').exists()).toBe(true)
      })

      it('shows last editor name', () => {
        wrapper = createWrapper({ selectedRule: defaultRule })
        expect(wrapper.text()).toContain('John Doe')
      })

      // NOTE: Related button moved to RuleActionsToolbar as a per-rule action
    })
  })

  // ==========================================
  // VISUAL FEEDBACK
  // ==========================================
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
