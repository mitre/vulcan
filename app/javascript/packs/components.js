import TurbolinksAdapter from "vue-turbolinks";
import Vue from "vue";
import BootstrapVue from "bootstrap-vue";
import Components from "../components/components/Components.vue";

Vue.use(TurbolinksAdapter);
Vue.use(BootstrapVue);

Vue.component("Components", Components);

document.addEventListener("turbolinks:load", () => {
  new Vue({
    el: "#Components",
  });
});
