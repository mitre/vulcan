import TurbolinksAdapter from "vue-turbolinks";
import Vue from "vue";
// Import the individual components
import { BootstrapVue, IconsPlugin } from "bootstrap-vue";
import { bvConfig } from "../config/bootstrapVueConfig";
import Toaster from "../components/toaster/Toaster.vue";

Vue.use(TurbolinksAdapter);
Vue.use(BootstrapVue, bvConfig);
Vue.use(IconsPlugin);

Vue.component("Toaster", Toaster);

document.addEventListener("turbolinks:load", () => {
  new Vue({
    el: "#Toaster",
  });
});
