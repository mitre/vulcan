import TurbolinksAdapter from "vue-turbolinks";
import Vue from "vue";
import { BootstrapVue, IconsPlugin } from "bootstrap-vue";
import UserPasswordPage from "../components/users/UserPasswordPage.vue";

Vue.use(TurbolinksAdapter);
Vue.use(BootstrapVue);
Vue.use(IconsPlugin);

Vue.component("Userpasswordpage", UserPasswordPage);

document.addEventListener("turbolinks:load", () => {
  new Vue({
    el: "#user-password-page",
  });
});
