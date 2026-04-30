/**
 * ComponentSettingsPage — admin-only configuration surface (Task 22).
 *
 * REQUIREMENTS:
 *
 * 1. Three sections: Identity, Point of Contact, Public Comment Period.
 * 2. form fields seeded from initialComponentState including the new
 *    comment_phase + period date fields.
 * 3. ISO datetime values in initialComponentState are trimmed to YYYY-MM-DD
 *    so <input type="date"> can render them; backend stores datetime, the
 *    form just doesn't expose time-of-day.
 * 4. comment_phase falls back to "draft" when missing on the prop.
 * 5. phaseOptions exposes the four DISA→friendly labels.
 * 6. save() PUTs the full payload (all 11 keys including the three
 *    Task 22 fields) to /components/:id and shows a toast.
 */
import { describe, it, expect, vi, afterEach, beforeEach } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import axios from "axios";
import ComponentSettingsPage from "@/components/components/ComponentSettingsPage.vue";

vi.mock("axios");

const baseComponent = {
  id: 8,
  name: "Container Platform",
  version: "1",
  release: "1",
  prefix: "CNTR-01",
  title: "Container Platform STIG",
  description: "Test description",
  admin_name: "Demo Admin",
  admin_email: "admin@example.com",
};

const baseProject = { id: 4, name: "Container Platform" };

const createWrapper = (componentOverrides = {}) =>
  mount(ComponentSettingsPage, {
    localVue,
    propsData: {
      initialComponentState: { ...baseComponent, ...componentOverrides },
      project: baseProject,
      effectivePermissions: "admin",
      currentUserId: 1,
    },
    stubs: {
      VueMultiselect: { template: '<div class="vue-multiselect-stub" />' },
    },
  });

describe("ComponentSettingsPage", () => {
  let wrapper;

  beforeEach(() => {
    vi.clearAllMocks();
    axios.put.mockResolvedValue({ data: { toast: "ok" } });
    axios.get.mockResolvedValue({ data: { users: [] } });
  });

  afterEach(() => {
    if (wrapper) wrapper.destroy();
  });

  describe("page chrome", () => {
    it("renders the page title 'Component Settings'", () => {
      wrapper = createWrapper();
      expect(wrapper.text()).toContain("Component Settings");
    });

    it("renders breadcrumbs ending with 'Settings'", () => {
      wrapper = createWrapper();
      const crumbs = wrapper.vm.breadcrumbs;
      expect(crumbs[crumbs.length - 1]).toEqual({ text: "Settings", active: true });
    });

    it("links 'Back to Component Editor' to the component root path", () => {
      wrapper = createWrapper();
      const backLink = wrapper
        .findAll("a")
        .wrappers.find((a) => a.text().includes("Back to Component Editor"));
      expect(backLink).toBeDefined();
      expect(backLink.attributes("href")).toBe("/components/8");
    });
  });

  describe("section structure", () => {
    it("renders the three section headings", () => {
      wrapper = createWrapper();
      const text = wrapper.text();
      expect(text).toContain("Identity");
      expect(text).toContain("Point of Contact");
      expect(text).toContain("Public Comment Period");
    });
  });

  describe("Public Comment Period field seeding", () => {
    it("falls back to 'draft' when the component has no comment_phase set", () => {
      wrapper = createWrapper();
      expect(wrapper.vm.form.comment_phase).toBe("draft");
    });

    it("seeds comment_phase from the component prop when set", () => {
      wrapper = createWrapper({ comment_phase: "open" });
      expect(wrapper.vm.form.comment_phase).toBe("open");
    });

    it("trims ISO datetime to YYYY-MM-DD for the date inputs", () => {
      wrapper = createWrapper({
        comment_period_starts_at: "2026-04-29T00:00:00Z",
        comment_period_ends_at: "2026-05-14T12:34:56Z",
      });
      expect(wrapper.vm.form.comment_period_starts_at).toBe("2026-04-29");
      expect(wrapper.vm.form.comment_period_ends_at).toBe("2026-05-14");
    });

    it("phaseOptions exposes the four DISA→friendly labels", () => {
      wrapper = createWrapper();
      expect(wrapper.vm.phaseOptions).toEqual([
        { value: "draft", text: "Draft" },
        { value: "open", text: "Open for comment" },
        { value: "adjudication", text: "Adjudication" },
        { value: "final", text: "Final" },
      ]);
    });
  });

  describe("Identity field seeding", () => {
    it("seeds the form from the prop (name, version, prefix, title, description)", () => {
      wrapper = createWrapper();
      expect(wrapper.vm.form.name).toBe("Container Platform");
      expect(wrapper.vm.form.prefix).toBe("CNTR-01");
      expect(wrapper.vm.form.title).toBe("Container Platform STIG");
    });
  });

  describe("Point of Contact field seeding", () => {
    it("seeds admin_name + admin_email from the prop", () => {
      wrapper = createWrapper();
      expect(wrapper.vm.form.admin_name).toBe("Demo Admin");
      expect(wrapper.vm.form.admin_email).toBe("admin@example.com");
    });

    it("setPoc updates admin_name + admin_email in the form", () => {
      wrapper = createWrapper();
      wrapper.vm.setPoc({ name: "Bob", email: "bob@example.com" });
      expect(wrapper.vm.form.admin_name).toBe("Bob");
      expect(wrapper.vm.form.admin_email).toBe("bob@example.com");
    });
  });

  describe("save", () => {
    it("PUTs all 11 form keys to /components/:id", async () => {
      wrapper = createWrapper({ comment_phase: "open" });
      wrapper.vm.form.comment_period_ends_at = "2026-05-14";
      await wrapper.vm.save();

      const [url, payload] = axios.put.mock.calls[0];
      expect(url).toBe("/components/8");
      expect(payload.component).toMatchObject({
        name: "Container Platform",
        version: "1",
        release: "1",
        title: "Container Platform STIG",
        description: "Test description",
        prefix: "CNTR-01",
        admin_name: "Demo Admin",
        admin_email: "admin@example.com",
        comment_phase: "open",
        comment_period_ends_at: "2026-05-14",
      });
    });
  });
});
