import { mount } from "@vue/test-utils";
import { describe, it, expect, vi } from "vitest";
import { localVue } from "@test/testHelper";
import App from "@/components/navbar/App.vue";
import { EVENTS, dispatch } from "@/utils/notificationEvents";

// Stub fetch for version check
globalThis.fetch = vi.fn(() =>
  Promise.resolve({ json: () => Promise.resolve({ tag_name: "v0.0.0" }) }),
);

const baseProps = {
  navigation: [],
  signed_in: true,
  users_path: "/users",
  profile_path: "/profile",
  sign_out_path: "/sign_out",
  access_requests: [],
  locked_users: [],
};

describe("Navbar locked user notifications", () => {
  it("shows locked user count in badge when locked_users present", () => {
    const wrapper = mount(App, {
      localVue,
      propsData: {
        ...baseProps,
        locked_users: [{ id: 1, name: "Locked User", email: "locked@example.com" }],
      },
    });
    // Badge should show combined count (access_requests + locked_users)
    const badge = wrapper.find(".badge-danger");
    expect(badge.exists()).toBe(true);
    expect(badge.text()).toBe("1");
  });

  it("shows locked user notification in dropdown", () => {
    const wrapper = mount(App, {
      localVue,
      propsData: {
        ...baseProps,
        locked_users: [{ id: 7, name: "Elinore Homenick", email: "elinore@example.com" }],
      },
    });
    const html = wrapper.html();
    expect(html).toContain("Elinore Homenick");
    expect(html).toContain("locked");
  });

  it("combines access_requests and locked_users in badge count", () => {
    const wrapper = mount(App, {
      localVue,
      propsData: {
        ...baseProps,
        access_requests: [
          { project_id: 1, user: { name: "Requester" }, project: { name: "Proj" } },
        ],
        locked_users: [{ id: 1, name: "Locked", email: "locked@example.com" }],
      },
    });
    const badge = wrapper.find(".badge-danger");
    expect(badge.exists()).toBe(true);
    expect(badge.text()).toBe("2");
  });

  it("does not show badge when no notifications exist", () => {
    const wrapper = mount(App, {
      localVue,
      propsData: {
        ...baseProps,
        access_requests: [],
        locked_users: [],
      },
    });
    const badge = wrapper.find(".badge-danger");
    expect(badge.exists()).toBe(false);
  });

  it("adds locked user on LOCKOUT_CHANGED (locked)", async () => {
    const wrapper = mount(App, {
      localVue,
      propsData: { ...baseProps, locked_users: [] },
    });
    expect(wrapper.vm.localLockedUsers).toHaveLength(0);

    dispatch(EVENTS.LOCKOUT_CHANGED, {
      action: "locked",
      user: { id: 5, name: "New Lock", email: "new@example.com" },
    });
    await wrapper.vm.$nextTick();

    expect(wrapper.vm.localLockedUsers).toHaveLength(1);
    expect(wrapper.vm.localLockedUsers[0].id).toBe(5);
  });

  it("removes locked user on LOCKOUT_CHANGED (unlocked)", async () => {
    const wrapper = mount(App, {
      localVue,
      propsData: {
        ...baseProps,
        locked_users: [{ id: 5, name: "Locked", email: "locked@example.com" }],
      },
    });
    expect(wrapper.vm.localLockedUsers).toHaveLength(1);

    dispatch(EVENTS.LOCKOUT_CHANGED, {
      action: "unlocked",
      user: { id: 5, name: "Locked", email: "locked@example.com" },
    });
    await wrapper.vm.$nextTick();

    expect(wrapper.vm.localLockedUsers).toHaveLength(0);
  });

  it("links locked user notification to /users?unlock=id", () => {
    const wrapper = mount(App, {
      localVue,
      propsData: {
        ...baseProps,
        locked_users: [{ id: 7, name: "Locked User", email: "locked@example.com" }],
      },
    });
    const items = wrapper.findAll(".dropdown-item");
    const lockedItem = items.wrappers.find((w) => w.text().includes("locked"));
    expect(lockedItem).toBeTruthy();
    expect(lockedItem.attributes("href")).toBe("/users?unlock=7");
  });
});

describe("Navbar access request reactivity", () => {
  it("initializes localAccessRequests from prop", () => {
    const requests = [
      { id: 10, project_id: 1, user: { name: "Requester" }, project: { name: "Proj" } },
    ];
    const wrapper = mount(App, {
      localVue,
      propsData: { ...baseProps, access_requests: requests },
    });
    expect(wrapper.vm.localAccessRequests).toHaveLength(1);
    expect(wrapper.vm.localAccessRequests[0].id).toBe(10);
  });

  it("removes access request on ACCESS_REQUEST_CHANGED (resolved)", async () => {
    const requests = [
      { id: 10, project_id: 1, user: { name: "Requester" }, project: { name: "Proj" } },
      { id: 11, project_id: 2, user: { name: "Other" }, project: { name: "Proj2" } },
    ];
    const wrapper = mount(App, {
      localVue,
      propsData: { ...baseProps, access_requests: requests },
    });
    expect(wrapper.vm.notificationCount).toBe(2);

    dispatch(EVENTS.ACCESS_REQUEST_CHANGED, { action: "resolved", id: 10 });
    await wrapper.vm.$nextTick();

    expect(wrapper.vm.localAccessRequests).toHaveLength(1);
    expect(wrapper.vm.localAccessRequests[0].id).toBe(11);
    expect(wrapper.vm.notificationCount).toBe(1);
  });

  it("decrements badge count when access request resolved", async () => {
    const requests = [
      { id: 10, project_id: 1, user: { name: "Requester" }, project: { name: "Proj" } },
    ];
    const wrapper = mount(App, {
      localVue,
      propsData: { ...baseProps, access_requests: requests },
    });
    const badge = wrapper.find(".badge-danger");
    expect(badge.text()).toBe("1");

    dispatch(EVENTS.ACCESS_REQUEST_CHANGED, { action: "resolved", id: 10 });
    await wrapper.vm.$nextTick();

    expect(wrapper.find(".badge-danger").exists()).toBe(false);
  });
});
