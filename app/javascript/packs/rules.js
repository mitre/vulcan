import TurbolinksAdapter from "vue-turbolinks";
import Vue from "vue";
import BootstrapVue from "bootstrap-vue";
import Rules from "../components/rules/Rules.vue";

Vue.use(TurbolinksAdapter);
Vue.use(BootstrapVue);

Vue.component("Rules", Rules);

document.addEventListener("turbolinks:load", () => {
  new Vue({
    el: "#Rules",
  });
});
