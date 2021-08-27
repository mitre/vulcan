import TurbolinksAdapter from "vue-turbolinks";
import Vue from "vue";
import BootstrapVue from "bootstrap-vue";
import ProjectMembers from "../components/project_members/ProjectMembers.vue";

Vue.use(TurbolinksAdapter);
Vue.use(BootstrapVue);

Vue.component("Projectmembers", ProjectMembers);

document.addEventListener("turbolinks:load", () => {
  new Vue({
    el: "#ProjectMembers",
  });
});
