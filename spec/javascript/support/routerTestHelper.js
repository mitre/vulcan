import VueRouter from "vue-router";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";

localVue.use(VueRouter);

export function createTestRouter(routes) {
  return new VueRouter({
    mode: "abstract",
    routes: routes || [{ path: "/", name: "test-root" }],
  });
}

export function mountWithRouter(component, options = {}) {
  const { routes, ...mountOptions } = options;
  const router = createTestRouter(routes);

  const wrapper = mount(component, {
    localVue,
    router,
    ...mountOptions,
  });

  return { wrapper, router };
}
