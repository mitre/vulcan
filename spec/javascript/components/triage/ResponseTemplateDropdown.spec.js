import { describe, it, expect, vi, beforeEach } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import ResponseTemplateDropdown from "@/components/triage/ResponseTemplateDropdown.vue";
import { getTriageResponseTemplates } from "@/api/projectsApi";

vi.mock("@/api/projectsApi", () => ({
  getTriageResponseTemplates: vi.fn(() =>
    Promise.resolve({ data: { triage_response_templates: [] } }),
  ),
}));

const flush = async (w) => {
  await new Promise((r) => setTimeout(r, 0));
  await w.vm.$nextTick();
};

describe("ResponseTemplateDropdown", () => {
  const templates = [
    { id: 1, name: "Generalize text", body: "We'll generalize the check and fix text." },
    { id: 2, name: "No change required", body: "We acknowledge — no change required." },
  ];

  beforeEach(() => {
    getTriageResponseTemplates.mockReset();
    getTriageResponseTemplates.mockResolvedValue({
      data: { triage_response_templates: templates },
    });
  });

  it("renders nothing when no projectId is provided", () => {
    const w = mount(ResponseTemplateDropdown, { localVue, propsData: {} });
    expect(w.find('[data-testid="template-picker"]').exists()).toBe(false);
  });

  it("fetches templates on mount when projectId is given", async () => {
    const w = mount(ResponseTemplateDropdown, { localVue, propsData: { projectId: 42 } });
    await flush(w);
    expect(getTriageResponseTemplates).toHaveBeenCalledWith(42);
    expect(w.vm.templates).toHaveLength(2);
  });

  it("emits insert with the template body when a template is selected", async () => {
    const w = mount(ResponseTemplateDropdown, { localVue, propsData: { projectId: 42 } });
    await flush(w);
    w.vm.onSelect(templates[1]);
    expect(w.emitted("insert")).toBeTruthy();
    expect(w.emitted("insert")[0][0]).toBe("We acknowledge — no change required.");
  });

  it("emits insert with the first template body", async () => {
    const w = mount(ResponseTemplateDropdown, { localVue, propsData: { projectId: 42 } });
    await flush(w);
    w.vm.onSelect(templates[0]);
    expect(w.emitted("insert")[0][0]).toBe("We'll generalize the check and fix text.");
  });

  it("does not emit insert when templates are empty", async () => {
    getTriageResponseTemplates.mockResolvedValue({
      data: { triage_response_templates: [] },
    });
    const w = mount(ResponseTemplateDropdown, { localVue, propsData: { projectId: 42 } });
    await flush(w);
    expect(w.vm.templates).toHaveLength(0);
    expect(w.emitted("insert")).toBeFalsy();
  });
});
