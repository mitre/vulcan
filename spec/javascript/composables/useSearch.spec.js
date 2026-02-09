import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import axios from "axios";
import { useSearch } from "@/composables/useSearch";

// Mock axios
vi.mock("axios");

describe("useSearch", () => {
  beforeEach(() => {
    vi.useFakeTimers();
    axios.get.mockReset();
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  // Requirements:
  // - Provides searchTerm ref for binding to input
  // - Provides isLoading state
  // - Provides results (projects, components, rules)
  // - Debounces API calls (300ms)
  // - Only searches when query is >= 2 characters
  // - Calls /api/search/global endpoint

  describe("initialization", () => {
    it("returns searchTerm ref initialized to empty string", () => {
      const { searchTerm } = useSearch();
      expect(searchTerm.value).toBe("");
    });

    it("returns isLoading ref initialized to false", () => {
      const { isLoading } = useSearch();
      expect(isLoading.value).toBe(false);
    });

    it("returns empty results arrays", () => {
      const { projects, components, rules } = useSearch();
      expect(projects.value).toEqual([]);
      expect(components.value).toEqual([]);
      expect(rules.value).toEqual([]);
    });
  });

  describe("search behavior", () => {
    it("does not search for queries less than 2 characters", async () => {
      const { searchTerm, search } = useSearch();
      searchTerm.value = "a";
      await search();

      expect(axios.get).not.toHaveBeenCalled();
    });

    it("searches for queries of 2 or more characters", async () => {
      axios.get.mockResolvedValueOnce({
        data: { projects: [], components: [], rules: [] },
      });

      const { searchTerm, search } = useSearch();
      searchTerm.value = "ab";
      await search();

      expect(axios.get).toHaveBeenCalledWith("/api/search/global", {
        params: { q: "ab", limit: 10 },
      });
    });

    it("sets isLoading to true during search", async () => {
      let resolvePromise;
      axios.get.mockImplementationOnce(
        () =>
          new Promise((resolve) => {
            resolvePromise = () =>
              resolve({ data: { projects: [], components: [], rules: [] } });
          })
      );

      const { searchTerm, search, isLoading } = useSearch();
      searchTerm.value = "test";
      const promise = search();

      expect(isLoading.value).toBe(true);

      resolvePromise();
      await promise;

      expect(isLoading.value).toBe(false);
    });

    it("populates results from API response", async () => {
      const mockResponse = {
        data: {
          projects: [{ id: 1, name: "Project 1", description: "Desc" }],
          components: [
            { id: 2, name: "Component 1", project_name: "Project 1" },
          ],
          rules: [{ id: 3, rule_id: "RULE-001", title: "Rule Title" }],
        },
      };
      axios.get.mockResolvedValueOnce(mockResponse);

      const { searchTerm, search, projects, components, rules } = useSearch();
      searchTerm.value = "test";
      await search();

      expect(projects.value).toHaveLength(1);
      expect(projects.value[0].name).toBe("Project 1");
      expect(components.value).toHaveLength(1);
      expect(components.value[0].name).toBe("Component 1");
      expect(rules.value).toHaveLength(1);
      expect(rules.value[0].rule_id).toBe("RULE-001");
    });

    it("clears results when searchTerm is cleared", async () => {
      const mockResponse = {
        data: {
          projects: [{ id: 1, name: "Project 1" }],
          components: [],
          rules: [],
        },
      };
      axios.get.mockResolvedValueOnce(mockResponse);

      const { searchTerm, search, projects, clearResults } = useSearch();
      searchTerm.value = "test";
      await search();

      expect(projects.value).toHaveLength(1);

      clearResults();

      expect(projects.value).toEqual([]);
    });
  });

  describe("error handling", () => {
    it("sets error state on API failure", async () => {
      axios.get.mockRejectedValueOnce(new Error("Network error"));

      const { searchTerm, search, error } = useSearch();
      searchTerm.value = "test";

      await expect(search()).rejects.toThrow("Network error");
      expect(error.value).toBe("Network error");
    });

    it("clears error on successful search", async () => {
      axios.get.mockRejectedValueOnce(new Error("Network error"));

      const { searchTerm, search, error } = useSearch();
      searchTerm.value = "test";
      await search().catch(() => {});

      expect(error.value).toBe("Network error");

      axios.get.mockResolvedValueOnce({
        data: { projects: [], components: [], rules: [] },
      });
      await search();

      expect(error.value).toBeNull();
    });
  });

  describe("hasResults computed", () => {
    it("returns false when no results", () => {
      const { hasResults } = useSearch();
      expect(hasResults.value).toBe(false);
    });

    it("returns true when projects exist", async () => {
      axios.get.mockResolvedValueOnce({
        data: {
          projects: [{ id: 1, name: "Project" }],
          components: [],
          rules: [],
        },
      });

      const { searchTerm, search, hasResults } = useSearch();
      searchTerm.value = "test";
      await search();

      expect(hasResults.value).toBe(true);
    });
  });
});
