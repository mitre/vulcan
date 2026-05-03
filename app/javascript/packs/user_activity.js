import TurbolinksAdapter from "vue-turbolinks";
import Vue from "vue";
import { BootstrapVue, IconsPlugin } from "bootstrap-vue";
import UserActivityPage from "../components/users/UserActivityPage.vue";

Vue.use(TurbolinksAdapter);
Vue.use(BootstrapVue);
Vue.use(IconsPlugin);

Vue.component("Useractivitypage", UserActivityPage);

document.addEventListener("turbolinks:load", () => {
  new Vue({
    el: "#user-activity-page",
  });
});
