import TurbolinksAdapter from "vue-turbolinks";
import Vue from "vue";
// Import the individual components
import BootstrapVue from "bootstrap-vue";

Vue.use(TurbolinksAdapter);
Vue.use(BootstrapVue);

document.addEventListener("turbolinks:load", () => {
  new Vue({
    el: "#login",
  });
});
