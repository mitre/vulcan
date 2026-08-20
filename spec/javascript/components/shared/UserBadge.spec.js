import { describe, it, expect } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import UserBadge from "@/components/shared/UserBadge.vue";

describe("UserBadge", () => {
  describe("initials computation", () => {
    it("renders initials from first and last name", () => {
      const w = mount(UserBadge, {
        localVue,
        propsData: { name: "Jane Doe", email: "jane@example.com" },
      });
      expect(w.find(".b-avatar-text span").text()).toBe("JD");
    });

    it("renders first initial only for single-word names", () => {
      const w = mount(UserBadge, {
        localVue,
        propsData: { name: "Admin", email: "admin@example.com" },
      });
      expect(w.find(".b-avatar-text span").text()).toBe("A");
    });

    it("falls back to first 2 chars of email when name is blank", () => {
      const w = mount(UserBadge, {
        localVue,
        propsData: { name: "", email: "viewer@example.com" },
      });
      expect(w.find(".b-avatar-text span").text()).toBe("VI");
    });

    it("renders person-fill icon when no name or email", () => {
      const w = mount(UserBadge, {
        localVue,
        propsData: {},
      });
      const icon = w.find(".b-avatar .b-icon");
      expect(icon.exists()).toBe(true);
    });
  });

  describe("popover content", () => {
    it("shows email in popover (the value-add info)", () => {
      const w = mount(UserBadge, {
        localVue,
        propsData: { name: "Jane Doe", email: "jane@example.com" },
      });
      expect(w.vm.popoverContent).toContain("jane@example.com");
    });

    it("shows name in popover only when showName is false (avatar-only mode)", () => {
      const w = mount(UserBadge, {
        localVue,
        propsData: { name: "Jane Doe", email: "jane@example.com", showName: false },
      });
      expect(w.vm.popoverContent).toContain("Jane Doe");
    });

    it("omits name from popover when showName is true (already visible)", () => {
      const w = mount(UserBadge, {
        localVue,
        propsData: { name: "Jane Doe", email: "jane@example.com", showName: true },
      });
      expect(w.vm.popoverContent).not.toContain("Jane Doe");
    });

    it("includes role when provided", () => {
      const w = mount(UserBadge, {
        localVue,
        propsData: { name: "Jane Doe", email: "jane@example.com", role: "reviewer" },
      });
      expect(w.vm.popoverContent).toContain("reviewer");
    });

    it("omits role line when role is null", () => {
      const w = mount(UserBadge, {
        localVue,
        propsData: { name: "Jane Doe", email: "jane@example.com" },
      });
      expect(w.vm.popoverContent).not.toContain("Role:");
    });

    it("has no popover when no email, no role, and showName is true", () => {
      const w = mount(UserBadge, {
        localVue,
        propsData: { name: "Jane Doe", showName: true },
      });
      expect(w.vm.hasPopoverContent).toBe(false);
    });
  });

  describe("avatar rendering", () => {
    it("uses avatarUrl as src when provided", () => {
      const w = mount(UserBadge, {
        localVue,
        propsData: { name: "Jane", avatarUrl: "https://example.com/avatar.jpg" },
      });
      const img = w.find(".b-avatar img");
      expect(img.exists()).toBe(true);
      expect(img.attributes("src")).toBe("https://example.com/avatar.jpg");
    });

    it("renders b-avatar with secondary variant by default", () => {
      const w = mount(UserBadge, {
        localVue,
        propsData: { name: "Jane Doe" },
      });
      expect(w.find(".b-avatar").classes()).toContain("badge-secondary");
    });
  });

  describe("display name", () => {
    it("shows name next to avatar when inline layout", () => {
      const w = mount(UserBadge, {
        localVue,
        propsData: { name: "Jane Doe", email: "jane@example.com", showName: true },
      });
      expect(w.text()).toContain("Jane Doe");
    });

    it("hides name when showName is false", () => {
      const w = mount(UserBadge, {
        localVue,
        propsData: { name: "Jane Doe", showName: false },
      });
      const textOutsideAvatar = w.find(".user-badge__name");
      expect(textOutsideAvatar.exists()).toBe(false);
    });
  });
});
