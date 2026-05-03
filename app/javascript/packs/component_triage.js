import TurbolinksAdapter from "vue-turbolinks";
import Vue from "vue";
import { BootstrapVue, IconsPlugin } from "bootstrap-vue";
import ComponentTriagePage from "../components/components/ComponentTriagePage.vue";
import linkify from "v-linkify";

Vue.use(TurbolinksAdapter);
Vue.use(BootstrapVue);
Vue.use(IconsPlugin);

Vue.directive("linkified", linkify);

Vue.component("Componenttriage", ComponentTriagePage);

document.addEventListener("turbolinks:load", () => {
  new Vue({
    el: "#componenttriage",
  });
});
