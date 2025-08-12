import TurbolinksAdapter from "vue-turbolinks";
import Vue from "vue";
import { BootstrapVue, IconsPlugin } from "bootstrap-vue";
import Rules from "../components/rules/Rules.vue";

Vue.use(TurbolinksAdapter);
Vue.use(BootstrapVue);
Vue.use(IconsPlugin);

Vue.component("Rules", Rules);

document.addEventListener("turbolinks:load", () => {
  new Vue({
    el: "#Rules",
  });
});
