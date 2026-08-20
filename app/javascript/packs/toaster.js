import Vue from "vue";
// Import the individual components
import { BootstrapVue, IconsPlugin } from "bootstrap-vue";
import { bvConfig } from "../config/bootstrapVueConfig";
import Toaster from "../components/toaster/Toaster.vue";

Vue.use(BootstrapVue, bvConfig);
Vue.use(IconsPlugin);

Vue.component("Toaster", Toaster);

document.addEventListener("DOMContentLoaded", () => {
  new Vue({
    el: "#Toaster",
  });
});
