import Vue from "vue";
import { BootstrapVue, IconsPlugin } from "bootstrap-vue";
import { bvConfig } from "../config/bootstrapVueConfig";
import BenchmarkListPage from "../components/shared/BenchmarkListPage.vue";

Vue.use(BootstrapVue, bvConfig);
Vue.use(IconsPlugin);

Vue.component("BenchmarkListPage", BenchmarkListPage);

document.addEventListener("DOMContentLoaded", () => {
  new Vue({
    el: "#Stigs",
  });
});
