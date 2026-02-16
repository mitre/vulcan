import { describe, it, expect } from 'vitest'
import { mount } from '@vue/test-utils'
import { localVue } from '@test/testHelper'
import HumanizedTypesMixIn from '@/mixins/HumanizedTypesMixIn.vue'

/**
 * HumanizedTypesMixIn Tests
 *
 * REQUIREMENTS:
 *
 * 1. humanizedType(type) method:
 *    - Looks up a machine-readable type string in the humanizedTypes map
 *    - Returns the human-readable display name if found
 *    - Returns the input string unchanged if not in the map
 *
 * 2. humanizedTypes data:
 *    - Provides mapping from internal field names to display names
 *    - Used in audit history, diff views, and review displays
 *    - Covers all rule, description, and check field names
 */

const HostComponent = {
  mixins: [HumanizedTypesMixIn],
  template: '<div></div>',
}

function createWrapper() {
  return mount(HostComponent, { localVue })
}

describe('HumanizedTypesMixIn', () => {
  // ==========================================
  // humanizedType METHOD — known mappings
  // ==========================================
  describe('humanizedType — known types', () => {
    it('returns "Vulnerability Discussion" for "vuln_discussion"', () => {
      const wrapper = createWrapper()
      expect(wrapper.vm.humanizedType('vuln_discussion')).toBe('Vulnerability Discussion')
    })

    it('returns "Status Justification" for "status_justification"', () => {
      const wrapper = createWrapper()
      expect(wrapper.vm.humanizedType('status_justification')).toBe('Status Justification')
    })

    it('returns "Fix Text" for "fixtext"', () => {
      const wrapper = createWrapper()
      expect(wrapper.vm.humanizedType('fixtext')).toBe('Fix Text')
    })

    it('returns "Check" for "content"', () => {
      const wrapper = createWrapper()
      expect(wrapper.vm.humanizedType('content')).toBe('Check')
    })

    it('returns "Vendor Comments" for "vendor_comments"', () => {
      const wrapper = createWrapper()
      expect(wrapper.vm.humanizedType('vendor_comments')).toBe('Vendor Comments')
    })

    it('returns "Artifact Description" for "artifact_description"', () => {
      const wrapper = createWrapper()
      expect(wrapper.vm.humanizedType('artifact_description')).toBe('Artifact Description')
    })

    it('returns "Rule" for "BaseRule"', () => {
      const wrapper = createWrapper()
      expect(wrapper.vm.humanizedType('BaseRule')).toBe('Rule')
    })

    it('returns "Rule Description" for "DisaRuleDescription"', () => {
      const wrapper = createWrapper()
      expect(wrapper.vm.humanizedType('DisaRuleDescription')).toBe('Rule Description')
    })

    it('returns "Rule Severity" for "rule_severity"', () => {
      const wrapper = createWrapper()
      expect(wrapper.vm.humanizedType('rule_severity')).toBe('Rule Severity')
    })

    it('returns "Title" for "title"', () => {
      const wrapper = createWrapper()
      expect(wrapper.vm.humanizedType('title')).toBe('Title')
    })

    it('returns "Status" for "status"', () => {
      const wrapper = createWrapper()
      expect(wrapper.vm.humanizedType('status')).toBe('Status')
    })

    it('returns "Mitigations" for "mitigations"', () => {
      const wrapper = createWrapper()
      expect(wrapper.vm.humanizedType('mitigations')).toBe('Mitigations')
    })

    it('returns "Documentable" for "documentable"', () => {
      const wrapper = createWrapper()
      expect(wrapper.vm.humanizedType('documentable')).toBe('Documentable')
    })

    it('returns "Locked" for "locked"', () => {
      const wrapper = createWrapper()
      expect(wrapper.vm.humanizedType('locked')).toBe('Locked')
    })
  })

  // ==========================================
  // humanizedType METHOD — unknown types
  // ==========================================
  describe('humanizedType — unknown types', () => {
    it('returns input string unchanged for unknown type', () => {
      const wrapper = createWrapper()
      expect(wrapper.vm.humanizedType('some_unknown_field')).toBe('some_unknown_field')
    })

    it('returns empty string for empty string input', () => {
      const wrapper = createWrapper()
      expect(wrapper.vm.humanizedType('')).toBe('')
    })

    it('returns the exact input for a type not in the map', () => {
      const wrapper = createWrapper()
      const input = 'completely_new_field'
      expect(wrapper.vm.humanizedType(input)).toBe(input)
    })
  })

  // ==========================================
  // humanizedTypes DATA — completeness
  // ==========================================
  describe('humanizedTypes data object', () => {
    it('has all expected keys', () => {
      const wrapper = createWrapper()
      const expectedKeys = [
        'AdditionalAnswer',
        'AdditionalQuestion',
        'BaseRule',
        'RuleDescription',
        'DisaRuleDescription',
        'created_at',
        'updated_at',
        'project_id',
        'status_justification',
        'artifact_description',
        'vendor_comments',
        'rule_id',
        'rule_severity',
        'rule_weight',
        'ident_system',
        'fixtext',
        'fixtext_fixref',
        'fix_id',
        'vuln_discussion',
        'false_positives',
        'false_negatives',
        'severity_override_guidance',
        'potential_impacts',
        'third_party_tools',
        'mitigation_control',
        'ia_controls',
        'content_ref_name',
        'content_ref_href',
        'system',
        'content',
        'documentable',
        'mitigations',
        'locked',
        'status',
        'title',
        'ident',
      ]

      expectedKeys.forEach((key) => {
        expect(wrapper.vm.humanizedTypes).toHaveProperty(key)
      })
    })

    it('maps "Additional Answer" for AdditionalAnswer', () => {
      const wrapper = createWrapper()
      expect(wrapper.vm.humanizedTypes.AdditionalAnswer).toBe('Additional Answer')
    })

    it('maps "Additional Question" for AdditionalQuestion', () => {
      const wrapper = createWrapper()
      expect(wrapper.vm.humanizedTypes.AdditionalQuestion).toBe('Additional Question')
    })
  })
})
