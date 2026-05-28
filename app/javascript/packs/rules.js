import TurbolinksAdapter from "vue-turbolinks";
import Vue from "vue";
import { BootstrapVue, IconsPlugin } from "bootstrap-vue";
import { bvConfig } from "../config/bootstrapVueConfig";
import Rules from "../components/rules/Rules.vue";

Vue.use(TurbolinksAdapter);
Vue.use(BootstrapVue, bvConfig);
Vue.use(IconsPlugin);

Vue.component("Rules", Rules);

document.addEventListener("turbolinks:load", () => {
  new Vue({
    el: "#Rules",
  });
});
