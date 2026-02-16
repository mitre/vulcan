import { describe, it, expect } from 'vitest'
import { mount } from '@vue/test-utils'
import { localVue } from '@test/testHelper'
import FindAndReplaceMixin from '@/mixins/FindAndReplaceMixin.vue'

/**
 * FindAndReplaceMixin Tests
 *
 * REQUIREMENTS:
 *
 * 1. groupFindResults(data, find_text, matchCase, fields):
 *    - Searches across specified fields in rule data for find_text
 *    - Returns object keyed by rule.id with { rule_id, results[] }
 *    - Each result has { field, value, segments }
 *    - matchCase=true: case-sensitive matching
 *    - matchCase=false: case-insensitive matching
 *    - Skips rules where field value is null/undefined
 *
 * 2. getSegments(value, find_text, matchCase):
 *    - Splits text into segments with highlighted (match) and non-highlighted parts
 *    - Each segment: { text, highlighted: boolean }
 *    - Handles multiple matches in same string
 *    - Respects case sensitivity flag
 *
 * 3. replaceTextInRule(rule, field, segments, replace_text):
 *    - Builds new text from segments, replacing highlighted with replace_text
 *    - Sets the result on the rule using lodash _.set with FIND_AND_REPLACE_FIELDS path
 *
 * FIND_AND_REPLACE_FIELDS map:
 *   'Status Justification' -> ['status_justification']
 *   'Title'                -> ['title']
 *   'Vuln Discussion'      -> ['disa_rule_descriptions_attributes', 0, 'vuln_discussion']
 *   'Mitigations'          -> ['disa_rule_descriptions_attributes', 0, 'mitigations']
 *   'Check'                -> ['checks_attributes', 0, 'content']
 *   'Fix'                  -> ['fixtext']
 *   'Vendor Comments'      -> ['vendor_comments']
 *   'Artifact Description' -> ['artifact_description']
 */

// Minimal host component that uses the mixin
const HostComponent = {
  mixins: [FindAndReplaceMixin],
  template: '<div></div>',
}

function createWrapper() {
  return mount(HostComponent, { localVue })
}

describe('FindAndReplaceMixin', () => {
  // ==========================================
  // groupFindResults
  // ==========================================
  describe('groupFindResults', () => {
    it('finds text in a simple top-level field', () => {
      const wrapper = createWrapper()
      const data = [
        { id: 1, rule_id: 'SV-001', title: 'Install security patches' },
      ]
      const results = wrapper.vm.groupFindResults(data, 'security', false, ['Title'])

      expect(results[1]).toBeDefined()
      expect(results[1].rule_id).toBe('SV-001')
      expect(results[1].results).toHaveLength(1)
      expect(results[1].results[0].field).toBe('Title')
      expect(results[1].results[0].value).toBe('Install security patches')
    })

    it('finds text across multiple fields on the same rule', () => {
      const wrapper = createWrapper()
      const data = [
        {
          id: 1,
          rule_id: 'SV-001',
          title: 'Configure firewall settings',
          fixtext: 'Configure the firewall rules',
        },
      ]
      const results = wrapper.vm.groupFindResults(data, 'Configure', true, ['Title', 'Fix'])

      expect(results[1]).toBeDefined()
      expect(results[1].results).toHaveLength(2)
      expect(results[1].results[0].field).toBe('Title')
      expect(results[1].results[1].field).toBe('Fix')
    })

    it('finds text across multiple rules', () => {
      const wrapper = createWrapper()
      const data = [
        { id: 1, rule_id: 'SV-001', title: 'Enable logging' },
        { id: 2, rule_id: 'SV-002', title: 'Enable auditing' },
      ]
      const results = wrapper.vm.groupFindResults(data, 'Enable', true, ['Title'])

      expect(results[1]).toBeDefined()
      expect(results[2]).toBeDefined()
      expect(results[1].rule_id).toBe('SV-001')
      expect(results[2].rule_id).toBe('SV-002')
    })

    it('performs case-sensitive search when matchCase is true', () => {
      const wrapper = createWrapper()
      const data = [
        { id: 1, rule_id: 'SV-001', title: 'Enable Logging' },
      ]
      const results = wrapper.vm.groupFindResults(data, 'enable', true, ['Title'])

      // 'enable' should NOT match 'Enable' in case-sensitive mode
      expect(results[1]).toBeUndefined()
    })

    it('performs case-insensitive search when matchCase is false', () => {
      const wrapper = createWrapper()
      const data = [
        { id: 1, rule_id: 'SV-001', title: 'Enable Logging' },
      ]
      const results = wrapper.vm.groupFindResults(data, 'enable', false, ['Title'])

      expect(results[1]).toBeDefined()
      expect(results[1].results[0].value).toBe('Enable Logging')
    })

    it('skips rules where the field value is null', () => {
      const wrapper = createWrapper()
      const data = [
        { id: 1, rule_id: 'SV-001', title: null },
      ]
      const results = wrapper.vm.groupFindResults(data, 'test', false, ['Title'])

      expect(results[1]).toBeUndefined()
    })

    it('skips rules where the field value is undefined', () => {
      const wrapper = createWrapper()
      const data = [
        { id: 1, rule_id: 'SV-001' },
        // title not defined at all
      ]
      const results = wrapper.vm.groupFindResults(data, 'test', false, ['Title'])

      expect(results[1]).toBeUndefined()
    })

    it('returns empty object when no matches found', () => {
      const wrapper = createWrapper()
      const data = [
        { id: 1, rule_id: 'SV-001', title: 'Enable logging' },
      ]
      const results = wrapper.vm.groupFindResults(data, 'nonexistent', false, ['Title'])

      expect(Object.keys(results)).toHaveLength(0)
    })

    it('searches nested fields like Vulnerability Discussion', () => {
      const wrapper = createWrapper()
      const data = [
        {
          id: 1,
          rule_id: 'SV-001',
          disa_rule_descriptions_attributes: [
            { vuln_discussion: 'This is a critical vulnerability.' },
          ],
        },
      ]
      const results = wrapper.vm.groupFindResults(
        data, 'critical', false, ['Vulnerability Discussion']
      )

      expect(results[1]).toBeDefined()
      expect(results[1].results[0].field).toBe('Vulnerability Discussion')
    })

    it('searches nested Check field', () => {
      const wrapper = createWrapper()
      const data = [
        {
          id: 1,
          rule_id: 'SV-001',
          checks_attributes: [
            { content: 'Verify the setting is enabled.' },
          ],
        },
      ]
      const results = wrapper.vm.groupFindResults(data, 'Verify', true, ['Check'])

      expect(results[1]).toBeDefined()
      expect(results[1].results[0].field).toBe('Check')
    })

    it('includes segments in each result', () => {
      const wrapper = createWrapper()
      const data = [
        { id: 1, rule_id: 'SV-001', title: 'Enable the firewall' },
      ]
      const results = wrapper.vm.groupFindResults(data, 'the', false, ['Title'])

      expect(results[1].results[0].segments).toBeDefined()
      expect(Array.isArray(results[1].results[0].segments)).toBe(true)
    })

    it('accumulates results when same rule matches in multiple fields', () => {
      const wrapper = createWrapper()
      const data = [
        {
          id: 1,
          rule_id: 'SV-001',
          status_justification: 'Security requirement',
          vendor_comments: 'Security policy enforced',
        },
      ]
      const results = wrapper.vm.groupFindResults(
        data, 'Security', true, ['Status Justification', 'Vendor Comments']
      )

      expect(results[1].results).toHaveLength(2)
    })
  })

  // ==========================================
  // getSegments
  // ==========================================
  describe('getSegments', () => {
    it('returns segments with match highlighted', () => {
      const wrapper = createWrapper()
      const segments = wrapper.vm.getSegments('hello world', 'world', true)

      expect(segments).toEqual([
        { text: 'hello ', highlighted: false },
        { text: 'world', highlighted: true },
        { text: '', highlighted: false },
      ])
    })

    it('handles match at the beginning of string', () => {
      const wrapper = createWrapper()
      const segments = wrapper.vm.getSegments('hello world', 'hello', true)

      expect(segments).toEqual([
        { text: '', highlighted: false },
        { text: 'hello', highlighted: true },
        { text: ' world', highlighted: false },
      ])
    })

    it('handles multiple matches in same string', () => {
      const wrapper = createWrapper()
      const segments = wrapper.vm.getSegments('the cat and the dog', 'the', true)

      expect(segments).toEqual([
        { text: '', highlighted: false },
        { text: 'the', highlighted: true },
        { text: ' cat and ', highlighted: false },
        { text: 'the', highlighted: true },
        { text: ' dog', highlighted: false },
      ])
    })

    it('handles case-insensitive matching', () => {
      const wrapper = createWrapper()
      const segments = wrapper.vm.getSegments('Hello hello HELLO', 'hello', false)

      // All three "hello" variants should be highlighted
      expect(segments).toHaveLength(7) // 3 matches + 4 non-matches (incl. empty strings)
      const highlighted = segments.filter((s) => s.highlighted)
      expect(highlighted).toHaveLength(3)
    })

    it('preserves original case in segment text during case-insensitive match', () => {
      const wrapper = createWrapper()
      const segments = wrapper.vm.getSegments('Hello World', 'hello', false)

      const match = segments.find((s) => s.highlighted)
      expect(match.text).toBe('Hello') // Original case preserved
    })

    it('returns full text as non-highlighted when no match', () => {
      const wrapper = createWrapper()
      const segments = wrapper.vm.getSegments('hello world', 'xyz', true)

      expect(segments).toEqual([
        { text: 'hello world', highlighted: false },
      ])
    })

    it('handles adjacent/overlapping search terms', () => {
      const wrapper = createWrapper()
      // "aa" appears at index 0, and also at index 1 — but indexOf with previousIndex = currentIndex + 1
      // means index 0 match, then search from 1 finds index 1
      const segments = wrapper.vm.getSegments('aaa', 'aa', true)

      // First match at 0: "aa", then search from 1: finds "aa" at index 1
      expect(segments).toHaveLength(5) // empty, "aa", empty, "aa", trailing
      const highlighted = segments.filter((s) => s.highlighted)
      expect(highlighted).toHaveLength(2)
    })
  })

  // ==========================================
  // replaceTextInRule
  // ==========================================
  describe('replaceTextInRule', () => {
    it('replaces highlighted segments with replace_text on simple field', () => {
      const wrapper = createWrapper()
      const rule = { title: 'Enable the firewall' }
      const segments = [
        { text: 'Enable ', highlighted: false },
        { text: 'the', highlighted: true },
        { text: ' firewall', highlighted: false },
      ]

      wrapper.vm.replaceTextInRule(rule, 'Title', segments, 'a')
      expect(rule.title).toBe('Enable a firewall')
    })

    it('replaces highlighted segments on nested field', () => {
      const wrapper = createWrapper()
      const rule = {
        disa_rule_descriptions_attributes: [
          { vuln_discussion: 'original text' },
        ],
      }
      const segments = [
        { text: '', highlighted: false },
        { text: 'original', highlighted: true },
        { text: ' text', highlighted: false },
      ]

      wrapper.vm.replaceTextInRule(rule, 'Vulnerability Discussion', segments, 'new')
      expect(rule.disa_rule_descriptions_attributes[0].vuln_discussion).toBe('new text')
    })

    it('replaces multiple highlighted segments', () => {
      const wrapper = createWrapper()
      const rule = { fixtext: 'set value to true and set flag to true' }
      const segments = [
        { text: 'set value to ', highlighted: false },
        { text: 'true', highlighted: true },
        { text: ' and set flag to ', highlighted: false },
        { text: 'true', highlighted: true },
        { text: '', highlighted: false },
      ]

      wrapper.vm.replaceTextInRule(rule, 'Fix', segments, 'false')
      expect(rule.fixtext).toBe('set value to false and set flag to false')
    })

    it('handles replacement with empty string (delete)', () => {
      const wrapper = createWrapper()
      const rule = { vendor_comments: 'remove THIS word' }
      const segments = [
        { text: 'remove ', highlighted: false },
        { text: 'THIS ', highlighted: true },
        { text: 'word', highlighted: false },
      ]

      wrapper.vm.replaceTextInRule(rule, 'Vendor Comments', segments, '')
      expect(rule.vendor_comments).toBe('remove word')
    })

    it('sets value on Check field (nested checks_attributes)', () => {
      const wrapper = createWrapper()
      const rule = {
        checks_attributes: [
          { content: 'old check' },
        ],
      }
      const segments = [
        { text: '', highlighted: false },
        { text: 'old', highlighted: true },
        { text: ' check', highlighted: false },
      ]

      wrapper.vm.replaceTextInRule(rule, 'Check', segments, 'new')
      expect(rule.checks_attributes[0].content).toBe('new check')
    })
  })
})
