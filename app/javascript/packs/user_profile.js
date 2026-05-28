import TurbolinksAdapter from "vue-turbolinks";
import Vue from "vue";
import { BootstrapVue, IconsPlugin } from "bootstrap-vue";
import { bvConfig } from "../config/bootstrapVueConfig";
import UserProfile from "../components/users/UserProfile.vue";

Vue.use(TurbolinksAdapter);
Vue.use(BootstrapVue, bvConfig);
Vue.use(IconsPlugin);

Vue.component("Userprofile", UserProfile);

document.addEventListener("turbolinks:load", () => {
  new Vue({
    el: "#user-profile",
  });
});
