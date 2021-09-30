import TurbolinksAdapter from "vue-turbolinks";
import Vue from "vue";
import BootstrapVue from "bootstrap-vue";
import Project from "../components/project/Project.vue";
import linkify from "vue-linkify";

Vue.use(TurbolinksAdapter);
Vue.use(BootstrapVue);

Vue.directive("linkified", linkify);

Vue.component("Project", Project);

document.addEventListener("turbolinks:load", () => {
  new Vue({
    el: "#Project",
  });
});
