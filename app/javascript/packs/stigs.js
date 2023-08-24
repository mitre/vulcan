import TurbolinksAdapter from "vue-turbolinks";
import Vue from "vue";
import BootstrapVue from "bootstrap-vue";
import Stigs from "../components/stigs/Stigs.vue";

Vue.use(TurbolinksAdapter);
Vue.use(BootstrapVue);

Vue.component("Stigs", Stigs);

document.addEventListener("turbolinks:load", () => {
  new Vue({
    el: "#Stigs",
  });
});
