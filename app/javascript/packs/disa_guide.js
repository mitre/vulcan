import TurbolinksAdapter from "vue-turbolinks";
import Vue from "vue";
import { BootstrapVue, IconsPlugin } from "bootstrap-vue";
import { bvConfig } from "../config/bootstrapVueConfig";
import DisaGuidePage from "../components/disa_guide/DisaGuidePage.vue";

Vue.use(TurbolinksAdapter);
Vue.use(BootstrapVue, bvConfig);
Vue.use(IconsPlugin);

Vue.component("disa-guide-page", DisaGuidePage);

document.addEventListener("turbolinks:load", () => {
  const el = document.getElementById("disa-guide");
  if (el) {
    new Vue({ el });
  }
});
