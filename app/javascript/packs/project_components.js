import TurbolinksAdapter from "vue-turbolinks";
import Vue from "vue";
import { BootstrapVue, IconsPlugin } from "bootstrap-vue";
import ProjectComponents from "../components/components/ProjectComponents.vue";
import linkify from "v-linkify";

Vue.use(TurbolinksAdapter);
Vue.use(BootstrapVue);
Vue.use(IconsPlugin);

Vue.directive("linkified", linkify);

Vue.component("Projectcomponents", ProjectComponents);

document.addEventListener("turbolinks:load", () => {
  new Vue({
    el: "#projectcomponents",
  });
});
