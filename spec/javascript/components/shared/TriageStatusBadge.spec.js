import { describe, it, expect } from "vitest";
import { mount } from "@vue/test-utils";
import TriageStatusBadge from "@/components/shared/TriageStatusBadge.vue";

describe("TriageStatusBadge", () => {
  it("renders glyph + friendly label for concur", () => {
    const w = mount(TriageStatusBadge, { propsData: { status: "concur" } });
    expect(w.text()).toContain("Accept");
    expect(w.text()).toContain("●");
  });

  it("renders 'Closed (Accept)' when adjudicatedAt is present and status is concur", () => {
    const w = mount(TriageStatusBadge, {
      propsData: { status: "concur", adjudicatedAt: "2026-04-29T10:00:00Z" },
    });
    expect(w.text()).toContain("Closed");
    expect(w.text()).toContain("Accept");
  });

  it("marks the glyph aria-hidden so screen readers don't announce it", () => {
    const w = mount(TriageStatusBadge, { propsData: { status: "concur" } });
    const glyphEl = w.find("[data-test=glyph]");
    expect(glyphEl.attributes("aria-hidden")).toBe("true");
  });

  it("provides DISA tooltip on hover", () => {
    const w = mount(TriageStatusBadge, { propsData: { status: "non_concur" } });
    const root = w.find("[data-test=badge]");
    expect(root.attributes("title")).toMatch(/non.concur/i);
  });

  it("uses stable DISA key as CSS class hook", () => {
    const w = mount(TriageStatusBadge, {
      propsData: { status: "concur_with_comment" },
    });
    expect(w.find(".triage-status--concur_with_comment").exists()).toBe(true);
  });

  it("renders 'Duplicate of #N' when status=duplicate and duplicateOfId given", () => {
    const w = mount(TriageStatusBadge, {
      propsData: { status: "duplicate", duplicateOfId: 142 },
    });
    expect(w.text()).toContain("Duplicate of #142");
  });
});
