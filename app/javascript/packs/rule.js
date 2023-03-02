import TurbolinksAdapter from "vue-turbolinks";
import Vue from "vue";
import BootstrapVue from "bootstrap-vue";
import Rule from "../components/rules/Rule.vue";

Vue.use(TurbolinksAdapter);
Vue.use(BootstrapVue);

Vue.component("Rule", Rule);

document.addEventListener("turbolinks:load", () => {
  new Vue({
    el: "#Rule",
  });
});
