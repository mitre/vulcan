import { mount } from '@vue/test-utils'
import { describe, expect, it } from 'vitest'
import BulkActions from './BulkActions.vue'

describe('bulkActions', () => {
  const createRule = (id: number, overrides = {}) => ({
    id,
    rule_id: `SRG-APP-${String(id).padStart(6, '0')}`,
    version: 'V1R1',
    title: `Rule ${id}`,
    status: 'Applicable - Configurable' as const,
    rule_severity: 'medium' as const,
    locked: false,
    is_merged: false,
    satisfies_count: 0,
    ...overrides,
  })

  const defaultProps = {
    selectedRules: [createRule(1), createRule(2)],
    visibleRules: [createRule(1), createRule(2), createRule(3)],
    canEdit: true,
  }

  describe('rendering', () => {
    it('does not render when no rules selected', () => {
      const wrapper = mount(BulkActions, {
        props: {
          ...defaultProps,
          selectedRules: [],
        },
      })

      expect(wrapper.find('.bulk-actions').exists()).toBe(false)
    })

    it('renders when rules are selected', () => {
      const wrapper = mount(BulkActions, {
        props: defaultProps,
      })

      expect(wrapper.find('.bulk-actions').exists()).toBe(true)
    })

    it('shows selection count', () => {
      const wrapper = mount(BulkActions, {
        props: defaultProps,
      })

      expect(wrapper.text()).toContain('2 selected')
    })

    it('shows Select All button when not all selected', () => {
      const wrapper = mount(BulkActions, {
        props: defaultProps,
      })

      const selectAllBtn = wrapper.findAll('button').find(b => b.text().includes('Select All'))
      expect(selectAllBtn).toBeDefined()
    })

    it('hides Select All button when all selected', () => {
      const wrapper = mount(BulkActions, {
        props: {
          ...defaultProps,
          selectedRules: defaultProps.visibleRules,
        },
      })

      const selectAllBtn = wrapper.findAll('button').find(b => b.text().includes('Select All'))
      expect(selectAllBtn).toBeUndefined()
    })

    it('shows Clear button', () => {
      const wrapper = mount(BulkActions, {
        props: defaultProps,
      })

      const clearBtn = wrapper.findAll('button').find(b => b.text().includes('Clear'))
      expect(clearBtn).toBeDefined()
    })
  })

  describe('satisfaction actions', () => {
    it('shows satisfaction buttons when canEdit is true', () => {
      const wrapper = mount(BulkActions, {
        props: defaultProps,
      })

      const markBtn = wrapper.findAll('button').find(b => b.text().includes('Mark Satisfied By'))
      const removeBtn = wrapper.findAll('button').find(b => b.text().includes('Remove Satisfaction'))

      expect(markBtn).toBeDefined()
      expect(removeBtn).toBeDefined()
    })

    it('hides satisfaction buttons when canEdit is false', () => {
      const wrapper = mount(BulkActions, {
        props: {
          ...defaultProps,
          canEdit: false,
        },
      })

      const markBtn = wrapper.findAll('button').find(b => b.text().includes('Mark Satisfied By'))
      const removeBtn = wrapper.findAll('button').find(b => b.text().includes('Remove Satisfaction'))

      expect(markBtn).toBeUndefined()
      expect(removeBtn).toBeUndefined()
    })

    it('enables Mark Satisfied By when rules are not merged', () => {
      const wrapper = mount(BulkActions, {
        props: defaultProps,
      })

      const markBtn = wrapper.findAll('button').find(b => b.text().includes('Mark Satisfied By'))!
      expect(markBtn.attributes('disabled')).toBeUndefined()
    })

    it('disables Mark Satisfied By when all selected rules are merged', () => {
      const wrapper = mount(BulkActions, {
        props: {
          ...defaultProps,
          selectedRules: [
            createRule(1, { is_merged: true }),
            createRule(2, { is_merged: true }),
          ],
        },
      })

      const markBtn = wrapper.findAll('button').find(b => b.text().includes('Mark Satisfied By'))!
      expect(markBtn.attributes('disabled')).toBeDefined()
    })

    it('disables Remove Satisfaction when no selected rules have satisfaction', () => {
      const wrapper = mount(BulkActions, {
        props: {
          ...defaultProps,
          selectedRules: [
            createRule(1, { is_merged: false, satisfies_count: 0 }),
            createRule(2, { is_merged: false, satisfies_count: 0 }),
          ],
        },
      })

      const removeBtn = wrapper.findAll('button').find(b => b.text().includes('Remove Satisfaction'))!
      expect(removeBtn.attributes('disabled')).toBeDefined()
    })

    it('enables Remove Satisfaction when some selected rules have satisfaction', () => {
      const wrapper = mount(BulkActions, {
        props: {
          ...defaultProps,
          selectedRules: [
            createRule(1, { is_merged: true }),
            createRule(2, { satisfies_count: 2 }),
          ],
        },
      })

      const removeBtn = wrapper.findAll('button').find(b => b.text().includes('Remove Satisfaction'))!
      expect(removeBtn.attributes('disabled')).toBeUndefined()
    })
  })

  describe('events', () => {
    it('emits clearSelection when Clear button clicked', async () => {
      const wrapper = mount(BulkActions, {
        props: defaultProps,
      })

      const clearBtn = wrapper.findAll('button').find(b => b.text().includes('Clear'))!
      await clearBtn.trigger('click')

      expect(wrapper.emitted('clearSelection')).toBeTruthy()
    })

    it('emits selectAll when Select All button clicked', async () => {
      const wrapper = mount(BulkActions, {
        props: defaultProps,
      })

      const selectAllBtn = wrapper.findAll('button').find(b => b.text().includes('Select All'))!
      await selectAllBtn.trigger('click')

      expect(wrapper.emitted('selectAll')).toBeTruthy()
    })

    it('emits markSatisfiedBy when button clicked', async () => {
      const wrapper = mount(BulkActions, {
        props: defaultProps,
      })

      const markBtn = wrapper.findAll('button').find(b => b.text().includes('Mark Satisfied By'))!
      await markBtn.trigger('click')

      expect(wrapper.emitted('markSatisfiedBy')).toBeTruthy()
    })

    it('emits removeSatisfaction when button clicked', async () => {
      const wrapper = mount(BulkActions, {
        props: {
          ...defaultProps,
          selectedRules: [createRule(1, { is_merged: true })],
        },
      })

      const removeBtn = wrapper.findAll('button').find(b => b.text().includes('Remove Satisfaction'))!
      await removeBtn.trigger('click')

      expect(wrapper.emitted('removeSatisfaction')).toBeTruthy()
    })
  })

  describe('selection state', () => {
    it('shows correct count for single selection', () => {
      const wrapper = mount(BulkActions, {
        props: {
          ...defaultProps,
          selectedRules: [createRule(1)],
        },
      })

      expect(wrapper.text()).toContain('1 selected')
    })

    it('shows correct count for multiple selections', () => {
      const wrapper = mount(BulkActions, {
        props: {
          ...defaultProps,
          selectedRules: [createRule(1), createRule(2), createRule(3), createRule(4), createRule(5)],
        },
      })

      expect(wrapper.text()).toContain('5 selected')
    })
  })
})
