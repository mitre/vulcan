import TurbolinksAdapter from "vue-turbolinks";
import Vue from "vue";
import { BootstrapVue, IconsPlugin } from "bootstrap-vue";
import { PiniaVuePlugin } from "pinia";
import { bvConfig } from "../config/bootstrapVueConfig";
import { sharedPinia } from "../lib/createVulcanApp";
import Navbar from "../components/navbar/App.vue";

Vue.use(PiniaVuePlugin);
Vue.use(TurbolinksAdapter);
Vue.use(BootstrapVue, bvConfig);
Vue.use(IconsPlugin);

Vue.component("Navbar", Navbar);

document.addEventListener("turbolinks:load", () => {
  new Vue({
    el: "#navbar",
    pinia: sharedPinia,
  });
});
