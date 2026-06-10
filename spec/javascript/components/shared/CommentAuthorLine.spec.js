import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import CommentAuthorLine from "@/components/shared/CommentAuthorLine.vue";

const baseProps = {
  name: "John Osborne",
  email: "josborne@chainguard.dev",
  date: "2026-05-19T16:17:00Z",
};

describe("CommentAuthorLine", () => {
  describe("inline layout", () => {
    it("renders avatar initials and the formatted date (useDateFormat)", () => {
      const wrapper = mount(CommentAuthorLine, {
        localVue,
        propsData: { ...baseProps, layout: "inline" },
      });
      expect(wrapper.find(".b-avatar-text span").text()).toBe("JO");
      const dateText = wrapper.find("[data-testid='author-date']").text();
      // moment "lll" format: month name + year, never the raw ISO string
      expect(dateText).toContain("May");
      expect(dateText).toContain("2026");
      expect(dateText).not.toContain("T16:17");
    });

    it("renders a UserBadge with name and email", () => {
      const wrapper = mount(CommentAuthorLine, {
        localVue,
        propsData: { ...baseProps, layout: "inline" },
      });
      const badge = wrapper.findComponent({ name: "UserBadge" });
      expect(badge.exists()).toBe(true);
      expect(badge.props("name")).toBe("John Osborne");
      expect(badge.props("email")).toBe("josborne@chainguard.dev");
    });

    it("renders initials in the avatar", () => {
      const wrapper = mount(CommentAuthorLine, {
        localVue,
        propsData: { ...baseProps, layout: "inline" },
      });
      expect(wrapper.find(".b-avatar-text span").text()).toBe("JO");
    });
  });

  describe("block layout", () => {
    it("renders name with showName and date on second line", () => {
      const wrapper = mount(CommentAuthorLine, {
        localVue,
        propsData: { ...baseProps, layout: "block" },
      });
      const badge = wrapper.findComponent({ name: "UserBadge" });
      expect(badge.exists()).toBe(true);
      expect(badge.props("showName")).toBe(true);
      expect(wrapper.text()).toContain("John Osborne");
      expect(wrapper.find("[data-testid='author-date']").text()).toContain("posted");
    });
  });

  describe("cell layout", () => {
    it("renders name with showName, no date", () => {
      const wrapper = mount(CommentAuthorLine, {
        localVue,
        propsData: { ...baseProps, layout: "cell" },
      });
      const badge = wrapper.findComponent({ name: "UserBadge" });
      expect(badge.exists()).toBe(true);
      expect(badge.props("showName")).toBe(true);
      expect(wrapper.text()).toContain("John Osborne");
      expect(wrapper.find("[data-testid='author-date']").exists()).toBe(false);
    });
  });

  describe("name fallback chain", () => {
    it("uses name prop directly when provided", () => {
      const wrapper = mount(CommentAuthorLine, {
        localVue,
        propsData: { name: "Alice", email: null, date: null, layout: "inline" },
      });
      const badge = wrapper.findComponent({ name: "UserBadge" });
      expect(badge.props("name")).toBe("Alice");
    });

    it("falls back to commenterDisplayName when name is null", () => {
      const wrapper = mount(CommentAuthorLine, {
        localVue,
        propsData: {
          name: null,
          commenterDisplayName: "Imported User",
          email: null,
          date: null,
          layout: "inline",
        },
      });
      const badge = wrapper.findComponent({ name: "UserBadge" });
      expect(badge.props("name")).toBe("Imported User");
    });

    it("falls back to em-dash when both name and commenterDisplayName are null", () => {
      const wrapper = mount(CommentAuthorLine, {
        localVue,
        propsData: { name: null, commenterDisplayName: null, email: null, date: null, layout: "inline" },
      });
      const badge = wrapper.findComponent({ name: "UserBadge" });
      expect(badge.props("name")).toBe("—");
    });
  });

  describe("defaults", () => {
    it("defaults to inline layout when no layout prop", () => {
      const wrapper = mount(CommentAuthorLine, {
        localVue,
        propsData: { name: "Test", email: "t@t.com", date: "2026-01-01T00:00:00Z" },
      });
      expect(wrapper.find("[data-testid='author-date']").exists()).toBe(true);
      expect(wrapper.classes()).toContain("comment-author-line--inline");
    });
  });
});
