import Vue from "vue";
import { BootstrapVue, IconsPlugin } from "bootstrap-vue";
import { bvConfig } from "../config/bootstrapVueConfig";
import UserPasswordPage from "../components/users/UserPasswordPage.vue";

Vue.use(BootstrapVue, bvConfig);
Vue.use(IconsPlugin);

Vue.component("Userpasswordpage", UserPasswordPage);

document.addEventListener("DOMContentLoaded", () => {
  new Vue({
    el: "#user-password-page",
  });
});
