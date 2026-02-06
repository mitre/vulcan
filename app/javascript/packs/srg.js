import TurbolinksAdapter from "vue-turbolinks";
import Vue from "vue";
import { BootstrapVue, IconsPlugin } from "bootstrap-vue";
import Srg from "../components/security_requirements_guides/Srg.vue";
import linkify from "v-linkify";

Vue.use(TurbolinksAdapter);
Vue.use(BootstrapVue);
Vue.use(IconsPlugin);

Vue.directive("linkified", linkify);

Vue.component("Srg", Srg);

document.addEventListener("turbolinks:load", () => {
  new Vue({
    el: "#srg",
  });
});
