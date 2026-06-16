import Vue from "vue";
import { BootstrapVue, IconsPlugin } from "bootstrap-vue";
import { bvConfig } from "../config/bootstrapVueConfig";
import ReleasedComponent from "../components/components/ReleasedComponent.vue";
import linkify from "v-linkify";

Vue.use(BootstrapVue, bvConfig);
Vue.use(IconsPlugin);

Vue.directive("linkified", linkify);

Vue.component("Releasedcomponent", ReleasedComponent);

document.addEventListener("DOMContentLoaded", () => {
  new Vue({
    el: "#releasedcomponent",
  });
});
