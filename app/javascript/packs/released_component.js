import TurbolinksAdapter from "vue-turbolinks";
import Vue from "vue";
import { BootstrapVue, IconsPlugin } from "bootstrap-vue";
import ReleasedComponent from "../components/components/ReleasedComponent.vue";
import linkify from "v-linkify";

Vue.use(TurbolinksAdapter);
Vue.use(BootstrapVue);
Vue.use(IconsPlugin);

Vue.directive("linkified", linkify);

Vue.component("Releasedcomponent", ReleasedComponent);

document.addEventListener("turbolinks:load", () => {
  new Vue({
    el: "#releasedcomponent",
  });
});
