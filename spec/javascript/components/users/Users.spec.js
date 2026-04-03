import { mount } from "@vue/test-utils";
import { describe, it, expect, afterEach } from "vitest";
import { localVue } from "@test/testHelper";
import Users from "@/components/users/Users.vue";

const lockedUser = {
  id: 7,
  name: "Elinore Homenick",
  email: "elinore@example.com",
  provider: null,
  admin: false,
  locked_at: "2026-02-20T02:05:47.574Z",
  failed_attempts: 3,
};

const baseProps = {
  users: [
    {
      id: 1,
      name: "Admin",
      email: "admin@example.com",
      provider: null,
      admin: true,
      locked_at: null,
      failed_attempts: 0,
    },
    lockedUser,
  ],
  histories: [],
  smtpEnabled: false,
  passwordPolicy: null,
  lockoutEnabled: true,
};

describe("Users auto-open unlock modal", () => {
  afterEach(() => {
    // Reset URL
    globalThis.history.replaceState({}, "", globalThis.location.pathname);
  });

  it("auto-opens edit modal for user specified in ?unlock= param", async () => {
    // Set query param before mount
    globalThis.history.replaceState({}, "", "?unlock=7");

    const wrapper = mount(Users, {
      localVue,
      propsData: baseProps,
    });

    await wrapper.vm.$nextTick();

    expect(wrapper.vm.showEditModal).toBe(true);
    expect(wrapper.vm.selectedUser).toBeTruthy();
    expect(wrapper.vm.selectedUser.id).toBe(7);
  });

  it("does not auto-open modal when no unlock param", async () => {
    globalThis.history.replaceState({}, "", "?");

    const wrapper = mount(Users, {
      localVue,
      propsData: baseProps,
    });

    await wrapper.vm.$nextTick();

    expect(wrapper.vm.showEditModal).toBe(false);
    expect(wrapper.vm.selectedUser).toBeNull();
  });

  it("does not auto-open modal when unlock param references non-existent user", async () => {
    globalThis.history.replaceState({}, "", "?unlock=999");

    const wrapper = mount(Users, {
      localVue,
      propsData: baseProps,
    });

    await wrapper.vm.$nextTick();

    expect(wrapper.vm.showEditModal).toBe(false);
    expect(wrapper.vm.selectedUser).toBeNull();
  });
});
