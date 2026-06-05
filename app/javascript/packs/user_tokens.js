import Vue from "vue";
import { BootstrapVue, IconsPlugin } from "bootstrap-vue";
import { bvConfig } from "../config/bootstrapVueConfig";
import UserTokens from "../components/users/UserTokens.vue";

Vue.use(BootstrapVue, bvConfig);
Vue.use(IconsPlugin);

Vue.component("Usertokens", UserTokens);

document.addEventListener("DOMContentLoaded", () => {
  new Vue({
    el: "#user-tokens-page",
  });
});
