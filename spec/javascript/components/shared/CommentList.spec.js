import { describe, it, expect, vi, beforeEach } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import { setActivePinia, createPinia } from "pinia";
import CommentList from "@/components/containers/CommentList.vue";
import { useCommentsStore } from "@/stores/comments";
import { getComments } from "@/api/componentsApi";

vi.mock("@/api/baseApi", () => ({
  default: {
    get: vi.fn(),
    post: vi.fn(),
    put: vi.fn(),
    patch: vi.fn(),
    delete: vi.fn(),
    defaults: { headers: { common: {} } },
  },
}));

vi.mock("@/api/componentsApi", () => ({
  getComments: vi.fn(),
}));

const mockResponse = {
  data: {
    rows: [
      {
        id: 142,
        author_name: "John Doe",
        commenter_display_name: "John Doe",
        commenter_email: "john@example.com",
        comment: "Check text is vague",
        section: "check_content",
        triage_status: "pending",
        created_at: "2026-04-27T10:00:00Z",
        reactions: { up: 1, down: 0, mine: null },
        responses_count: 2,
        commenter_imported: false,
      },
      {
        id: 143,
        author_name: "Jane Smith",
        commenter_display_name: "Jane Smith",
        commenter_email: "jane@example.com",
        comment: "Fix text too broad",
        section: "fixtext",
        triage_status: "concur",
        created_at: "2026-04-28T10:00:00Z",
        reactions: { up: 0, down: 0, mine: null },
        responses_count: 0,
        commenter_imported: false,
      },
    ],
    pagination: { page: 1, per_page: 25, total: 2 },
    status_counts: { pending: 1, concur: 1 },
  },
};

describe("CommentList", () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    vi.clearAllMocks();
    getComments.mockResolvedValue(mockResponse);
  });

  const baseProps = { componentId: 38 };

  function mountWithSlot(props = {}, slots = {}) {
    return mount(CommentList, {
      localVue,
      propsData: { ...baseProps, ...props },
      scopedSlots: {
        item: '<div class="test-item" :data-id="props.comment.id">{{ props.comment.text }}</div>',
        ...slots,
      },
    });
  }

  describe("data fetching", () => {
    it("fetches comments from store on mount", async () => {
      const w = mountWithSlot();
      await w.vm.$nextTick();
      await new Promise((r) => setTimeout(r, 0));

      expect(getComments).toHaveBeenCalledWith(38, expect.any(Object));
    });

    it("exposes comments via #item scoped slot", async () => {
      const w = mountWithSlot();
      await w.vm.$nextTick();
      await new Promise((r) => setTimeout(r, 0));
      await w.vm.$nextTick();

      const items = w.findAll(".test-item");
      expect(items).toHaveLength(2);
      expect(items.at(0).attributes("data-id")).toBe("142");
      expect(items.at(1).attributes("data-id")).toBe("143");
    });

    it("renders #loading slot while fetching", async () => {
      let resolvePromise;
      getComments.mockReturnValue(
        new Promise((r) => {
          resolvePromise = r;
        }),
      );

      const w = mount(CommentList, {
        localVue,
        propsData: baseProps,
        scopedSlots: {
          item: "<div />",
          loading: '<div class="loading-state">Loading...</div>',
        },
      });
      await w.vm.$nextTick();

      expect(w.find(".loading-state").exists()).toBe(true);

      resolvePromise(mockResponse);
      await new Promise((r) => setTimeout(r, 0));
      await w.vm.$nextTick();

      expect(w.find(".loading-state").exists()).toBe(false);
    });

    it("renders #empty slot when no comments returned", async () => {
      getComments.mockResolvedValue({
        data: { rows: [], pagination: { page: 1, per_page: 25, total: 0 } },
      });

      const w = mount(CommentList, {
        localVue,
        propsData: baseProps,
        scopedSlots: {
          item: "<div />",
          empty: '<div class="empty-state">No comments</div>',
        },
      });
      await w.vm.$nextTick();
      await new Promise((r) => setTimeout(r, 0));
      await w.vm.$nextTick();

      expect(w.find(".empty-state").exists()).toBe(true);
    });
  });

  describe("filtering", () => {
    it("passes filterStatus to store fetch params", async () => {
      mountWithSlot({ filterStatus: "pending" });
      await new Promise((r) => setTimeout(r, 0));

      expect(getComments).toHaveBeenCalledWith(
        38,
        expect.objectContaining({ triage_status: "pending" }),
      );
    });

    it("passes filterSection to store fetch params", async () => {
      mountWithSlot({ filterSection: "check_content" });
      await new Promise((r) => setTimeout(r, 0));

      expect(getComments).toHaveBeenCalledWith(
        38,
        expect.objectContaining({ section: "check_content" }),
      );
    });

    it("re-fetches when filterStatus prop changes", async () => {
      const w = mountWithSlot({ filterStatus: "all" });
      await new Promise((r) => setTimeout(r, 0));

      await w.setProps({ filterStatus: "pending" });
      await new Promise((r) => setTimeout(r, 0));

      expect(getComments).toHaveBeenCalledTimes(2);
    });
  });

  describe("highlight-section (dedup mode)", () => {
    it("marks non-matching items as dimmed when highlightSection is set", async () => {
      const w = mount(CommentList, {
        localVue,
        propsData: { ...baseProps, highlightSection: "check_content" },
        scopedSlots: {
          item: '<div :class="{ dimmed: props.dimmed }">{{ props.comment.section }}</div>',
        },
      });
      await w.vm.$nextTick();
      await new Promise((r) => setTimeout(r, 0));
      await w.vm.$nextTick();

      const items = w.findAll("div[class]");
      const dimmedItems = items.wrappers.filter((i) => i.classes("dimmed"));
      expect(dimmedItems.length).toBe(1);
    });
  });

  describe("pagination", () => {
    it("exposes pagination data in scoped slot", async () => {
      const w = mount(CommentList, {
        localVue,
        propsData: baseProps,
        scopedSlots: {
          item: "<div />",
          footer: '<div class="pagination-info">{{ props.total }} total</div>',
        },
      });
      await w.vm.$nextTick();
      await new Promise((r) => setTimeout(r, 0));
      await w.vm.$nextTick();

      expect(w.find(".pagination-info").text()).toBe("2 total");
    });
  });
});
