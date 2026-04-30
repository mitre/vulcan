import { describe, it, expect, vi, beforeEach } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import axios from "axios";
import CommentTriageModal from "@/components/components/CommentTriageModal.vue";

vi.mock("axios");

const flushPromises = async (wrapper) => {
  await new Promise((resolve) => setTimeout(resolve, 0));
  if (wrapper) await wrapper.vm.$nextTick();
};

// b-modal in BootstrapVue renders to a portal and stays empty until shown,
// so for body-content assertions we stub it with a div that always renders
// its default + modal-footer slots. Same pattern as ConfirmDeleteModal.spec.js.
// `centered` is exposed so we can assert vertical-centering at the template
// level (Aaron 2026-04-29 — visual parity with CommentComposerModal).
const visibleModalStub = {
  "b-modal": {
    template: `
      <div class="modal" :data-centered="String(centered)">
        <div class="modal-body"><slot></slot></div>
        <div class="modal-footer"><slot name="modal-footer" :cancel="() => {}"></slot></div>
      </div>
    `,
    props: {
      title: String,
      centered: { type: Boolean, default: false },
    },
  },
};

const sampleReview = {
  id: 142,
  rule_id: 7,
  rule_displayed_name: "CRI-O-000050",
  section: "check_content",
  author_name: "John Doe",
  author_email: "john@redhat.com",
  comment: "Check text mentions runc 1.0...",
  created_at: "2026-04-27T10:00:00Z",
  triage_status: "pending",
  adjudicated_at: null,
};

describe("CommentTriageModal", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("renders the comment + section context", () => {
    const w = mount(CommentTriageModal, {
      localVue,
      propsData: { review: sampleReview },
      stubs: visibleModalStub,
    });
    const html = w.html();
    expect(html).toContain("CRI-O-000050");
    expect(html).toContain("Check"); // friendly section label via SectionLabel
    expect(html).toContain("John Doe");
  });

  it("shows decision radios with friendly label + DISA term in parens (the pedagogical exception)", () => {
    const w = mount(CommentTriageModal, {
      localVue,
      propsData: { review: sampleReview },
      stubs: visibleModalStub,
    });
    const html = w.html();
    expect(html).toMatch(/Accept[^<]*Concur\)/);
    expect(html).toMatch(/Decline[^<]*Non-concur\)/);
  });

  it("requires response_comment when triage_status=non_concur (client-side gate)", () => {
    const w = mount(CommentTriageModal, {
      localVue,
      propsData: { review: sampleReview },
    });
    w.vm.triageStatus = "non_concur";
    w.vm.responseComment = "";
    expect(w.vm.canSave).toBe(false);
    w.vm.responseComment = "we already addressed differently";
    expect(w.vm.canSave).toBe(true);
  });

  it("requires duplicate_of_review_id when triage_status=duplicate", () => {
    const w = mount(CommentTriageModal, {
      localVue,
      propsData: { review: sampleReview },
    });
    w.vm.triageStatus = "duplicate";
    w.vm.duplicateOfId = null;
    expect(w.vm.canSave).toBe(false);
    w.vm.duplicateOfId = 99;
    expect(w.vm.canSave).toBe(true);
  });

  it("posts to /reviews/:id/triage on Save decision", async () => {
    axios.patch.mockResolvedValue({
      data: { review: { ...sampleReview, triage_status: "concur" } },
    });
    const w = mount(CommentTriageModal, {
      localVue,
      propsData: { review: sampleReview },
    });
    vi.spyOn(w.vm.$bvModal, "hide").mockImplementation(() => {});

    w.vm.triageStatus = "concur";
    w.vm.responseComment = "thanks";
    await w.vm.saveTriage(false);
    await flushPromises(w);

    expect(axios.patch).toHaveBeenCalledWith(
      "/reviews/142/triage",
      expect.objectContaining({ triage_status: "concur", response_comment: "thanks" }),
    );
    expect(w.emitted("triaged")).toBeTruthy();
  });

  it("'Save & close' fires triage AND adjudicate atomically", async () => {
    axios.patch
      .mockResolvedValueOnce({
        data: { review: { ...sampleReview, triage_status: "concur" } },
      })
      .mockResolvedValueOnce({
        data: {
          review: { ...sampleReview, triage_status: "concur", adjudicated_at: "2026-04-29T12:00Z" },
        },
      });
    const w = mount(CommentTriageModal, {
      localVue,
      propsData: { review: sampleReview },
    });
    vi.spyOn(w.vm.$bvModal, "hide").mockImplementation(() => {});

    w.vm.triageStatus = "concur";
    w.vm.responseComment = "done";
    await w.vm.saveTriage(true);
    await flushPromises(w);

    expect(axios.patch).toHaveBeenCalledTimes(2);
    expect(axios.patch.mock.calls[1][0]).toBe("/reviews/142/adjudicate");
    expect(w.emitted("adjudicated")).toBeTruthy();
  });

  it("disables 'Save & close' for terminal-by-rule statuses (informational, duplicate, needs_clarification, withdrawn)", () => {
    const w = mount(CommentTriageModal, {
      localVue,
      propsData: { review: sampleReview },
    });
    ["informational", "duplicate", "needs_clarification", "withdrawn"].forEach((status) => {
      w.vm.triageStatus = status;
      expect(w.vm.canSaveAndClose).toBe(false);
    });
    w.vm.triageStatus = "concur";
    expect(w.vm.canSaveAndClose).toBe(true);
  });

  it("surfaces server errors via AlertMixin without crashing", async () => {
    axios.patch.mockRejectedValueOnce({ response: { status: 422, data: {} } });
    const w = mount(CommentTriageModal, {
      localVue,
      propsData: { review: sampleReview },
    });
    const alertSpy = vi.spyOn(w.vm, "alertOrNotifyResponse").mockImplementation(() => {});

    w.vm.triageStatus = "concur";
    await w.vm.saveTriage(false);
    await flushPromises(w);

    expect(alertSpy).toHaveBeenCalled();
    alertSpy.mockRestore();
  });

  // Vertical centering — visual parity with CommentComposerModal,
  // requested by Aaron 2026-04-29.
  it("sets centered=true on the b-modal so it sits in the middle of the viewport", () => {
    const w = mount(CommentTriageModal, {
      localVue,
      propsData: { review: sampleReview },
      stubs: visibleModalStub,
    });
    expect(w.find(".modal").attributes("data-centered")).toBe("true");
  });
});
