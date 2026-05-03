/**
 * ComponentSettingsPage — admin-only configuration surface.
 *
 * Three sections: Identity, Point of Contact, Public Comment Period.
 * The comment-period card edits the open/closed phase + optional
 * closed_reason + optional comment_period_starts_at / ends_at dates.
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
    it("falls back to 'open' when the component has no comment_phase set", () => {
      wrapper = createWrapper();
      expect(wrapper.vm.form.comment_phase).toBe("open");
      expect(wrapper.vm.form.closed_reason).toBeNull();
    });

    it("seeds comment_phase + closed_reason from the prop", () => {
      wrapper = createWrapper({ comment_phase: "closed", closed_reason: "adjudicating" });
      expect(wrapper.vm.form.comment_phase).toBe("closed");
      expect(wrapper.vm.form.closed_reason).toBe("adjudicating");
    });

    it("trims ISO datetime to YYYY-MM-DD for the date inputs", () => {
      wrapper = createWrapper({
        comment_period_starts_at: "2026-04-29T00:00:00Z",
        comment_period_ends_at: "2026-05-14T12:34:56Z",
      });
      expect(wrapper.vm.form.comment_period_starts_at).toBe("2026-04-29");
      expect(wrapper.vm.form.comment_period_ends_at).toBe("2026-05-14");
    });

    it("phaseOptions exposes the two-value enum (open/closed)", () => {
      wrapper = createWrapper();
      expect(wrapper.vm.phaseOptions).toEqual([
        { value: "open", text: "Open" },
        { value: "closed", text: "Closed" },
      ]);
    });

    it("closedReasonOptions includes a null/none option plus the two reasons", () => {
      wrapper = createWrapper({ comment_phase: "closed" });
      const opts = wrapper.vm.closedReasonOptions;
      expect(opts[0].value).toBeNull();
      expect(opts.slice(1)).toEqual([
        { value: "adjudicating", text: "Adjudicating" },
        { value: "finalized", text: "Finalized" },
      ]);
    });

    it("clears closed_reason when phase flips to 'open'", () => {
      wrapper = createWrapper({ comment_phase: "closed", closed_reason: "adjudicating" });
      wrapper.vm.onPhaseChange("open");
      expect(wrapper.vm.form.closed_reason).toBeNull();
    });
  });

  describe("Identity field seeding", () => {
    it("seeds the form from the prop (name, prefix, title)", () => {
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
    it("PUTs all 12 form keys to /components/:id (including closed_reason)", async () => {
      wrapper = createWrapper({ comment_phase: "open" });
      wrapper.vm.form.comment_period_ends_at = "2026-05-14";
      await wrapper.vm.save();

      const [url, payload] = axios.put.mock.calls[0];
      expect(url).toBe("/components/8");
      expect(payload.component).toMatchObject({
        name: "Container Platform",
        prefix: "CNTR-01",
        comment_phase: "open",
        closed_reason: null,
        comment_period_ends_at: "2026-05-14",
      });
    });
  });

  describe("confirm-modal on closed+finalized regression", () => {
    const finalizedProps = { comment_phase: "closed", closed_reason: "finalized" };

    it("shows a confirmation prompt when reopening from closed+finalized", async () => {
      wrapper = createWrapper(finalizedProps);
      wrapper.vm.$bvModal.msgBoxConfirm = vi.fn().mockResolvedValue(true);
      wrapper.vm.form.comment_phase = "open";
      wrapper.vm.form.closed_reason = null;
      await wrapper.vm.save();

      expect(wrapper.vm.$bvModal.msgBoxConfirm).toHaveBeenCalled();
      const [message] = wrapper.vm.$bvModal.msgBoxConfirm.mock.calls[0];
      expect(message).toMatch(/reopen|disposition/i);
    });

    it("aborts the save when the user cancels the confirmation", async () => {
      wrapper = createWrapper(finalizedProps);
      wrapper.vm.$bvModal.msgBoxConfirm = vi.fn().mockResolvedValue(false);
      wrapper.vm.form.comment_phase = "open";
      wrapper.vm.form.closed_reason = null;
      await wrapper.vm.save();

      expect(axios.put).not.toHaveBeenCalled();
    });

    it("proceeds with the save when the user confirms", async () => {
      wrapper = createWrapper(finalizedProps);
      wrapper.vm.$bvModal.msgBoxConfirm = vi.fn().mockResolvedValue(true);
      wrapper.vm.form.comment_phase = "open";
      wrapper.vm.form.closed_reason = null;
      await wrapper.vm.save();

      expect(axios.put).toHaveBeenCalled();
      expect(axios.put.mock.calls[0][1].component.comment_phase).toBe("open");
    });

    it("does NOT show the confirmation when the phase is unchanged", async () => {
      wrapper = createWrapper(finalizedProps);
      wrapper.vm.$bvModal.msgBoxConfirm = vi.fn().mockResolvedValue(true);
      // form still closed+finalized — admin only changing PoC fields say
      await wrapper.vm.save();

      expect(wrapper.vm.$bvModal.msgBoxConfirm).not.toHaveBeenCalled();
      expect(axios.put).toHaveBeenCalled();
    });

    it("does NOT show the confirmation moving from closed+adjudicating to open", async () => {
      // adjudicating wasn't the frozen-for-writes state, so no reopen risk
      wrapper = createWrapper({ comment_phase: "closed", closed_reason: "adjudicating" });
      wrapper.vm.$bvModal.msgBoxConfirm = vi.fn().mockResolvedValue(true);
      wrapper.vm.form.comment_phase = "open";
      wrapper.vm.form.closed_reason = null;
      await wrapper.vm.save();

      expect(wrapper.vm.$bvModal.msgBoxConfirm).not.toHaveBeenCalled();
      expect(axios.put).toHaveBeenCalled();
    });
  });
});
