import TurbolinksAdapter from "vue-turbolinks";
import Vue from "vue";
// Import the individual components
import { BootstrapVue, IconsPlugin } from "bootstrap-vue";

Vue.use(TurbolinksAdapter);
Vue.use(BootstrapVue);
Vue.use(IconsPlugin);

document.addEventListener("turbolinks:load", () => {
  new Vue({
    el: "#login",
  });
});
