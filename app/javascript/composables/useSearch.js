import { ref, computed } from "vue";
import axios from "axios";

/**
 * Composable for global search functionality.
 * Searches across projects, components, rules, SRGs, STIGs, STIG rules, and SRG rules
 * using the /api/search/global endpoint.
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
  const srgs = ref([]);
  const stigs = ref([]);
  const stigRules = ref([]);
  const srgRules = ref([]);

  // Computed
  const hasResults = computed(() => {
    return (
      projects.value.length > 0 ||
      components.value.length > 0 ||
      rules.value.length > 0 ||
      srgs.value.length > 0 ||
      stigs.value.length > 0 ||
      stigRules.value.length > 0 ||
      srgRules.value.length > 0
    );
  });

  const totalResults = computed(() => {
    return (
      projects.value.length +
      components.value.length +
      rules.value.length +
      srgs.value.length +
      stigs.value.length +
      stigRules.value.length +
      srgRules.value.length
    );
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
      srgs.value = response.data.srgs || [];
      stigs.value = response.data.stigs || [];
      stigRules.value = response.data.stig_rules || [];
      srgRules.value = response.data.srg_rules || [];
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
    srgs.value = [];
    stigs.value = [];
    stigRules.value = [];
    srgRules.value = [];
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
    srgs,
    stigs,
    stigRules,
    srgRules,

    // Computed
    hasResults,
    totalResults,

    // Methods
    search,
    clearResults,
    reset,
  };
}
