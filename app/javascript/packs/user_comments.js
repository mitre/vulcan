import TurbolinksAdapter from "vue-turbolinks";
import Vue from "vue";
import { BootstrapVue, IconsPlugin } from "bootstrap-vue";
import MyCommentsPage from "../components/users/MyCommentsPage.vue";

Vue.use(TurbolinksAdapter);
Vue.use(BootstrapVue);
Vue.use(IconsPlugin);

Vue.component("Mycommentspage", MyCommentsPage);

document.addEventListener("turbolinks:load", () => {
  new Vue({
    el: "#mycommentspage",
  });
});
