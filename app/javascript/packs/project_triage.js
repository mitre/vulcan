import TurbolinksAdapter from "vue-turbolinks";
import Vue from "vue";
import { BootstrapVue, IconsPlugin } from "bootstrap-vue";
import { bvConfig } from "../config/bootstrapVueConfig";
import ProjectTriagePage from "../components/project/ProjectTriagePage.vue";
import linkify from "v-linkify";

Vue.use(TurbolinksAdapter);
Vue.use(BootstrapVue, bvConfig);
Vue.use(IconsPlugin);

Vue.directive("linkified", linkify);

Vue.component("Projecttriage", ProjectTriagePage);

document.addEventListener("turbolinks:load", () => {
  new Vue({
    el: "#projecttriage",
  });
});
