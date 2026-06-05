import Vue from "vue";
import { BootstrapVue, IconsPlugin } from "bootstrap-vue";
import { bvConfig } from "../config/bootstrapVueConfig";
import UserActivityPage from "../components/users/UserActivityPage.vue";

Vue.use(BootstrapVue, bvConfig);
Vue.use(IconsPlugin);

Vue.component("Useractivitypage", UserActivityPage);

document.addEventListener("DOMContentLoaded", () => {
  new Vue({
    el: "#user-activity-page",
  });
});
