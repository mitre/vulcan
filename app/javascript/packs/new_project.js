import TurbolinksAdapter from "vue-turbolinks";
import Vue from "vue";
import NewProject from "../components/project/NewProject.vue";
import BootstrapVue from "bootstrap-vue";

Vue.use(TurbolinksAdapter);
Vue.use(BootstrapVue);

Vue.component("Newproject", NewProject);

document.addEventListener("turbolinks:load", () => {
  new Vue({
    el: "#NewProject",
  });
});
