import Vue from "vue";
import TurbolinksAdapter from "vue-turbolinks";
import { BootstrapVue, IconsPlugin } from "bootstrap-vue";
import { PiniaVuePlugin, createPinia } from "pinia";
import { bvConfig } from "../config/bootstrapVueConfig";

Vue.use(PiniaVuePlugin);
Vue.use(TurbolinksAdapter);
Vue.use(BootstrapVue, bvConfig);
Vue.use(IconsPlugin);

export function createVulcanApp({ el, componentName, component, directives }) {
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

  return new Vue({ el, pinia: createPinia() });
}
