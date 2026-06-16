import Vue from "vue";
import { BootstrapVue, IconsPlugin } from "bootstrap-vue";
import { PiniaVuePlugin, createPinia } from "pinia";
import { bvConfig } from "../config/bootstrapVueConfig";

Vue.use(PiniaVuePlugin);
Vue.use(BootstrapVue, bvConfig);
Vue.use(IconsPlugin);

const sharedPinia = createPinia();

export { sharedPinia };

export function createVulcanApp({ el, componentName, component, directives, router }) {
  if (component) {
    Vue.component(componentName, component);
  }
  if (directives) {
    Object.entries(directives).forEach(([name, dir]) => {
      Vue.directive(name, dir);
    });
  }

  const targetEl = document.querySelector(el);
  if (!targetEl) return null;

  const options = { el, pinia: sharedPinia };
  if (router) {
    options.router = router;
  }

  return new Vue(options);
}
