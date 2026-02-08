import { describe, it, expect, vi, beforeEach } from 'vitest'
import { shallowMount, createLocalVue } from '@vue/test-utils'
import Rules from '@/components/rules/Rules.vue'
import BootstrapVue from 'bootstrap-vue'
import axios from 'axios'

vi.mock('axios')

const localVue = createLocalVue()
localVue.use(BootstrapVue)

describe('Rules', () => {
  const createWrapper = (rulesOverrides = []) => {
    const defaultRule = {
      id: 1,
      component_id: 100,
      rule_id: '000010',
      version: 'APSC-DV-000010',
      status: 'Not Yet Determined',
      satisfied_by: [],
      satisfies: [],
      disa_rule_descriptions_attributes: [{ vuln_discussion: '' }],
      checks_attributes: [{ content: '' }],
      rule_descriptions_attributes: []
    }

    const rules = rulesOverrides.length > 0 ? rulesOverrides : [defaultRule]

    return shallowMount(Rules, {
      localVue,
      propsData: {
        effective_permissions: 'admin',
        current_user_id: 1,
        project: { id: 1, name: 'Test Project' },
        component: { id: 100, name: 'Test Component', version: '1', release: '1' },
        rules: rules,
        statuses: ['Not Yet Determined', 'Applicable - Configurable'],
      }
    })
  }

  describe('addSatisfiedRule', () => {
    beforeEach(() => {
      vi.clearAllMocks()
    })

    it('preserves unsaved local changes when adding satisfaction', async () => {
      // Setup: Create two rules - one will satisfy the other
      const rule1 = {
        id: 1,
        component_id: 100,
        rule_id: '000010',
        version: 'APSC-DV-000010',
        status: 'Not Yet Determined',
        satisfied_by: [],
        satisfies: [],
        disa_rule_descriptions_attributes: [{ vuln_discussion: '' }],
        checks_attributes: [{ content: '' }],
        rule_descriptions_attributes: []
      }
      const rule2 = {
        id: 2,
        component_id: 100,
        rule_id: '000020',
        version: 'APSC-DV-000020',
        status: 'Applicable - Configurable',
        satisfied_by: [],
        satisfies: [],
        disa_rule_descriptions_attributes: [{ vuln_discussion: '' }],
        checks_attributes: [{ content: '' }],
        rule_descriptions_attributes: []
      }

      const wrapper = createWrapper([rule1, rule2])

      // Simulate local status change (user changes status but hasn't saved yet)
      wrapper.vm.reactiveRules[0].status = 'Applicable - Configurable'

      // Mock successful satisfaction creation
      axios.post.mockResolvedValue({
        data: { toast: 'Successfully marked as satisfied' }
      })

      // Mock the refresh that returns the OLD server data (status still 'Not Yet Determined')
      axios.get.mockResolvedValue({
        data: {
          id: 1,
          component_id: 100,
          rule_id: '000010',
          version: 'APSC-DV-000010',
          status: 'Not Yet Determined', // Server still has old status
          satisfied_by: [rule2], // But now has the satisfaction
          satisfies: [],
          disa_rule_descriptions_attributes: [{ vuln_discussion: '' }],
          checks_attributes: [{ content: '' }],
          rule_descriptions_attributes: []
        }
      })

      // Act: Add satisfaction (rule1 is satisfied by rule2)
      await wrapper.vm.addSatisfiedRule(1, 2)

      // Wait for promises to resolve
      await wrapper.vm.$nextTick()
      await new Promise(resolve => setTimeout(resolve, 10))

      // Assert: Local status change should be PRESERVED
      // This is the key assertion - the bug is that this currently fails
      // because refreshRule overwrites local changes with server data
      expect(wrapper.vm.reactiveRules[0].status).toBe('Applicable - Configurable')

      // Also verify the satisfaction was added
      expect(wrapper.vm.reactiveRules[0].satisfied_by.length).toBe(1)
    })

    it('updates satisfaction arrays without full rule refresh', async () => {
      const rule1 = {
        id: 1,
        component_id: 100,
        rule_id: '000010',
        version: 'APSC-DV-000010',
        status: 'Applicable - Configurable',
        title: 'Local unsaved title change', // Local change
        satisfied_by: [],
        satisfies: [],
        disa_rule_descriptions_attributes: [{ vuln_discussion: '' }],
        checks_attributes: [{ content: '' }],
        rule_descriptions_attributes: []
      }
      const rule2 = {
        id: 2,
        component_id: 100,
        rule_id: '000020',
        version: 'APSC-DV-000020',
        status: 'Applicable - Configurable',
        satisfied_by: [],
        satisfies: [],
        disa_rule_descriptions_attributes: [{ vuln_discussion: '' }],
        checks_attributes: [{ content: '' }],
        rule_descriptions_attributes: []
      }

      const wrapper = createWrapper([rule1, rule2])

      // Mock successful satisfaction creation that returns updated relationship data
      axios.post.mockResolvedValue({
        data: {
          toast: 'Successfully marked as satisfied',
          rule: { ...rule1, satisfied_by: [rule2] },
          satisfied_by_rule: { ...rule2, satisfies: [rule1] }
        }
      })

      // Call addSatisfiedRule
      await wrapper.vm.addSatisfiedRule(1, 2)
      await wrapper.vm.$nextTick()

      // Local changes should be preserved
      expect(wrapper.vm.reactiveRules[0].title).toBe('Local unsaved title change')
    })
  })

  describe('removeSatisfiedRule', () => {
    beforeEach(() => {
      vi.clearAllMocks()
    })

    it('preserves unsaved local changes when removing satisfaction', async () => {
      // Setup: rule1 is satisfied by rule2
      const rule1 = {
        id: 1,
        component_id: 100,
        rule_id: '000010',
        version: 'APSC-DV-000010',
        status: 'Applicable - Configurable',
        satisfied_by: [{ id: 2, rule_id: '000020', version: 'APSC-DV-000020' }],
        satisfies: [],
        disa_rule_descriptions_attributes: [{ vuln_discussion: '' }],
        checks_attributes: [{ content: '' }],
        rule_descriptions_attributes: []
      }
      const rule2 = {
        id: 2,
        component_id: 100,
        rule_id: '000020',
        version: 'APSC-DV-000020',
        status: 'Applicable - Configurable',
        satisfied_by: [],
        satisfies: [{ id: 1, rule_id: '000010', version: 'APSC-DV-000010' }],
        disa_rule_descriptions_attributes: [{ vuln_discussion: '' }],
        checks_attributes: [{ content: '' }],
        rule_descriptions_attributes: []
      }

      const wrapper = createWrapper([rule1, rule2])

      // Simulate local status change (user changes status but hasn't saved yet)
      wrapper.vm.reactiveRules[0].status = 'Not Applicable'

      // Mock successful satisfaction removal
      axios.delete.mockResolvedValue({
        data: { toast: 'Successfully removed satisfaction' }
      })

      // Act: Remove satisfaction
      await wrapper.vm.removeSatisfiedRule(1, 2)
      await wrapper.vm.$nextTick()

      // Assert: Local status change should be PRESERVED
      expect(wrapper.vm.reactiveRules[0].status).toBe('Not Applicable')

      // Also verify the satisfaction was removed
      expect(wrapper.vm.reactiveRules[0].satisfied_by.length).toBe(0)
      expect(wrapper.vm.reactiveRules[1].satisfies.length).toBe(0)
    })
  })
})
