import { describe, it, expect, beforeEach } from "vitest";
import { setActivePinia, createPinia } from "pinia";
import { useCommentsStore } from "@/stores/comments";

describe("useCommentsStore", () => {
  beforeEach(() => {
    setActivePinia(createPinia());
  });

  it("instantiates with empty comments state", () => {
    const store = useCommentsStore();
    expect(store.comments).toEqual({});
  });

  it("instantiates with empty loading state", () => {
    const store = useCommentsStore();
    expect(store.loading).toBe(false);
  });

  it("instantiates with null error state", () => {
    const store = useCommentsStore();
    expect(store.error).toBeNull();
  });

  it("has the correct store id", () => {
    const store = useCommentsStore();
    expect(store.$id).toBe("comments");
  });
});
