import { ref, computed, isRef } from "vue";

/**
 * Composable for table search, pagination, and filtering.
 * Extracts the duplicated search/perPage/currentPage/filteredItems pattern
 * from BenchmarkTable, ProjectsTable, UsersTable.
 *
 * @param {Array|Ref<Array>|Function} items - source items (reactive ref, plain array, or getter function)
 * @param {Function} filterFn - (item, downcasedQuery) => boolean
 * @param {Object} options - { perPage: 10 }
 * @returns {{ search, perPage, currentPage, filteredItems, totalRows }}
 */
export function useTableSearch(items, filterFn, options = {}) {
  const search = ref("");
  const perPage = ref(options.perPage || 10);
  const currentPage = ref(1);

  const filteredItems = computed(() => {
    const q = search.value.toLowerCase();
    const source = isRef(items) ? items.value : typeof items === "function" ? items() : items;
    if (!q) return source || [];
    return (source || []).filter((item) => filterFn(item, q));
  });

  const totalRows = computed(() => filteredItems.value.length);

  return { search, perPage, currentPage, filteredItems, totalRows };
}
