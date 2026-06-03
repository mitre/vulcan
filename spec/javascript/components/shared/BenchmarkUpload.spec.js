import { describe, it, expect, afterEach, vi, beforeEach } from "vitest";
import { shallowMount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import BenchmarkUpload from "@/components/shared/BenchmarkUpload.vue";

vi.mock("@/api/baseApi", () => ({
  default: {
    get: vi.fn(() => Promise.resolve({ data: {} })),
    post: vi.fn(() => Promise.resolve({ data: {} })),
    put: vi.fn(() => Promise.resolve({ data: {} })),
    patch: vi.fn(() => Promise.resolve({ data: {} })),
    delete: vi.fn(() => Promise.resolve({ data: {} })),
    defaults: { headers: { common: {} } },
  },
}));

vi.mock("@/api/projectsApi", () => ({
  uploadBenchmark: vi.fn(() => Promise.resolve({ data: {} })),
}));

describe("BenchmarkUpload", () => {
  let wrapper;

  const createWrapper = (props = {}) => {
    return shallowMount(BenchmarkUpload, {
      localVue,
      propsData: {
        value: false,
        post_path: "/srgs",
        ...props,
      },
      stubs: {
        BModal: { template: "<div><slot /><slot name='modal-footer' /></div>", methods: { show: vi.fn(), hide: vi.fn() } },
        BButton: true,
        BSpinner: true,
      },
    });
  };

  beforeEach(() => vi.resetAllMocks());
  afterEach(() => { if (wrapper) wrapper.destroy(); });

  it("submitUpload calls uploadBenchmark with path and formData", async () => {
    const { uploadBenchmark } = await import("@/api/projectsApi");
    uploadBenchmark.mockResolvedValueOnce({ data: {} });

    wrapper = createWrapper();
    wrapper.vm.file = new File(["content"], "test.xml");
    wrapper.vm.submitUpload();

    expect(uploadBenchmark).toHaveBeenCalledWith("/srgs", expect.any(FormData));
  });

  it("uses default path /srgs when post_path not provided", async () => {
    const { uploadBenchmark } = await import("@/api/projectsApi");
    uploadBenchmark.mockResolvedValueOnce({ data: {} });

    wrapper = createWrapper({ post_path: null });
    wrapper.vm.file = new File(["content"], "test.xml");
    wrapper.vm.submitUpload();

    expect(uploadBenchmark).toHaveBeenCalledWith("/srgs", expect.any(FormData));
  });
});
