import TurbolinksAdapter from "vue-turbolinks";
import Vue from "vue";
import { BootstrapVue, IconsPlugin } from "bootstrap-vue";
import { bvConfig } from "../config/bootstrapVueConfig";
import PasswordField from "../components/shared/PasswordField.vue";

Vue.use(TurbolinksAdapter);
Vue.use(BootstrapVue, bvConfig);
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
