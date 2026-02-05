import TurbolinksAdapter from "vue-turbolinks";
import Vue from "vue";
import { BootstrapVue, IconsPlugin } from "bootstrap-vue";
import UserProfile from "../components/users/UserProfile.vue";

Vue.use(TurbolinksAdapter);
Vue.use(BootstrapVue);
Vue.use(IconsPlugin);

Vue.component("userprofile", UserProfile);

document.addEventListener("turbolinks:load", () => {
  new Vue({
    el: "#user-profile",
  });
});
