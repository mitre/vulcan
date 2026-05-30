import TurbolinksAdapter from "vue-turbolinks";
import Vue from "vue";
import { BootstrapVue, IconsPlugin } from "bootstrap-vue";
import { bvConfig } from "../config/bootstrapVueConfig";
import UserTokens from "../components/users/UserTokens.vue";

Vue.use(TurbolinksAdapter);
Vue.use(BootstrapVue, bvConfig);
Vue.use(IconsPlugin);

Vue.component("Usertokens", UserTokens);

document.addEventListener("turbolinks:load", () => {
  new Vue({
    el: "#user-tokens-page",
  });
});
