import { mount } from "@vue/test-utils";
import CommentAuthorLine from "@/components/shared/CommentAuthorLine.vue";

const baseProps = {
  name: "John Osborne",
  email: "josborne@chainguard.dev",
  date: "2026-05-19T16:17:00Z",
};

describe("CommentAuthorLine", () => {
  describe("inline layout", () => {
    it("renders name, email, and date on one line", () => {
      const wrapper = mount(CommentAuthorLine, {
        propsData: { ...baseProps, layout: "inline" },
      });
      expect(wrapper.find("[data-testid='author-name']").text()).toBe("John Osborne");
      expect(wrapper.find("[data-testid='author-email']").text()).toContain("josborne@chainguard.dev");
      expect(wrapper.find("[data-testid='author-date']").exists()).toBe(true);
    });

    it("shows email in parentheses", () => {
      const wrapper = mount(CommentAuthorLine, {
        propsData: { ...baseProps, layout: "inline" },
      });
      expect(wrapper.find("[data-testid='author-email']").text()).toBe("(josborne@chainguard.dev)");
    });

    it("hides email when not provided", () => {
      const wrapper = mount(CommentAuthorLine, {
        propsData: { name: "John", email: null, date: baseProps.date, layout: "inline" },
      });
      expect(wrapper.find("[data-testid='author-email']").exists()).toBe(false);
    });
  });

  describe("block layout", () => {
    it("renders name and email on first line, date on second", () => {
      const wrapper = mount(CommentAuthorLine, {
        propsData: { ...baseProps, layout: "block" },
      });
      expect(wrapper.find("[data-testid='author-name']").text()).toBe("John Osborne");
      expect(wrapper.find("[data-testid='author-email']").text()).toBe("(josborne@chainguard.dev)");
      expect(wrapper.find("[data-testid='author-date']").text()).toContain("posted");
    });
  });

  describe("cell layout", () => {
    it("renders name and email stacked, no date", () => {
      const wrapper = mount(CommentAuthorLine, {
        propsData: { ...baseProps, layout: "cell" },
      });
      expect(wrapper.find("[data-testid='author-name']").text()).toBe("John Osborne");
      expect(wrapper.find("[data-testid='author-email']").text()).toBe("josborne@chainguard.dev");
      expect(wrapper.find("[data-testid='author-date']").exists()).toBe(false);
    });

    it("renders email without parentheses in cell layout", () => {
      const wrapper = mount(CommentAuthorLine, {
        propsData: { ...baseProps, layout: "cell" },
      });
      const emailText = wrapper.find("[data-testid='author-email']").text();
      expect(emailText).not.toContain("(");
    });
  });

  describe("name fallback chain", () => {
    it("uses name prop directly when provided", () => {
      const wrapper = mount(CommentAuthorLine, {
        propsData: { name: "Alice", email: null, date: null, layout: "inline" },
      });
      expect(wrapper.find("[data-testid='author-name']").text()).toBe("Alice");
    });

    it("falls back to commenterDisplayName when name is null", () => {
      const wrapper = mount(CommentAuthorLine, {
        propsData: {
          name: null,
          commenterDisplayName: "Imported User",
          email: null,
          date: null,
          layout: "inline",
        },
      });
      expect(wrapper.find("[data-testid='author-name']").text()).toBe("Imported User");
    });

    it("falls back to em-dash when both name and commenterDisplayName are null", () => {
      const wrapper = mount(CommentAuthorLine, {
        propsData: { name: null, commenterDisplayName: null, email: null, date: null, layout: "inline" },
      });
      expect(wrapper.find("[data-testid='author-name']").text()).toBe("—");
    });
  });

  describe("defaults", () => {
    it("defaults to inline layout when no layout prop", () => {
      const wrapper = mount(CommentAuthorLine, {
        propsData: { name: "Test", email: "t@t.com", date: "2026-01-01T00:00:00Z" },
      });
      expect(wrapper.find("[data-testid='author-date']").exists()).toBe(true);
      expect(wrapper.find("[data-testid='author-email']").text()).toBe("(t@t.com)");
    });
  });
});
