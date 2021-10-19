import TurbolinksAdapter from "vue-turbolinks";
import Vue from "vue";
import BootstrapVue from "bootstrap-vue";
import ProjectComponent from "../components/components/ProjectComponent.vue";
import linkify from "vue-linkify";

Vue.use(TurbolinksAdapter);
Vue.use(BootstrapVue);

Vue.directive("linkified", linkify);

Vue.component("Projectcomponent", ProjectComponent);

document.addEventListener("turbolinks:load", () => {
  new Vue({
    el: "#projectcomponent",
  });
});
