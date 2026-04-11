/**
 * UpdateComponentDetailsModal — vue-multiselect migration test
 *
 * REQUIREMENT: PoC user search uses vue-multiselect (not vue-simple-suggest)
 * to avoid the process is not defined runtime error.
 */
import { describe, it, expect, afterEach } from "vitest";
import { shallowMount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import UpdateComponentDetailsModal from "@/components/components/UpdateComponentDetailsModal.vue";

describe("UpdateComponentDetailsModal", () => {
  let wrapper;

  const createWrapper = (props = {}) => {
    return shallowMount(UpdateComponentDetailsModal, {
      localVue,
      propsData: {
        component: {
          id: 1,
          name: "Test Component",
          version: 1,
          release: 1,
          title: "Test STIG",
          description: "Test",
          prefix: "TST-01",
          admin_name: "Demo Admin",
          admin_email: "admin@example.com",
        },
        ...props,
      },
      stubs: {
        VueMultiselect: {
          template: '<div class="vue-multiselect-stub" />',
          props: ["options", "label", "trackBy", "placeholder", "searchable"],
          model: { prop: "value", event: "input" },
        },
      },
    });
  };

  afterEach(() => {
    if (wrapper) wrapper.destroy();
  });

  it("uses vue-multiselect for PoC search (not vue-simple-suggest)", () => {
    wrapper = createWrapper();
    expect(wrapper.find(".vue-multiselect-stub").exists()).toBe(true);
    expect(wrapper.find(".vue-simple-suggest").exists()).toBe(false);
  });

  it("setComponentPoc sets admin_name and admin_email", () => {
    wrapper = createWrapper();
    wrapper.vm.setComponentPoc({ name: "Bob User", email: "bob@example.com" });
    expect(wrapper.vm.admin_name).toBe("Bob User");
    expect(wrapper.vm.admin_email).toBe("bob@example.com");
  });
});
