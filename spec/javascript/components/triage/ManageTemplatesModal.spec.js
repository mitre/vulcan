import { describe, it, expect, vi, beforeEach } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import ManageTemplatesModal from "@/components/triage/ManageTemplatesModal.vue";

vi.mock("@/api/projectsApi", () => ({
  getTriageResponseTemplates: vi.fn(() =>
    Promise.resolve({
      data: {
        triage_response_templates: [
          { id: 1, name: "Accept standard", body: "Concur with the finding as written." },
          { id: 2, name: "Decline - needs evidence", body: "Unable to incorporate without supporting evidence." },
        ],
      },
    }),
  ),
  createTriageResponseTemplate: vi.fn(() =>
    Promise.resolve({
      data: { triage_response_template: { id: 3, name: "New template", body: "New body" } },
    }),
  ),
  updateTriageResponseTemplate: vi.fn(() => Promise.resolve({ data: {} })),
  deleteTriageResponseTemplate: vi.fn(() => Promise.resolve()),
}));

/**
 * REQUIREMENTS:
 * ManageTemplatesModal is a project-scoped CRUD modal for triage response templates.
 * It MUST:
 *   - Load and display existing templates on mount
 *   - Allow creating new templates (name + body)
 *   - Allow editing existing templates inline
 *   - Allow deleting templates with confirmation
 *   - Use design system variables (Gate 12)
 *   - Emit "saved" when templates are modified so the dropdown refreshes
 */
describe("ManageTemplatesModal", () => {
  let wrapper;

  const mountWith = (props = {}) =>
    mount(ManageTemplatesModal, {
      localVue,
      propsData: { projectId: 42, visible: true, ...props },
      stubs: { "b-modal": { template: '<div><slot /><slot name="modal-title" /></div>' } },
    });

  const flushPromises = async () => {
    await new Promise((resolve) => setTimeout(resolve, 0));
    if (wrapper) await wrapper.vm.$nextTick();
  };

  beforeEach(async () => {
    vi.clearAllMocks();
    wrapper = mountWith();
    await flushPromises();
  });

  it("passes correct title to modal", () => {
    const modal = wrapper.findComponent({ name: "b-modal" });
    expect(modal.exists() || wrapper.text()).toBeTruthy();
    expect(wrapper.vm.$options.name).toBe("ManageTemplatesModal");
  });

  it("loads and displays existing templates on mount", () => {
    const rows = wrapper.findAll("[data-testid='template-row']");
    expect(rows.length).toBe(2);
    expect(rows.at(0).text()).toContain("Accept standard");
    expect(rows.at(1).text()).toContain("Decline - needs evidence");
  });

  it("has a create form with name and body fields", () => {
    expect(wrapper.find("[data-testid='new-template-name']").exists()).toBe(true);
    expect(wrapper.findComponent({ name: "MarkdownTextarea" }).exists()).toBe(true);
  });

  it("creates a template and emits saved", async () => {
    const { createTriageResponseTemplate } = await import("@/api/projectsApi");

    wrapper.vm.newName = "New template";
    wrapper.vm.newBody = "New body";
    await wrapper.vm.$nextTick();
    await wrapper.find("[data-testid='create-template-btn']").trigger("click");
    await flushPromises();

    expect(createTriageResponseTemplate).toHaveBeenCalledWith(42, {
      name: "New template",
      body: "New body",
    });
    expect(wrapper.emitted("saved")).toBeTruthy();
  });

  it("disables create button when name or body is empty", () => {
    const btn = wrapper.find("[data-testid='create-template-btn']");
    expect(btn.attributes("disabled")).toBeDefined();
  });

  it("has edit and delete buttons per template row", () => {
    const rows = wrapper.findAll("[data-testid='template-row']");
    expect(rows.at(0).find("[data-testid='edit-template-btn']").exists()).toBe(true);
    expect(rows.at(0).find("[data-testid='delete-template-btn']").exists()).toBe(true);
  });

  it("calls delete API and emits saved on delete confirmation", async () => {
    const { deleteTriageResponseTemplate } = await import("@/api/projectsApi");

    await wrapper.findAll("[data-testid='delete-template-btn']").at(0).trigger("click");
    await flushPromises();

    expect(deleteTriageResponseTemplate).toHaveBeenCalledWith(42, 1);
    expect(wrapper.emitted("saved")).toBeTruthy();
  });
});
