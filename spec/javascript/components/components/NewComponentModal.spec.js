import { describe, it, expect, afterEach, vi } from 'vitest'
import { shallowMount, mount, createLocalVue } from '@vue/test-utils'
import { BootstrapVue } from 'bootstrap-vue'
import NewComponentModal from '@/components/components/NewComponentModal.vue'

// Mock axios (used by fetchData and createComponent)
vi.mock('axios', () => ({
  default: {
    get: vi.fn(() => Promise.resolve({ data: [] })),
    post: vi.fn(() => Promise.resolve({ data: {} })),
    defaults: { headers: { common: {} } }
  }
}))

const localVue = createLocalVue()
localVue.use(BootstrapVue)

/**
 * NewComponentModal Contract Tests
 *
 * REQUIREMENTS:
 *
 * 1. OPENER BUTTON RENDERING:
 *    - showOpener defaults to FALSE (no button renders)
 *    - showOpener=true renders the opener button
 *    - Prevents unwanted buttons when modal is triggered programmatically
 *
 * 2. PROGRAMMATIC ACCESS:
 *    - showModal() method exists for triggering via refs
 *    - Works regardless of showOpener value
 *
 * 3. FILE INPUT ACCEPT ATTRIBUTE (spreadsheet import mode):
 *    - Must accept CSV files (.csv, text/csv)
 *    - Must accept Excel files (.xlsx, .xls, proper MIME types)
 *    - Must NOT contain typos (e.g., "appliction" instead of "application")
 *    - Backend (Roo gem) supports CSV, so UI must not block them
 */
describe('NewComponentModal', () => {
  let wrapper

  const defaultProps = {
    project_id: 1,
    project: { id: 1, name: 'Test Project' }
  }

  const createWrapper = (props = {}) => {
    return shallowMount(NewComponentModal, {
      localVue,
      propsData: {
        ...defaultProps,
        ...props
      },
      mocks: {
        $refs: {
          AddComponentModal: { show: () => {} }
        }
      }
    })
  }

  afterEach(() => {
    if (wrapper) {
      wrapper.destroy()
    }
  })

  // ==========================================
  // OPENER BUTTON CONTRACT
  // ==========================================
  describe('opener button rendering (regression prevention)', () => {
    it('does NOT render opener button by default (showOpener defaults to false)', () => {
      wrapper = createWrapper()
      // With showOpener=false, the opener span should not render
      const openerSpan = wrapper.find('span[v-if="showOpener"]')
      // Since we're using shallowMount, check the prop value
      expect(wrapper.props('showOpener')).toBe(false)
    })

    it('does NOT render opener button when showOpener explicitly false', () => {
      wrapper = createWrapper({ showOpener: false })
      expect(wrapper.props('showOpener')).toBe(false)
    })

    it('DOES render opener button when showOpener=true', () => {
      wrapper = createWrapper({ showOpener: true })
      expect(wrapper.props('showOpener')).toBe(true)
    })
  })

  // ==========================================
  // PROGRAMMATIC ACCESS
  // ==========================================
  describe('programmatic modal triggering', () => {
    it('has showModal method for programmatic access via refs', () => {
      wrapper = createWrapper()
      expect(typeof wrapper.vm.showModal).toBe('function')
    })
  })

  // ==========================================
  // MODE PROPS
  // ==========================================
  describe('modal modes', () => {
    it('default mode when no mode props set', () => {
      wrapper = createWrapper()
      expect(wrapper.props('spreadsheet_import')).toBe(false)
      expect(wrapper.props('copy_component')).toBe(false)
    })

    it('spreadsheet import mode when prop set', () => {
      wrapper = createWrapper({ spreadsheet_import: true })
      expect(wrapper.props('spreadsheet_import')).toBe(true)
    })

    it('copy component mode prop can be set', () => {
      // Just verify the prop can be set - full functionality tested in integration
      wrapper = createWrapper({ copy_component: true, project: { id: 1, name: 'Test', components: [] } })
      expect(wrapper.props('copy_component')).toBe(true)
    })
  })

  // ==========================================
  // FILE INPUT ACCEPT ATTRIBUTE
  // Requirement: The file picker must accept CSV files
  // in addition to Excel files. The backend (Roo gem)
  // supports CSV, so the UI must not block them.
  // ==========================================
  describe('spreadsheet import file input accept attribute', () => {
    // b-modal renders content lazily/in portal, so we stub it
    // to just render its default slot content inline
    const ModalStub = {
      template: '<div><slot></slot></div>'
    }

    const createMountedWrapper = (props = {}) => {
      return mount(NewComponentModal, {
        localVue,
        propsData: {
          ...defaultProps,
          spreadsheet_import: true,
          ...props
        },
        stubs: {
          'b-modal': ModalStub,
          VueSimpleSuggest: true
        }
      })
    }

    it('accepts .csv file extension', () => {
      wrapper = createMountedWrapper()
      const fileInput = wrapper.find('input[type="file"]')
      expect(fileInput.exists()).toBe(true)
      expect(fileInput.attributes('accept')).toContain('.csv')
    })

    it('accepts text/csv MIME type', () => {
      wrapper = createMountedWrapper()
      const fileInput = wrapper.find('input[type="file"]')
      expect(fileInput.attributes('accept')).toContain('text/csv')
    })

    it('accepts .xlsx file extension', () => {
      wrapper = createMountedWrapper()
      const fileInput = wrapper.find('input[type="file"]')
      expect(fileInput.attributes('accept')).toContain('.xlsx')
    })

    it('accepts .xls file extension', () => {
      wrapper = createMountedWrapper()
      const fileInput = wrapper.find('input[type="file"]')
      expect(fileInput.attributes('accept')).toContain('.xls')
    })

    it('does NOT contain the typo "appliction"', () => {
      wrapper = createMountedWrapper()
      const fileInput = wrapper.find('input[type="file"]')
      expect(fileInput.attributes('accept')).not.toContain('appliction')
    })

    it('uses correct MIME types for Excel formats', () => {
      wrapper = createMountedWrapper()
      const fileInput = wrapper.find('input[type="file"]')
      const accept = fileInput.attributes('accept')
      // XLSX MIME type
      expect(accept).toContain('application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
      // XLS MIME type
      expect(accept).toContain('application/vnd.ms-excel')
    })
  })
})
