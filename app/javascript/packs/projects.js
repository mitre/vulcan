import TurbolinksAdapter from "vue-turbolinks";
import Vue from "vue";
import { BootstrapVue, IconsPlugin } from "bootstrap-vue";
import Projects from "../components/projects/Projects.vue";

Vue.use(TurbolinksAdapter);
Vue.use(BootstrapVue);
Vue.use(IconsPlugin);

Vue.component("Projects", Projects);

document.addEventListener("turbolinks:load", () => {
  new Vue({
    el: "#Projects",
  });
});
