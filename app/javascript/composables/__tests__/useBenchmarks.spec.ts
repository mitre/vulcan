/**
 * useBenchmarks Composable Unit Tests
 *
 * Tests the unified benchmarks interface for STIGs, SRGs, and Components.
 */

import { beforeEach, describe, expect, it, vi } from 'vitest'
import { ref } from 'vue'
import { useComponentsStore, useSrgsStore, useStigsStore } from '@/stores'
import { useBenchmarks } from '../useBenchmarks'

// Mock the toast composable
vi.mock('../useToast', () => ({
  useAppToast: () => ({
    success: vi.fn(),
    error: vi.fn(),
    info: vi.fn(),
    warning: vi.fn(),
  }),
}))

// Mock the API modules
vi.mock('@/apis/stigs.api', () => ({
  getStigs: vi.fn(),
  getStig: vi.fn(),
  uploadStig: vi.fn(),
  deleteStig: vi.fn(),
}))

vi.mock('@/apis/srgs.api', () => ({
  getSrgs: vi.fn(),
  getSrg: vi.fn(),
  uploadSrg: vi.fn(),
  deleteSrg: vi.fn(),
}))

vi.mock('@/apis/components.api', () => ({
  getComponents: vi.fn(),
  getComponent: vi.fn(),
  createComponent: vi.fn(),
  updateComponent: vi.fn(),
  deleteComponent: vi.fn(),
  duplicateComponent: vi.fn(),
}))

describe('useBenchmarks', () => {
  describe('type switching', () => {
    it('returns stig type when called with "stig"', () => {
      const benchmarks = useBenchmarks('stig')
      expect(benchmarks.type).toBe('stig')
    })

    it('returns srg type when called with "srg"', () => {
      const benchmarks = useBenchmarks('srg')
      expect(benchmarks.type).toBe('srg')
    })

    it('returns component type when called with "component"', () => {
      const benchmarks = useBenchmarks('component')
      expect(benchmarks.type).toBe('component')
    })
  })

  describe('sTIG benchmarks', () => {
    let stigStore: ReturnType<typeof useStigsStore>

    beforeEach(() => {
      stigStore = useStigsStore()
      stigStore.reset()
    })

    it('converts STIGs to unified benchmark format', () => {
      stigStore.$patch({
        stigs: [
          {
            id: 1,
            stig_id: 'RHEL_9_STIG',
            title: 'Red Hat Enterprise Linux 9 STIG',
            name: 'RHEL 9',
            version: 'V1R1',
            benchmark_date: '2024-01-15',
          },
        ] as any,
      })

      const benchmarks = useBenchmarks('stig')
      expect(benchmarks.items.value).toHaveLength(1)
      expect(benchmarks.items.value[0]).toEqual({
        id: 1,
        benchmark_id: 'RHEL_9_STIG',
        title: 'Red Hat Enterprise Linux 9 STIG',
        name: 'RHEL 9',
        version: 'V1R1',
        date: '2024-01-15',
      })
    })

    it('exposes upload function for STIGs', () => {
      const benchmarks = useBenchmarks('stig')
      expect(benchmarks.upload).toBeDefined()
    })

    it('exposes remove function for STIGs', () => {
      const benchmarks = useBenchmarks('stig')
      expect(benchmarks.remove).toBeDefined()
    })
  })

  describe('sRG benchmarks', () => {
    let srgStore: ReturnType<typeof useSrgsStore>

    beforeEach(() => {
      srgStore = useSrgsStore()
      srgStore.reset()
    })

    it('converts SRGs to unified benchmark format', () => {
      srgStore.$patch({
        srgs: [
          {
            id: 2,
            srg_id: 'SRG-OS-000001',
            title: 'General Purpose Operating System SRG',
            name: 'GPOS SRG',
            version: 'V2R3',
            release_date: '2024-02-20',
          },
        ] as any,
      })

      const benchmarks = useBenchmarks('srg')
      expect(benchmarks.items.value).toHaveLength(1)
      expect(benchmarks.items.value[0]).toEqual({
        id: 2,
        benchmark_id: 'SRG-OS-000001',
        title: 'General Purpose Operating System SRG',
        name: 'GPOS SRG',
        version: 'V2R3',
        date: '2024-02-20',
      })
    })

    it('exposes upload function for SRGs', () => {
      const benchmarks = useBenchmarks('srg')
      expect(benchmarks.upload).toBeDefined()
    })

    it('exposes remove function for SRGs', () => {
      const benchmarks = useBenchmarks('srg')
      expect(benchmarks.remove).toBeDefined()
    })
  })

  describe('component benchmarks', () => {
    let componentStore: ReturnType<typeof useComponentsStore>

    beforeEach(() => {
      componentStore = useComponentsStore()
      componentStore.reset()
    })

    it('converts Components to unified benchmark format', () => {
      componentStore.$patch({
        components: [
          {
            id: 3,
            name: 'Test Component',
            prefix: 'TEST',
            version: 1,
            release: 2,
            title: 'Test Component Title',
            released: false,
            created_at: '2024-03-10T10:00:00Z',
          },
        ] as any,
      })

      const benchmarks = useBenchmarks('component')
      expect(benchmarks.items.value).toHaveLength(1)
      expect(benchmarks.items.value[0]).toEqual({
        id: 3,
        benchmark_id: 'TEST-1',
        title: 'Test Component Title',
        name: 'Test Component',
        version: 'V1R2',
        date: '2024-03-10T10:00:00Z',
      })
    })

    it('uses name as title when title is not set', () => {
      componentStore.$patch({
        components: [
          {
            id: 4,
            name: 'Component Name',
            prefix: 'COMP',
            version: 2,
            release: 0,
            title: null,
            released: false,
            created_at: '2024-03-15T10:00:00Z',
          },
        ] as any,
      })

      const benchmarks = useBenchmarks('component')
      expect(benchmarks.items.value[0].title).toBe('Component Name')
    })

    it('does not expose upload function for Components', () => {
      const benchmarks = useBenchmarks('component')
      expect(benchmarks.upload).toBeUndefined()
    })

    it('exposes remove function for Components', () => {
      const benchmarks = useBenchmarks('component')
      expect(benchmarks.remove).toBeDefined()
    })
  })

  describe('releasedOnly option for Components', () => {
    let componentStore: ReturnType<typeof useComponentsStore>

    beforeEach(() => {
      componentStore = useComponentsStore()
      componentStore.reset()
      componentStore.$patch({
        components: [
          { id: 1, name: 'Released', prefix: 'REL', version: 1, release: 0, released: true, created_at: '2024-01-01' },
          { id: 2, name: 'Draft', prefix: 'DRF', version: 1, release: 0, released: false, created_at: '2024-01-02' },
          { id: 3, name: 'Also Released', prefix: 'REL2', version: 1, release: 0, released: true, created_at: '2024-01-03' },
        ] as any,
      })
    })

    it('shows all components when releasedOnly is false', () => {
      const benchmarks = useBenchmarks('component', { releasedOnly: false })
      expect(benchmarks.items.value).toHaveLength(3)
    })

    it('shows all components when releasedOnly is not set', () => {
      const benchmarks = useBenchmarks('component')
      expect(benchmarks.items.value).toHaveLength(3)
    })

    it('filters to released components when releasedOnly is true', () => {
      const benchmarks = useBenchmarks('component', { releasedOnly: true })
      expect(benchmarks.items.value).toHaveLength(2)
      expect(benchmarks.items.value.every(item => item.name === 'Released' || item.name === 'Also Released')).toBe(true)
    })

    it('supports reactive releasedOnly ref', () => {
      const releasedOnly = ref(false)
      const benchmarks = useBenchmarks('component', { releasedOnly })

      // Initially shows all
      expect(benchmarks.items.value).toHaveLength(3)

      // Switch to released only
      releasedOnly.value = true
      expect(benchmarks.items.value).toHaveLength(2)

      // Switch back
      releasedOnly.value = false
      expect(benchmarks.items.value).toHaveLength(3)
    })
  })

  describe('loading and error state', () => {
    it('exposes loading state for STIGs', () => {
      const stigStore = useStigsStore()
      stigStore.$patch({ loading: true })

      const benchmarks = useBenchmarks('stig')
      expect(benchmarks.loading.value).toBe(true)
    })

    it('exposes loading state for SRGs', () => {
      const srgStore = useSrgsStore()
      srgStore.$patch({ loading: true })

      const benchmarks = useBenchmarks('srg')
      expect(benchmarks.loading.value).toBe(true)
    })

    it('exposes loading state for Components', () => {
      const componentStore = useComponentsStore()
      componentStore.$patch({ loading: true })

      const benchmarks = useBenchmarks('component')
      expect(benchmarks.loading.value).toBe(true)
    })

    it('exposes error state for STIGs', () => {
      const stigStore = useStigsStore()
      stigStore.$patch({ error: 'STIG error' })

      const benchmarks = useBenchmarks('stig')
      expect(benchmarks.error.value).toBe('STIG error')
    })

    it('exposes error state for SRGs', () => {
      const srgStore = useSrgsStore()
      srgStore.$patch({ error: 'SRG error' })

      const benchmarks = useBenchmarks('srg')
      expect(benchmarks.error.value).toBe('SRG error')
    })

    it('exposes error state for Components', () => {
      const componentStore = useComponentsStore()
      componentStore.$patch({ error: 'Component error' })

      const benchmarks = useBenchmarks('component')
      expect(benchmarks.error.value).toBe('Component error')
    })
  })
})
