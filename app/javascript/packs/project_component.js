import TurbolinksAdapter from "vue-turbolinks";
import Vue from "vue";
import { BootstrapVue, IconsPlugin } from "bootstrap-vue";
import ProjectComponent from "../components/components/ProjectComponent.vue";
import linkify from "v-linkify";

Vue.use(TurbolinksAdapter);
Vue.use(BootstrapVue);
Vue.use(IconsPlugin);

Vue.directive("linkified", linkify);

Vue.component("Projectcomponent", ProjectComponent);

document.addEventListener("turbolinks:load", () => {
  new Vue({
    el: "#projectcomponent",
  });
});
