/**
 * Benchmarks Composable
 *
 * Provides a unified interface for working with both STIGs and SRGs.
 * Converts internal types to the unified IBenchmarkListItem format.
 *
 * Usage:
 *   const { items, loading, error, refresh, upload, remove } = useBenchmarks('stig')
 */

import type { BenchmarkType, IBenchmarkListItem } from '@/types'
import { computed } from 'vue'
import { useSrgs } from './useSrgs'
import { useStigs } from './useStigs'

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
 * Unified benchmarks composable
 * Provides the same interface for both STIGs and SRGs
 */
export function useBenchmarks(type: BenchmarkType) {
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
  else {
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
}
