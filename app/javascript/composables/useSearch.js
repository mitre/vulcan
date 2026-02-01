import { ref, computed } from "vue";
import axios from "axios";

/**
 * Composable for global search functionality.
 * Searches across projects, components, and rules using the /api/search/global endpoint.
 *
 * @param {Object} options - Configuration options
 * @param {number} options.limit - Maximum results per category (default: 10)
 * @returns {Object} Search state and methods
 *
 * @example
 * ```javascript
 * const { searchTerm, search, projects, components, rules, isLoading } = useSearch();
 *
 * // Bind searchTerm to input
 * // <input v-model="searchTerm" @input="debouncedSearch" />
 *
 * // Or trigger search manually
 * searchTerm.value = 'kubernetes';
 * await search();
 * ```
 */
export function useSearch(options = {}) {
  const { limit = 10 } = options;

  // State
  const searchTerm = ref("");
  const isLoading = ref(false);
  const error = ref(null);

  // Results
  const projects = ref([]);
  const components = ref([]);
  const rules = ref([]);

  // Computed
  const hasResults = computed(() => {
    return (
      projects.value.length > 0 ||
      components.value.length > 0 ||
      rules.value.length > 0
    );
  });

  const totalResults = computed(() => {
    return projects.value.length + components.value.length + rules.value.length;
  });

  /**
   * Execute search against the API.
   * Only searches if query is 2+ characters.
   *
   * @returns {Promise<void>}
   */
  async function search() {
    const query = searchTerm.value.trim();

    // Don't search for very short queries
    if (query.length < 2) {
      return;
    }

    isLoading.value = true;
    error.value = null;

    try {
      const response = await axios.get("/api/search/global", {
        params: { q: query, limit },
      });

      // Update results
      projects.value = response.data.projects || [];
      components.value = response.data.components || [];
      rules.value = response.data.rules || [];
    } catch (err) {
      error.value = err.message || "Search failed";
      throw err;
    } finally {
      isLoading.value = false;
    }
  }

  /**
   * Clear all search results.
   */
  function clearResults() {
    projects.value = [];
    components.value = [];
    rules.value = [];
    error.value = null;
  }

  /**
   * Reset search state completely.
   */
  function reset() {
    searchTerm.value = "";
    clearResults();
  }

  return {
    // State
    searchTerm,
    isLoading,
    error,

    // Results
    projects,
    components,
    rules,

    // Computed
    hasResults,
    totalResults,

    // Methods
    search,
    clearResults,
    reset,
  };
}
