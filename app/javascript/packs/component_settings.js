import TurbolinksAdapter from "vue-turbolinks";
import Vue from "vue";
import { BootstrapVue, IconsPlugin } from "bootstrap-vue";
import ComponentSettingsPage from "../components/components/ComponentSettingsPage.vue";
import linkify from "v-linkify";

Vue.use(TurbolinksAdapter);
Vue.use(BootstrapVue);
Vue.use(IconsPlugin);

Vue.directive("linkified", linkify);

Vue.component("Componentsettings", ComponentSettingsPage);

document.addEventListener("turbolinks:load", () => {
  new Vue({
    el: "#componentsettings",
  });
});
