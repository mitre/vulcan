import Vue from "vue";
import { BootstrapVue, IconsPlugin } from "bootstrap-vue";
import { bvConfig } from "../config/bootstrapVueConfig";
import ComponentSettingsPage from "../components/components/ComponentSettingsPage.vue";
import linkify from "v-linkify";

Vue.use(BootstrapVue, bvConfig);
Vue.use(IconsPlugin);

Vue.directive("linkified", linkify);

Vue.component("Componentsettings", ComponentSettingsPage);

document.addEventListener("DOMContentLoaded", () => {
  new Vue({
    el: "#componentsettings",
  });
});
