import Vue from "vue";
import { BootstrapVue, IconsPlugin } from "bootstrap-vue";
import { bvConfig } from "../config/bootstrapVueConfig";
import Stig from "../components/stigs/Stig.vue";
import linkify from "v-linkify";

Vue.use(BootstrapVue, bvConfig);
Vue.use(IconsPlugin);

Vue.directive("linkified", linkify);

Vue.component("Stig", Stig);

document.addEventListener("DOMContentLoaded", () => {
  new Vue({
    el: "#stig",
  });
});
