import TurbolinksAdapter from "vue-turbolinks";
import Vue from "vue";
import { BootstrapVue, IconsPlugin } from "bootstrap-vue";
import Navbar from "../components/navbar/App.vue";

Vue.use(TurbolinksAdapter);
Vue.use(BootstrapVue);
Vue.use(IconsPlugin);

Vue.component("Navbar", Navbar);

document.addEventListener("turbolinks:load", () => {
  new Vue({
    el: "#navbar",
  });
});
