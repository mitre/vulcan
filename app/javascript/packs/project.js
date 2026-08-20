import Vue from "vue";
import { BootstrapVue, IconsPlugin } from "bootstrap-vue";
import { bvConfig } from "../config/bootstrapVueConfig";
import Project from "../components/project/Project.vue";
import linkify from "v-linkify";

Vue.use(BootstrapVue, bvConfig);
Vue.use(IconsPlugin);

Vue.directive("linkified", linkify);

Vue.component("Project", Project);

document.addEventListener("DOMContentLoaded", () => {
  new Vue({
    el: "#Project",
  });
});
