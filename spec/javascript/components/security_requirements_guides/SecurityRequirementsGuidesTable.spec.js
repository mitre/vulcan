import { describe, it, expect, beforeEach, afterEach } from 'vitest'
import { shallowMount } from '@vue/test-utils'
import { localVue } from '@test/testHelper'
import SecurityRequirementsGuidesTable from '@/components/security_requirements_guides/SecurityRequirementsGuidesTable.vue'

/**
 * SecurityRequirementsGuidesTable Component Tests
 *
 * REQUIREMENTS:
 *
 * 1. SORTABLE COLUMNS:
 *    - All main columns should be sortable (name/ID, title, version, date)
 *    - Component type: Name, Based On, Version, Updated should be sortable
 *    - SRG type: SRG ID, Title, Version, Release Date should be sortable
 *    - STIG type: STIG ID, Title, Version, Benchmark Date should be sortable
 *
 * 2. SEARCH:
 *    - Filters items by search term
 *    - Case-insensitive
 *
 * 3. PAGINATION:
 *    - Shows 10 items per page by default
 *    - Pagination controls visible when needed
 */
describe('SecurityRequirementsGuidesTable', () => {
  let wrapper

  const sampleSRGs = [
    { id: 1, srg_id: 'SRG-001', title: 'General Purpose OS SRG', version: 'V3R3', release_date: '2025-01-15' },
    { id: 2, srg_id: 'SRG-002', title: 'Web Server SRG', version: 'V4R4', release_date: '2025-02-20' },
  ]

  const sampleSTIGs = [
    { id: 1, stig_id: 'RHEL-9', title: 'Red Hat Enterprise Linux 9', version: 'V2R7', benchmark_date: '2025-03-10' },
    { id: 2, stig_id: 'WIN-2025', title: 'Windows Server 2025', version: 'V1R3', benchmark_date: '2025-04-05' },
  ]

  const sampleComponents = [
    { id: 1, name: 'Photon OS 3', based_on_title: 'GPOS SRG', version: 1, release: 1, updated_at: '2025-05-01', rules_count: 191, severity_counts: { high: 0, medium: 191, low: 0 } },
    { id: 2, name: 'RHEL 9', based_on_title: 'GPOS SRG', version: 2, release: 7, updated_at: '2025-06-15', rules_count: 275, severity_counts: { high: 12, medium: 248, low: 15 } },
  ]

  afterEach(() => {
    if (wrapper) {
      wrapper.destroy()
    }
  })

  // ==========================================
  // SORTABLE COLUMNS - SRG TYPE
  // ==========================================
  describe('sortable columns - SRG type', () => {
    beforeEach(() => {
      wrapper = shallowMount(SecurityRequirementsGuidesTable, {
        localVue,
        propsData: {
          srgs: sampleSRGs,
          is_vulcan_admin: false,
          type: 'SRG',
        },
        stubs: {
          BTable: true,
          BPagination: true,
          BIcon: true,
          BButton: true,
          BLink: true,
        },
      })
    })

    it('SRG ID column is sortable', () => {
      const fields = wrapper.vm.fields
      const srgIdField = fields.find((f) => f.key === 'srg_id')
      expect(srgIdField).toBeDefined()
      expect(srgIdField.sortable).toBe(true)
    })

    it('Title column is sortable', () => {
      const fields = wrapper.vm.fields
      const titleField = fields.find((f) => f.key === 'title')
      expect(titleField).toBeDefined()
      expect(titleField.sortable).toBe(true)
    })

    it('Version column is sortable', () => {
      const fields = wrapper.vm.fields
      const versionField = fields.find((f) => f.key === 'version')
      expect(versionField).toBeDefined()
      expect(versionField.sortable).toBe(true)
    })

    it('Release Date column is sortable', () => {
      const fields = wrapper.vm.fields
      const dateField = fields.find((f) => f.key === 'release_date')
      expect(dateField).toBeDefined()
      expect(dateField.sortable).toBe(true)
    })
  })

  // ==========================================
  // SORTABLE COLUMNS - STIG TYPE
  // ==========================================
  describe('sortable columns - STIG type', () => {
    beforeEach(() => {
      wrapper = shallowMount(SecurityRequirementsGuidesTable, {
        localVue,
        propsData: {
          srgs: sampleSTIGs,
          is_vulcan_admin: false,
          type: 'STIG',
        },
        stubs: {
          BTable: true,
          BPagination: true,
          BIcon: true,
          BButton: true,
          BLink: true,
        },
      })
    })

    it('STIG ID column is sortable', () => {
      const fields = wrapper.vm.fields
      const stigIdField = fields.find((f) => f.key === 'stig_id')
      expect(stigIdField).toBeDefined()
      expect(stigIdField.sortable).toBe(true)
    })

    it('Title column is sortable', () => {
      const fields = wrapper.vm.fields
      const titleField = fields.find((f) => f.key === 'title')
      expect(titleField).toBeDefined()
      expect(titleField.sortable).toBe(true)
    })

    it('Version column is sortable', () => {
      const fields = wrapper.vm.fields
      const versionField = fields.find((f) => f.key === 'version')
      expect(versionField).toBeDefined()
      expect(versionField.sortable).toBe(true)
    })

    it('Benchmark Date column is sortable', () => {
      const fields = wrapper.vm.fields
      const dateField = fields.find((f) => f.key === 'benchmark_date')
      expect(dateField).toBeDefined()
      expect(dateField.sortable).toBe(true)
    })
  })

  // ==========================================
  // SORTABLE COLUMNS - COMPONENT TYPE
  // ==========================================
  describe('sortable columns - Component type', () => {
    beforeEach(() => {
      wrapper = shallowMount(SecurityRequirementsGuidesTable, {
        localVue,
        propsData: {
          srgs: sampleComponents,
          is_vulcan_admin: false,
          type: 'Component',
        },
        stubs: {
          BTable: true,
          BPagination: true,
          BIcon: true,
          BButton: true,
          BLink: true,
        },
      })
    })

    it('Name column is sortable', () => {
      const fields = wrapper.vm.fields
      const nameField = fields.find((f) => f.key === 'name')
      expect(nameField).toBeDefined()
      expect(nameField.sortable).toBe(true)
    })

    it('Based On column is sortable', () => {
      const fields = wrapper.vm.fields
      const basedOnField = fields.find((f) => f.key === 'based_on_title')
      expect(basedOnField).toBeDefined()
      expect(basedOnField.sortable).toBe(true)
    })

    it('Version column is sortable', () => {
      const fields = wrapper.vm.fields
      const versionField = fields.find((f) => f.key === 'component_version')
      expect(versionField).toBeDefined()
      expect(versionField.sortable).toBe(true)
    })

    it('Updated column is sortable', () => {
      const fields = wrapper.vm.fields
      const updatedField = fields.find((f) => f.key === 'updated_at')
      expect(updatedField).toBeDefined()
      expect(updatedField.sortable).toBe(true)
    })
  })

  // ==========================================
  // SEVERITY BADGES COLUMN - COMPONENT TYPE
  // ==========================================
  describe('severity badges column - Component type', () => {
    beforeEach(() => {
      wrapper = shallowMount(SecurityRequirementsGuidesTable, {
        localVue,
        propsData: {
          srgs: sampleComponents,
          is_vulcan_admin: false,
          type: 'Component',
        },
        stubs: {
          BTable: true,
          BPagination: true,
          BIcon: true,
          BButton: true,
          BLink: true,
          BBadge: true,
        },
      })
    })

    it('includes Severity column', () => {
      const fields = wrapper.vm.fields
      const severityField = fields.find((f) => f.key === 'severity_counts')
      expect(severityField).toBeDefined()
      expect(severityField.label).toBe('Severity')
    })
  })

  // ==========================================
  // SEVERITY BADGES - ALL TYPES
  // ==========================================
  describe('severity badges - all types have it', () => {
    it('SRG type has Severity column', () => {
      wrapper = shallowMount(SecurityRequirementsGuidesTable, {
        localVue,
        propsData: {
          srgs: sampleSRGs,
          is_vulcan_admin: false,
          type: 'SRG',
        },
        stubs: { BTable: true, BPagination: true, BIcon: true },
      })

      const fields = wrapper.vm.fields
      const severityField = fields.find((f) => f.key === 'severity_counts')
      expect(severityField).toBeDefined()
      expect(severityField.label).toBe('Severity')
    })

    it('STIG type has Severity column', () => {
      wrapper = shallowMount(SecurityRequirementsGuidesTable, {
        localVue,
        propsData: {
          srgs: sampleSTIGs,
          is_vulcan_admin: false,
          type: 'STIG',
        },
        stubs: { BTable: true, BPagination: true, BIcon: true },
      })

      const fields = wrapper.vm.fields
      const severityField = fields.find((f) => f.key === 'severity_counts')
      expect(severityField).toBeDefined()
      expect(severityField.label).toBe('Severity')
    })
  })

  // ==========================================
  // COLUMN VISIBILITY TOGGLE
  // ==========================================
  describe('column visibility toggle', () => {
    beforeEach(() => {
      wrapper = shallowMount(SecurityRequirementsGuidesTable, {
        localVue,
        propsData: {
          srgs: sampleComponents,
          is_vulcan_admin: false,
          type: 'Component',
        },
        stubs: {
          BTable: true,
          BPagination: true,
          BIcon: true,
          BButton: true,
          BLink: true,
          BDropdown: true,
          BDropdownItem: true,
          BDropdownDivider: true,
        },
      })
    })

    it('has visibleColumns data property', () => {
      expect(wrapper.vm.visibleColumns).toBeDefined()
      expect(Array.isArray(wrapper.vm.visibleColumns)).toBe(true)
    })

    it('all columns visible by default', () => {
      const allColumnKeys = wrapper.vm.allColumnKeys
      const visibleColumns = wrapper.vm.visibleColumns
      expect(visibleColumns).toEqual(allColumnKeys)
    })

    it('toggleColumn method exists', () => {
      expect(wrapper.vm.toggleColumn).toBeDefined()
      expect(typeof wrapper.vm.toggleColumn).toBe('function')
    })

    it('toggleColumn adds column when not visible', () => {
      wrapper.vm.visibleColumns = ['name', 'version']
      wrapper.vm.toggleColumn('based_on_title')
      expect(wrapper.vm.visibleColumns).toContain('based_on_title')
    })

    it('toggleColumn removes column when visible', () => {
      wrapper.vm.visibleColumns = ['name', 'based_on_title', 'version']
      wrapper.vm.toggleColumn('based_on_title')
      expect(wrapper.vm.visibleColumns).not.toContain('based_on_title')
    })

    it('filteredFields only includes visible columns', () => {
      wrapper.vm.visibleColumns = ['name', 'component_version']
      const filtered = wrapper.vm.filteredFields
      expect(filtered.length).toBe(2)
      expect(filtered.map(f => f.key)).toEqual(['name', 'component_version'])
    })

    it('isColumnVisible method works correctly', () => {
      wrapper.vm.visibleColumns = ['name', 'component_version']
      expect(wrapper.vm.isColumnVisible('name')).toBe(true)
      expect(wrapper.vm.isColumnVisible('based_on_title')).toBe(false)
    })
  })
})
