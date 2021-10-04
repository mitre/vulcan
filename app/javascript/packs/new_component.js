import TurbolinksAdapter from "vue-turbolinks";
import Vue from "vue";
import NewComponent from "../components/components/NewComponent.vue";
import BootstrapVue from "bootstrap-vue";

Vue.use(TurbolinksAdapter);
Vue.use(BootstrapVue);

Vue.component("Newcomponent", NewComponent);

document.addEventListener("turbolinks:load", () => {
  new Vue({
    el: "#NewComponent",
  });
});
