import TurbolinksAdapter from "vue-turbolinks";
import Vue from "vue";
import { BootstrapVue, IconsPlugin } from "bootstrap-vue";
import PasswordField from "../components/shared/PasswordField.vue";

Vue.use(TurbolinksAdapter);
Vue.use(BootstrapVue);
Vue.use(IconsPlugin);

document.addEventListener("turbolinks:load", () => {
  new Vue({
    el: "#login",
    components: { PasswordField },
    data() {
      return {
        registerPassword: "",
      };
    },
  });
});
