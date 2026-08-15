import { ref, computed } from "vue";
import { benchmarkItemTerm } from "../constants/terminology";

/**
 * Benchmark Type Configurations
 *
 * Defines how to adapt the viewer for different benchmark types.
 */
const BENCHMARK_CONFIG = {
  stig: {
    itemsKey: "rules", // After stigToBenchmark adapter
    searchFields: ["rule_id", "title", "severity"],
    idField: "rule_id",
  },
  srg: {
    itemsKey: "rules", // After srgToBenchmark adapter
    searchFields: ["rule_id", "title"],
    idField: "rule_id",
  },
  cis: {
    itemsKey: "rules", // After adapter (CIS uses stigToBenchmark)
    searchFields: ["rule_id", "title", "level"],
    idField: "rule_id",
  },
  component: {
    itemsKey: "rules", // After componentToBenchmark adapter
    searchFields: ["rule_id", "title", "rule_severity"],
    idField: "rule_id",
  },
};

/**
 * useBenchmarkViewer - Unified viewer for STIG/SRG/CIS benchmarks
 *
 * Provides type-agnostic state management and navigation for benchmark viewers.
 * Configuration-driven to handle differences between benchmark types.
 *
 * Usage:
 *   import { useBenchmarkViewer } from "@/composables/useBenchmarkViewer";
 *
 *   setup() {
 *     const {
 *       selectedItem,
 *       items,
 *       filteredItems,
 *       selectItem,
 *       selectNext,
 *       selectPrevious,
 *       setSearch
 *     } = useBenchmarkViewer(benchmark, 'stig');
 *
 *     return { selectedItem, filteredItems, selectItem, setSearch };
 *   }
 *
 * @param {Object} benchmarkData - The benchmark object (STIG, SRG, or CIS)
 * @param {String} type - Benchmark type ('stig' | 'srg' | 'cis')
 * @returns {Object} Reactive state and methods
 */
export function useBenchmarkViewer(benchmarkData, type, documentType) {
  // Get configuration for this benchmark type
  const config = BENCHMARK_CONFIG[type];
  if (!config) {
    throw new Error(
      `Unknown benchmark type: ${type}. Must be 'stig', 'srg', 'cis', or 'component'.`,
    );
  }

  // State
  const benchmark = ref(benchmarkData);
  const benchmarkType = ref(type);
  const searchTerm = ref("");

  // Extract items from benchmark using config
  const items = computed(() => {
    return benchmark.value[config.itemsKey] || [];
  });

  // Selected item state
  const selectedItem = ref(items.value[0] || null);

  // Filtered items based on search
  const filteredItems = computed(() => {
    if (!searchTerm.value) return items.value;

    const search = searchTerm.value.toLowerCase();
    return items.value.filter((item) => {
      // Search across configured fields
      return config.searchFields.some((field) => {
        const value = item[field];
        return value && String(value).toLowerCase().includes(search);
      });
    });
  });

  // Item type name from config
  // Noun comes from the central terminology table — a released component
  // resolves through its own document_type; catalogs through their type.
  const itemTypeName = computed(() => benchmarkItemTerm(type, documentType).singular.toLowerCase());

  /**
   * Select a specific item
   */
  function selectItem(item) {
    selectedItem.value = item;
  }

  /**
   * Navigate to next item in filtered list
   */
  function selectNext() {
    if (filteredItems.value.length === 0) return;
    const currentIndex = filteredItems.value.findIndex(
      (item) => item.id === selectedItem.value?.id,
    );
    const nextIndex = (currentIndex + 1) % filteredItems.value.length;
    selectedItem.value = filteredItems.value[nextIndex];
  }

  /**
   * Navigate to previous item in filtered list
   */
  function selectPrevious() {
    if (filteredItems.value.length === 0) return;
    const currentIndex = filteredItems.value.findIndex(
      (item) => item.id === selectedItem.value?.id,
    );
    const prevIndex = currentIndex <= 0 ? filteredItems.value.length - 1 : currentIndex - 1;
    selectedItem.value = filteredItems.value[prevIndex];
  }

  /**
   * Set search term to filter items
   */
  function setSearch(term) {
    searchTerm.value = term;
    // If current selected item is filtered out, select first filtered item
    if (
      filteredItems.value.length > 0 &&
      !filteredItems.value.some((item) => item.id === selectedItem.value?.id)
    ) {
      selectedItem.value = filteredItems.value[0];
    }
  }

  return {
    // State
    benchmark,
    benchmarkType,
    selectedItem,
    items,
    filteredItems,
    searchTerm,
    itemTypeName,
    // Methods
    selectItem,
    selectNext,
    selectPrevious,
    setSearch,
  };
}
