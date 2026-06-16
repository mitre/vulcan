import Vue from "vue";
import { BootstrapVue, IconsPlugin } from "bootstrap-vue";
import { bvConfig } from "../config/bootstrapVueConfig";
import Users from "../components/users/Users.vue";

Vue.use(BootstrapVue, bvConfig);
Vue.use(IconsPlugin);

Vue.component("Users", Users);

document.addEventListener("DOMContentLoaded", () => {
  new Vue({
    el: "#users",
  });
});
