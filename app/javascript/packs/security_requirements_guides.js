import TurbolinksAdapter from "vue-turbolinks";
import Vue from "vue";
import { BootstrapVue, IconsPlugin } from "bootstrap-vue";
import SecurityRequirementsGuides from "../components/security_requirements_guides/SecurityRequirementsGuides.vue";

Vue.use(TurbolinksAdapter);
Vue.use(BootstrapVue);
Vue.use(IconsPlugin);

Vue.component("Securityrequirementsguides", SecurityRequirementsGuides);

document.addEventListener("turbolinks:load", () => {
  new Vue({
    el: "#SecurityRequirementsGuides",
  });
});
