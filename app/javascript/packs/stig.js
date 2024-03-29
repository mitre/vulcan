import TurbolinksAdapter from "vue-turbolinks";
import Vue from "vue";
import BootstrapVue from "bootstrap-vue";
import Stig from "../components/stigs/Stig.vue";
import linkify from "vue-linkify";

Vue.use(TurbolinksAdapter);
Vue.use(BootstrapVue);

Vue.directive("linkified", linkify);

Vue.component("Stig", Stig);

document.addEventListener("turbolinks:load", () => {
  new Vue({
    el: "#stig",
  });
});
