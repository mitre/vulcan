import TurbolinksAdapter from "vue-turbolinks";
import Vue from "vue";
import { BootstrapVue, IconsPlugin } from "bootstrap-vue";
import BenchmarkListPage from "../components/shared/BenchmarkListPage.vue";

Vue.use(TurbolinksAdapter);
Vue.use(BootstrapVue);
Vue.use(IconsPlugin);

Vue.component("BenchmarkListPage", BenchmarkListPage);

document.addEventListener("turbolinks:load", () => {
  new Vue({
    el: "#SecurityRequirementsGuides",
  });
});
