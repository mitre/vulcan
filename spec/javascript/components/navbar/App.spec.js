import { mount } from "@vue/test-utils";
import { describe, it, expect, vi, beforeEach } from "vitest";
import { setActivePinia, createPinia } from "pinia";
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
  beforeEach(() => {
    setActivePinia(createPinia());
  });

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
        access_requests: [{ user: { name: "Requester" }, project: { id: 1, name: "Proj" } }],
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

describe("Navbar profile dropdown", () => {
  const userProps = (overrides = {}) => ({
    ...baseProps,
    current_user: { id: 42, name: "Casey Tester", email: "casey@example.com", ...overrides },
  });

  // REQUIREMENT: the utility nav (bell / theme toggle / user menu) never
  // collapses, so its dropdown menus must overlay the page content at EVERY
  // viewport width — not expand the navbar in-flow. Bootstrap only restores
  // dropdown position: absolute above the navbar's expand breakpoint (xl);
  // the .utility-nav hook re-applies Bootstrap's own expanded-navbar rule to
  // this always-expanded nav (the same rule the bare .navbar-expand pattern
  // on Bootstrap's docs site uses). jsdom loads no CSS, so this pins the
  // class hook; Playwright verifies the rendered behavior.
  it("marks the always-visible utility nav with the dropdown-overlay hook", () => {
    const wrapper = mount(App, { localVue, propsData: userProps() });
    const utilityNav = wrapper.find(".utility-nav");
    expect(utilityNav.exists()).toBe(true);
    // Both utility dropdowns (notifications + user menu) live inside it
    expect(utilityNav.findAll(".dropdown-menu").length).toBe(2);
  });

  it("shows the user's name next to the profile icon when current_user is provided", () => {
    const wrapper = mount(App, { localVue, propsData: userProps() });
    expect(wrapper.text()).toContain("Casey Tester");
  });

  it("falls back to email if name is missing", () => {
    const wrapper = mount(App, {
      localVue,
      propsData: userProps({ name: null }),
    });
    expect(wrapper.text()).toContain("casey@example.com");
  });

  it("renders the user's name + email at the top of the dropdown", () => {
    const wrapper = mount(App, { localVue, propsData: userProps() });
    const html = wrapper.html();
    expect(html).toContain("Casey Tester");
    expect(html).toContain("casey@example.com");
  });

  it("links 'My Comments' to /users/<id>/comments", () => {
    const wrapper = mount(App, { localVue, propsData: userProps() });
    const link = wrapper
      .findAll(".dropdown-item")
      .wrappers.find((w) => w.text().includes("My Comments"));
    expect(link).toBeDefined();
    expect(link.attributes("href")).toBe("/users/42/comments");
  });

  it("omits the My Comments item when current_user is not provided", () => {
    const wrapper = mount(App, { localVue, propsData: baseProps });
    const link = wrapper
      .findAll(".dropdown-item")
      .wrappers.find((w) => w.text().includes("My Comments"));
    expect(link).toBeUndefined();
  });
});

describe("Navbar access request link", () => {
  it("links access request notification to /projects/:id using project.id", () => {
    const wrapper = mount(App, {
      localVue,
      propsData: {
        ...baseProps,
        access_requests: [
          { id: 10, user: { name: "Jane Doe" }, project: { id: 42, name: "Container Platform" } },
        ],
      },
    });
    const items = wrapper.findAll(".dropdown-item");
    const arItem = items.wrappers.find((w) => w.text().includes("Jane Doe"));
    expect(arItem).toBeTruthy();
    expect(arItem.attributes("href")).toBe("/projects/42?members=1");
  });
});

describe("Navbar access request reactivity", () => {
  it("initializes localAccessRequests from prop", () => {
    const requests = [{ id: 10, user: { name: "Requester" }, project: { id: 1, name: "Proj" } }];
    const wrapper = mount(App, {
      localVue,
      propsData: { ...baseProps, access_requests: requests },
    });
    expect(wrapper.vm.localAccessRequests).toHaveLength(1);
    expect(wrapper.vm.localAccessRequests[0].id).toBe(10);
  });

  it("removes access request on ACCESS_REQUEST_CHANGED (resolved)", async () => {
    const requests = [
      { id: 10, user: { name: "Requester" }, project: { id: 1, name: "Proj" } },
      { id: 11, user: { name: "Other" }, project: { id: 2, name: "Proj2" } },
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
    const requests = [{ id: 10, user: { name: "Requester" }, project: { id: 1, name: "Proj" } }];
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

describe("Navbar non-signed-in (login page)", () => {
  const loginProps = { ...baseProps, signed_in: false };

  it("renders the dark mode toggle when not signed in", () => {
    const w = mount(App, { localVue, propsData: loginProps });
    const toggleNav = w
      .findAll(".navbar-nav")
      .wrappers.find((nav) => nav.find("[aria-label='Toggle dark mode']").exists());
    expect(toggleNav).toBeTruthy();
  });

  it("right-aligns the dark mode toggle with order-xl-last", () => {
    const w = mount(App, { localVue, propsData: loginProps });
    const toggleNav = w
      .findAll(".navbar-nav")
      .wrappers.find((nav) => nav.find("[aria-label='Toggle dark mode']").exists());
    expect(toggleNav.classes()).toContain("ml-auto");
    expect(toggleNav.classes()).toContain("order-xl-last");
  });
});

describe("Navbar dropdown viewport containment", () => {
  // The old tests here pinned boundary="viewport" — a NO-OP inside navbars:
  // BootstrapVue never instantiates Popper in a navbar (mixins/dropdown.js
  // "Only instantiate Popper.js when dropdown is not in <b-navbar>"), and
  // boundary only configures Popper. Containment is CSS: menus anchor to the
  // .utility-nav (li is position: static — Bootstrap's documented
  // dropdown-parent pattern) and are width-capped, so wide notification
  // menus cannot overflow the left viewport edge on small screens.
  it("keeps the bell badge anchored to the toggle link, not the li", () => {
    const w = mount(App, {
      localVue,
      propsData: {
        ...baseProps,
        access_requests: [{ user: { name: "Req" }, project: { id: 1, name: "P" } }],
      },
    });
    const dropdowns = w.findAllComponents({ name: "BNavItemDropdown" });
    const bellToggle = dropdowns.at(0).find(".nav-link");
    // The li must stay position: static (CSS) so the badge needs its
    // positioning context on the toggle link itself.
    expect(bellToggle.classes()).toContain("position-relative");
    expect(dropdowns.at(0).find(".badge-danger").exists()).toBe(true);
  });

  // ── mixin contract ──────────────────────────────────────────────────
  // REQUIREMENT: the navbar app carries no mixins at all. FormMixin was
  // verified dead — authenticityToken never referenced.
  it("declares no mixins", () => {
    expect(App.mixins).toBeUndefined();
  });
});
