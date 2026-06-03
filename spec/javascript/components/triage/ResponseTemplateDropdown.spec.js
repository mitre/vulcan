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
  beforeEach(() => {
    getTriageResponseTemplates.mockReset();
    getTriageResponseTemplates.mockResolvedValue({
      data: {
        triage_response_templates: [
          { id: 1, name: "Generalize text", body: "We'll generalize the check and fix text." },
          { id: 2, name: "No change required", body: "We acknowledge — no change required." },
        ],
      },
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

  it("emits insert with the template body when a template is picked", async () => {
    const w = mount(ResponseTemplateDropdown, { localVue, propsData: { projectId: 42 } });
    await flush(w);
    const target = w.vm.templates.find((t) => t.id === 2);
    w.vm.onSelect(target);
    expect(w.emitted("insert")).toBeTruthy();
    expect(w.emitted("insert")[0][0]).toBe("We acknowledge — no change required.");
  });
});
