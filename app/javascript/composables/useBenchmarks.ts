/**
 * Benchmarks Composable
 *
 * Provides a unified interface for working with STIGs, SRGs, and Components.
 * Converts internal types to the unified IBenchmarkListItem format.
 *
 * Usage:
 *   const { items, loading, error, refresh, upload, remove } = useBenchmarks('stig')
 *   const { items, loading, error, refresh } = useBenchmarks('component')
 *   const { items } = useBenchmarks('component', { releasedOnly: true }) // Public view
 */

import type { Ref } from 'vue'
import type { BenchmarkType, IBenchmarkListItem, IComponent } from '@/types'
import { computed } from 'vue'
import { useComponents } from './useComponents'
import { useSrgs } from './useSrgs'
import { useStigs } from './useStigs'

export interface UseBenchmarksOptions {
  /** For components: only show released components (public view) */
  releasedOnly?: boolean | Ref<boolean>
}

/**
 * Convert STIG to unified benchmark list item
 */
function stigToBenchmarkListItem(stig: Record<string, unknown>): IBenchmarkListItem {
  return {
    id: stig.id as number,
    benchmark_id: stig.stig_id as string,
    title: stig.title as string,
    name: stig.name as string | undefined,
    version: stig.version as string,
    date: stig.benchmark_date as string | undefined,
  }
}

/**
 * Convert SRG to unified benchmark list item
 */
function srgToBenchmarkListItem(srg: Record<string, unknown>): IBenchmarkListItem {
  return {
    id: srg.id as number,
    benchmark_id: srg.srg_id as string,
    title: srg.title as string,
    name: srg.name as string | undefined,
    version: srg.version as string,
    date: srg.release_date as string | undefined,
  }
}

/**
 * Convert Component to unified benchmark list item
 */
function componentToBenchmarkListItem(component: IComponent): IBenchmarkListItem {
  return {
    id: component.id,
    benchmark_id: `${component.prefix}-${component.version}`,
    title: component.title || component.name,
    name: component.name,
    version: `V${component.version}R${component.release || 0}`,
    date: component.created_at,
  }
}

/**
 * Unified benchmarks composable
 * Provides the same interface for STIGs, SRGs, and Components
 *
 * @param type - The benchmark type to work with
 * @param options - Optional configuration (e.g., releasedOnly for components)
 */
export function useBenchmarks(type: BenchmarkType, options: UseBenchmarksOptions = {}) {
  if (type === 'stig') {
    const { stigs, loading, error, refresh, upload, remove } = useStigs()

    // Convert STIGs to unified format
    const items = computed<IBenchmarkListItem[]>(() =>
      stigs.value.map(stigToBenchmarkListItem),
    )

    return {
      type: 'stig' as const,
      items,
      loading,
      error,
      refresh,
      upload,
      remove,
    }
  }
  else if (type === 'srg') {
    const { srgs, loading, error, refresh, upload, remove } = useSrgs()

    // Convert SRGs to unified format
    const items = computed<IBenchmarkListItem[]>(() =>
      srgs.value.map(srgToBenchmarkListItem),
    )

    return {
      type: 'srg' as const,
      items,
      loading,
      error,
      refresh,
      upload,
      remove,
    }
  }
  else {
    // Component type
    const { components, released, loading, error, refresh: refreshComponents, remove } = useComponents()

    // Convert Components to unified format
    // Filter by released status if releasedOnly option is set
    const items = computed<IBenchmarkListItem[]>(() => {
      const releasedOnly = typeof options.releasedOnly === 'object'
        ? options.releasedOnly.value
        : options.releasedOnly

      const sourceComponents = releasedOnly ? released.value : components.value
      return sourceComponents.map(componentToBenchmarkListItem)
    })

    return {
      type: 'component' as const,
      items,
      loading,
      error,
      refresh: refreshComponents,
      upload: undefined, // Components don't support file upload
      remove,
    }
  }
}
