import TurbolinksAdapter from "vue-turbolinks";
import Vue from "vue";
import { BootstrapVue, IconsPlugin } from "bootstrap-vue";
import { bvConfig } from "../config/bootstrapVueConfig";
import Stig from "../components/stigs/Stig.vue";
import linkify from "v-linkify";

Vue.use(TurbolinksAdapter);
Vue.use(BootstrapVue, bvConfig);
Vue.use(IconsPlugin);

Vue.directive("linkified", linkify);

Vue.component("Stig", Stig);

document.addEventListener("turbolinks:load", () => {
  new Vue({
    el: "#stig",
  });
});
