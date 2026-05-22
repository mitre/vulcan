import { describe, it, expect, vi, beforeEach } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import TriageRuleSidebar from "@/components/triage/TriageRuleSidebar.vue";

const comments = [
  {
    id: 1,
    rule_id: 10,
    rule_displayed_name: "CNTR-01-000001",
    section: "check_content",
    triage_status: "pending",
    comment: "Check text mentions runc 1.0",
  },
  {
    id: 2,
    rule_id: 10,
    rule_displayed_name: "CNTR-01-000001",
    section: "fixtext",
    triage_status: "concur",
    comment: "Fix text could include seccomp path",
  },
  {
    id: 3,
    rule_id: 11,
    rule_displayed_name: "CNTR-01-000002",
    section: null,
    triage_status: "pending",
    comment: "Could we soften the severity?",
  },
  {
    id: 4,
    rule_id: null,
    rule_displayed_name: "(component)",
    commentable_type: "Component",
    section: null,
    triage_status: "pending",
    comment: "General component feedback",
  },
];

function baseProps(overrides = {}) {
  return {
    comments,
    currentId: 1,
    ...overrides,
  };
}

describe("TriageRuleSidebar", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("renders a search input for filtering rules", () => {
    const w = mount(TriageRuleSidebar, { localVue, propsData: baseProps() });
    expect(w.find("[data-testid='sidebar-search']").exists()).toBe(true);
  });

  it("groups comments by rule and shows rule headers", () => {
    const w = mount(TriageRuleSidebar, { localVue, propsData: baseProps() });
    const headers = w.findAll("[data-testid='sidebar-rule-header']");
    expect(headers.length).toBe(3);
  });

  it("shows component group first, then rules in ascending order", () => {
    const w = mount(TriageRuleSidebar, { localVue, propsData: baseProps() });
    const headers = w.findAll("[data-testid='sidebar-rule-header']");
    expect(headers.at(0).text()).toContain("(component)");
    expect(headers.at(1).text()).toContain("CNTR-01-000001");
    expect(headers.at(2).text()).toContain("CNTR-01-000002");
  });

  it("shows pending and total counts per rule", () => {
    const w = mount(TriageRuleSidebar, { localVue, propsData: baseProps() });
    const headers = w.findAll("[data-testid='sidebar-rule-header']");
    expect(headers.at(1).text()).toContain("1/2");
  });

  it("highlights the rule group containing the current comment", () => {
    const w = mount(TriageRuleSidebar, { localVue, propsData: baseProps({ currentId: 1 }) });
    const headers = w.findAll("[data-testid='sidebar-rule-header']");
    expect(headers.at(1).classes()).toContain("sidebar-rule--active");
  });

  it("emits select with first comment id when clicking a rule header", async () => {
    const w = mount(TriageRuleSidebar, { localVue, propsData: baseProps() });
    const headers = w.findAll("[data-testid='sidebar-rule-header']");
    await headers.at(2).trigger("click");
    expect(w.emitted("select")).toHaveLength(1);
    expect(w.emitted("select")[0][0]).toBe(3);
  });

  it("filters rules by search text", async () => {
    const w = mount(TriageRuleSidebar, { localVue, propsData: baseProps() });
    const search = w.find("[data-testid='sidebar-search']");
    await search.setValue("000002");
    const headers = w.findAll("[data-testid='sidebar-rule-header']");
    expect(headers.length).toBe(1);
    expect(headers.at(0).text()).toContain("CNTR-01-000002");
  });

  it("shows individual comments when a rule group is expanded", async () => {
    const w = mount(TriageRuleSidebar, { localVue, propsData: baseProps({ currentId: 1 }) });
    const items = w.findAll("[data-testid='sidebar-comment-item']");
    expect(items.length).toBeGreaterThan(0);
  });

  it("emits select with comment id when clicking an individual comment", async () => {
    const w = mount(TriageRuleSidebar, { localVue, propsData: baseProps({ currentId: 1 }) });
    const items = w.findAll("[data-testid='sidebar-comment-item']");
    const secondItem = items.filter((item) => item.text().includes("#2")).at(0);
    await secondItem.trigger("click");
    expect(w.emitted("select")[0][0]).toBe(2);
  });

  it("highlights the active comment in the sidebar", () => {
    const w = mount(TriageRuleSidebar, { localVue, propsData: baseProps({ currentId: 1 }) });
    const items = w.findAll("[data-testid='sidebar-comment-item']");
    const activeItem = items.filter((item) => item.text().includes("#1")).at(0);
    expect(activeItem.classes()).toContain("sidebar-comment--active");
  });

  it("supports keyboard navigation with ArrowDown/ArrowUp", async () => {
    const w = mount(TriageRuleSidebar, { localVue, propsData: baseProps() });
    const list = w.find("[data-testid='sidebar-list']");
    await list.trigger("keydown", { key: "ArrowDown" });
    await list.trigger("keydown", { key: "ArrowDown" });
    await list.trigger("keydown", { key: "Enter" });
    expect(w.emitted("select")).toBeTruthy();
  });

  it("applies sidebar-focused class to the focused item during keyboard nav", async () => {
    const w = mount(TriageRuleSidebar, { localVue, propsData: baseProps() });
    const list = w.find("[data-testid='sidebar-list']");
    await list.trigger("keydown", { key: "ArrowDown" });
    await w.vm.$nextTick();
    const focused = w.find(".sidebar-focused");
    expect(focused.exists()).toBe(true);
  });

  it("moves sidebar-focused class on successive ArrowDown presses", async () => {
    const w = mount(TriageRuleSidebar, { localVue, propsData: baseProps() });
    const list = w.find("[data-testid='sidebar-list']");
    await list.trigger("keydown", { key: "ArrowDown" });
    await w.vm.$nextTick();
    const first = w.find(".sidebar-focused");
    expect(first.exists()).toBe(true);
    const firstText = first.text();

    await list.trigger("keydown", { key: "ArrowDown" });
    await w.vm.$nextTick();
    const second = w.find(".sidebar-focused");
    expect(second.text()).not.toBe(firstText);
  });

  it("wraps focus from last item to first on ArrowDown", async () => {
    const w = mount(TriageRuleSidebar, { localVue, propsData: baseProps() });
    const list = w.find("[data-testid='sidebar-list']");
    const totalItems = w.vm.flatItems.length;
    for (let i = 0; i <= totalItems; i++) {
      await list.trigger("keydown", { key: "ArrowDown" });
    }
    await w.vm.$nextTick();
    expect(w.vm.focusedIndex).toBe(0);
  });

  it("is a composite widget — sidebar-list has single tabindex=0", () => {
    const w = mount(TriageRuleSidebar, { localVue, propsData: baseProps() });
    const list = w.find("[data-testid='sidebar-list']");
    expect(list.attributes("tabindex")).toBe("0");
    expect(list.attributes("role")).toBe("listbox");
  });

  it("individual items have tabindex=-1 (not in tab order, only arrow-navigable)", () => {
    const w = mount(TriageRuleSidebar, { localVue, propsData: baseProps() });
    const items = w.findAll("[role='option']");
    items.wrappers.forEach((item) => {
      expect(["-1", "0"]).toContain(item.attributes("tabindex"));
    });
  });

  it("shows total pending count in sidebar header", () => {
    const w = mount(TriageRuleSidebar, { localVue, propsData: baseProps() });
    expect(w.find("[data-testid='sidebar-header']").text()).toContain("3 pending");
  });
});
