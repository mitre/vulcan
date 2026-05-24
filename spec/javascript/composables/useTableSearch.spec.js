import { describe, it, expect } from "vitest";
import { useTableSearch } from "@/composables/useTableSearch";

describe("useTableSearch", () => {
  const items = [
    { id: 1, name: "Alpha Project", title: "First" },
    { id: 2, name: "Beta Project", title: "Second" },
    { id: 3, name: "Gamma System", title: "Third" },
  ];

  it("exports search, perPage, currentPage, filteredItems, totalRows", () => {
    const result = useTableSearch(items, (item, q) =>
      item.name.toLowerCase().includes(q),
    );
    expect(result).toHaveProperty("search");
    expect(result).toHaveProperty("perPage");
    expect(result).toHaveProperty("currentPage");
    expect(result).toHaveProperty("filteredItems");
    expect(result).toHaveProperty("totalRows");
  });

  it("returns all items when search is empty", () => {
    const result = useTableSearch(items, (item, q) =>
      item.name.toLowerCase().includes(q),
    );
    expect(result.filteredItems.value).toHaveLength(3);
    expect(result.totalRows.value).toBe(3);
  });

  it("filters items by search term (case-insensitive)", () => {
    const result = useTableSearch(items, (item, q) =>
      item.name.toLowerCase().includes(q),
    );
    result.search.value = "beta";
    expect(result.filteredItems.value).toHaveLength(1);
    expect(result.filteredItems.value[0].name).toBe("Beta Project");
    expect(result.totalRows.value).toBe(1);
  });

  it("returns empty array when no items match", () => {
    const result = useTableSearch(items, (item, q) =>
      item.name.toLowerCase().includes(q),
    );
    result.search.value = "nonexistent";
    expect(result.filteredItems.value).toHaveLength(0);
    expect(result.totalRows.value).toBe(0);
  });

  it("defaults perPage to 10", () => {
    const result = useTableSearch(items, (item, q) =>
      item.name.toLowerCase().includes(q),
    );
    expect(result.perPage.value).toBe(10);
  });

  it("defaults currentPage to 1", () => {
    const result = useTableSearch(items, (item, q) =>
      item.name.toLowerCase().includes(q),
    );
    expect(result.currentPage.value).toBe(1);
  });

  it("accepts custom perPage", () => {
    const result = useTableSearch(
      items,
      (item, q) => item.name.toLowerCase().includes(q),
      { perPage: 25 },
    );
    expect(result.perPage.value).toBe(25);
  });

  it("handles reactive items array", () => {
    const reactiveItems = [...items];
    const result = useTableSearch(reactiveItems, (item, q) =>
      item.name.toLowerCase().includes(q),
    );
    expect(result.filteredItems.value).toHaveLength(3);
  });
});
