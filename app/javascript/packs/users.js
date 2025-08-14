import TurbolinksAdapter from "vue-turbolinks";
import Vue from "vue";
import { BootstrapVue, IconsPlugin } from "bootstrap-vue";
import Users from "../components/users/Users.vue";

Vue.use(TurbolinksAdapter);
Vue.use(BootstrapVue);
Vue.use(IconsPlugin);

Vue.component("Users", Users);

document.addEventListener("turbolinks:load", () => {
  new Vue({
    el: "#users",
  });
});
